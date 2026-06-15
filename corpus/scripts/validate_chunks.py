"""Contrôle qualité des chunks produits par chunk_codes.py.

Vérifie, pour chaque corpus/chunks/{code}_{langue}.jsonl :
  - continuité de la numérotation (trous = articles potentiellement ratés)
  - doublons de numéros (hors sous-articles 19-1, bis…)
  - longueurs aberrantes (chunk minuscule = parsing cassé, énorme = en-têtes
    ratés en cascade)
  - cohérence FR/AR par code (les deux versions doivent avoir des comptes
    proches)
  - références connues (Code du travail = 589 articles…)

Sortie : rapport lisible + code retour 1 si anomalie bloquante.
Usage : python3 validate_chunks.py [--strict]
"""

import json
import statistics
import sys
from collections import Counter
from pathlib import Path

CHUNKS = Path(__file__).resolve().parent.parent / "chunks"

# Nombre d'articles attendus (sources : rapport état des lieux + textes)
EXPECTED = {
    "constitution_2011": 180,
    "code_travail": 589,
    "moudawana": 400,
    "droits_reels": 334,
}

MIN_LEN = 40        # un article fait rarement moins de 40 caractères
MAX_LEN = 25000     # ou plus de ~8 pages
MIN_COVERAGE = 0.90  # chunks retenus / numéro max


def validate_file(path: Path) -> tuple[list[str], list[str]]:
    """Retourne (erreurs bloquantes, avertissements)."""
    errors, warnings = [], []
    chunks = [json.loads(l) for l in path.read_text().splitlines()]
    code_lang = path.stem
    code = "_".join(code_lang.split("_")[:-1])

    nums = [c["num_int"] for c in chunks]
    max_num = max(nums)
    base_nums = [c["num_int"] for c in chunks
                 if c["num_int"] and "-" not in c["article_num"]]

    # couverture
    coverage = len(set(base_nums)) / max_num
    if coverage < MIN_COVERAGE:
        errors.append(f"couverture {coverage:.0%} (<{MIN_COVERAGE:.0%}) : "
                      f"{len(set(base_nums))} articles pour un max n°{max_num}")

    # trous
    holes = [n for n in range(1, max_num + 1) if n not in set(base_nums)]
    if holes:
        msg = f"{len(holes)} trou(s) : {holes[:15]}{'…' if len(holes) > 15 else ''}"
        (warnings if len(holes) <= max_num * 0.1 else errors).append(msg)

    # doublons (hors sous-articles)
    dups = [n for n, c in Counter(base_nums).items() if c > 1]
    if dups:
        warnings.append(f"{len(dups)} numéro(s) en double : {sorted(dups)[:10]}")

    # longueurs
    lens = [len(c["texte"]) for c in chunks]
    tiny = sum(1 for l in lens if l < MIN_LEN)
    huge = sum(1 for l in lens if l > MAX_LEN)
    if tiny:
        warnings.append(f"{tiny} chunk(s) < {MIN_LEN} caractères")
    if huge:
        warnings.append(f"{huge} chunk(s) > {MAX_LEN} caractères")

    # référence connue
    expected = EXPECTED.get(code)
    if expected and abs(len(set(base_nums)) - expected) > expected * 0.05:
        errors.append(f"attendu ≈{expected} articles, trouvé {len(set(base_nums))}")

    stats = (f"{len(chunks)} chunks, n°max {max_num}, "
             f"médiane {int(statistics.median(lens))} car.")
    print(f"  {path.name:42s} {stats}")
    return errors, warnings


def main():
    strict = "--strict" in sys.argv
    files = sorted(CHUNKS.glob("*.jsonl"))
    if not files:
        print("Aucun chunk : lancer chunk_codes.py d'abord")
        sys.exit(1)

    total_err = 0
    by_code: dict[str, dict[str, int]] = {}
    print(f"=== validation de {len(files)} fichiers ===")
    all_msgs = []
    for f in files:
        errors, warnings = validate_file(f)
        for e in errors:
            all_msgs.append(f"  ✘ {f.name} : {e}")
            total_err += 1
        for w in warnings:
            all_msgs.append(f"  ⚠ {f.name} : {w}")
            if strict:
                total_err += 1
        code = "_".join(f.stem.split("_")[:-1])
        lang = f.stem.split("_")[-1]
        n = sum(1 for _ in f.read_text().splitlines())
        by_code.setdefault(code, {})[lang] = n

    print("\n=== cohérence FR/AR ===")
    for code, langs in sorted(by_code.items()):
        if len(langs) == 2:
            fr, ar = langs.get("fr", 0), langs.get("ar", 0)
            delta = abs(fr - ar) / max(fr, ar)
            flag = "⚠" if delta > 0.10 else "✓"
            print(f"  {flag} {code:28s} fr={fr:4d}  ar={ar:4d}  (écart {delta:.0%})")
            if delta > 0.10:
                all_msgs.append(f"  ⚠ {code} : écart FR/AR de {delta:.0%}")

    if all_msgs:
        print("\n=== anomalies ===")
        print("\n".join(all_msgs))
    print(f"\n{'ÉCHEC' if total_err else 'OK'} — {total_err} erreur(s) bloquante(s)")
    sys.exit(1 if total_err else 0)


if __name__ == "__main__":
    main()
