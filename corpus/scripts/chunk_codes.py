"""Chunking du corpus juridique par article.

Principe Chawerni : 1 chunk = 1 article de loi, avec sa hiérarchie
(livre/titre/chapitre) et sa version de consolidation. Jamais de découpe par
fenêtre de tokens — un article tronqué = une citation fausse.

Méthode de détection des en-têtes (validée sur les PDFs réels) :
  1. extraction PyMuPDF + normalisation arabe (normalize_ar)
  2. suppression des lignes de pagination et des titres courants répétés
  3. candidats = toutes les occurrences de `المادة/الفصل N` (AR) ou
     `Article N` (FR)
  4. sélection par PLUS LONGUE CHAÎNE MONOTONE (programmation dynamique) :
     les vrais en-têtes se suivent (1, 2, 3, …) et forment mécaniquement la
     chaîne croissante la plus longue ; les références croisées (« المنصوص
     عليها في المادة 23 ») n'en font pas partie. Une approche gloutonne ne
     suffit pas : une référence matchant le numéro attendu fait sauter le
     curseur trop loin et tronque le document (constaté sur code_travail_ar).
     Trous tolérés jusqu'à MAX_GAP (articles abrogés), rapportés par
     validate_chunks.py.

Usage :
  python3 chunk_codes.py             # tout le manifeste
  python3 chunk_codes.py code_penal  # un seul texte
Sortie : corpus/chunks/{code}_{langue}.jsonl
"""

import json
import re
import sys
from collections import Counter
from dataclasses import asdict, dataclass, field
from pathlib import Path

import fitz

from normalize_ar import normalize_ar, strip_junk_lines

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "raw"
OUT = ROOT / "chunks"
MANIFEST = json.loads((ROOT / "manifest.json").read_text())
REGISTRY = json.loads((ROOT / "registry.json").read_text())

MAX_GAP = 6  # articles abrogés/manquants tolérés avant d'arrêter la chaîne

# --- patterns ---------------------------------------------------------------

AR_FIRST = {"الأولى": 1, "الأول": 1}
FR_FIRST = {"premier": 1}

# Marqueurs AR « flous » : certains PDFs (code du travail 2021) ont une couche
# texte fragmentée où le mot المادة lui-même est coupé (`الم اد ة53`) — on
# tolère des blancs entre les lettres du marqueur.
_AR_MADDA = r"ا\s*ل\s*م\s*ا\s*د\s*ة"
_AR_FASL = r"ا\s*ل\s*ف\s*ص\s*ل"
PATTERNS = {
    "ar": re.compile(
        rf"({_AR_MADDA}|{_AR_FASL})\s*(\d{{1,4}}(?:[-.]\d{{1,3}})?|الأولى|الأول)"
    ),
    "fr": re.compile(
        r"(Article|ARTICLE|Art\.)\s*(\d{1,4}(?:[-.]\d{1,3})?(?:\s*(?:bis|ter))?|premier|Premier)"
    ),
}


def canonical_marker(raw: str) -> str:
    return re.sub(r"\s+", "", raw)

HIERARCHY = {
    "ar": re.compile(r"^\s*(الكتاب|الجزء|القسم|الباب|الفرع|الفصل التمهيدي)\b(.{0,80})"),
    "fr": re.compile(r"^\s*(LIVRE|TITRE|CHAPITRE|SECTION)\b(.{0,80})", re.IGNORECASE),
}
# En AR, الفصل sert d'en-tête d'article dans certains codes (pénal, DOC…) et
# de niveau hiérarchique dans d'autres : on ne le traite en hiérarchie que si
# le marqueur d'article détecté est المادة.


@dataclass
class ArticleChunk:
    code: str
    langue: str
    article_num: str          # tel qu'affiché : "446", "19-1", "premier"
    num_int: int              # partie entière pour tri/continuité
    marqueur: str             # المادة / الفصل / Article
    hierarchie: dict = field(default_factory=dict)
    texte: str = ""
    version: str = ""         # date maj Adala (manifest)
    sha256_source: str = ""   # lien registry.json
    source_pdf: str = ""


# --- extraction -------------------------------------------------------------

def extract_text(pdf_path: Path, lang: str) -> str:
    doc = fitz.open(pdf_path)
    pages: list[str] = [str(doc[i].get_text()) for i in range(doc.page_count)]
    doc.close()

    # Titres courants : lignes identiques répétées sur >25 % des pages, mais
    # UNIQUEMENT près des bords de page (EDGE premières/dernières lignes).
    # Un filtre sur tout le corps de page supprimerait les mots fréquents que
    # l'extraction RTL isole sur leur propre ligne — y compris « المادة »
    # lui-même (bug constaté sur 38-15 AR : tous les en-têtes effacés).
    EDGE = 4
    freq = Counter()
    for p in pages:
        lines = [l.strip() for l in p.split("\n")]
        edges = {l for l in lines[:EDGE] + lines[-EDGE:] if l}
        for line in edges:
            freq[line] += 1
    threshold = max(3, int(len(pages) * 0.25))
    running = {l for l, c in freq.items() if c >= threshold and len(l) < 80}

    cleaned = []
    for p in pages:
        lines = p.split("\n")
        keep = []
        for idx, l in enumerate(lines):
            at_edge = idx < EDGE or idx >= len(lines) - EDGE
            if at_edge and l.strip() in running:
                continue
            keep.append(l)
        cleaned.append("\n".join(keep))
    text = "\n".join(cleaned)
    if lang == "ar":
        text = normalize_ar(text)
    # PAS de strip_junk_lines global ici : l'extraction RTL renvoie souvent le
    # numéro d'article seul sur sa propre ligne (`المادة ⏎ 52`) et le filtre
    # le supprimerait comme un numéro de page, détruisant l'en-tête (bug
    # constaté sur 38-15 AR). Le `\s*` des patterns traverse les sauts de
    # ligne ; le nettoyage se fait chunk par chunk dans chunk_file().
    return text


def _ar_plausibility(s: str) -> int:
    """Score de vraisemblance d'une ligne arabe en ordre logique : mots
    commençant par l'article ال et mots finissant par ة (impossible en
    initiale) — quasi nuls dans du texte en miroir."""
    return len(re.findall(r"\bال\w", s)) + len(re.findall(r"\w{2,}ة\b", s))


def extract_text_visual_reversed(pdf_path: Path) -> str:
    """Extraction de secours pour les PDFs à couche texte en ordre visuel
    (constaté sur code_travail_ar : PyMuPDF brouille les mots ; pdfminer sort
    les lignes en miroir exact — `ةداملا` = `المادة` inversé). Le PDF peut
    être MIXTE (certaines pages en ordre logique) : l'orientation est donc
    décidée LIGNE PAR LIGNE au score de vraisemblance, en re-renversant les
    séquences chiffres/latin pour qu'elles restent lisibles."""
    from pdfminer.high_level import extract_text as pm_extract

    raw = pm_extract(str(pdf_path))
    fixed = []
    for line in raw.split("\n"):
        logical = normalize_ar(line)
        r = line[::-1]
        r = re.sub(r"[0-9A-Za-z]+", lambda m: m.group(0)[::-1], r)
        mirrored = normalize_ar(r)
        fixed.append(mirrored if _ar_plausibility(mirrored) > _ar_plausibility(logical) else logical)
    text = "\n".join(fixed)
    # Dans la mise en page miroir, le numéro d'en-tête arrive sur la ligne
    # PRÉCÉDANT le marqueur (`1 ⏎ المادة`) : on le recolle derrière.
    text = re.sub(r"(\d{1,4})\s*\n\s*(المادة|الفصل)\s*\n", r"\2 \1\n", text)
    return text


# --- sélection des en-têtes par chaîne monotone -----------------------------

def parse_num(raw: str, lang: str) -> tuple[str, int]:
    raw = raw.strip()
    first = (AR_FIRST if lang == "ar" else FR_FIRST).get(raw.lower() if lang == "fr" else raw)
    if first:
        return raw, first
    m = re.match(r"(\d+)", raw)
    return raw, int(m.group(1)) if m else 0


def _is_sub_article(num_str: str) -> bool:
    return "-" in num_str or "." in num_str or "bis" in num_str.lower() or "ter" in num_str.lower()


def select_headers(text: str, lang: str) -> tuple[list, str]:
    """Sélectionne les en-têtes d'articles : plus longue chaîne croissante
    (DP), puis raccordement des chaînes préfixe/suffixe — une page déplacée
    dans le flux d'extraction crée un saut > MAX_GAP qui couperait sinon tout
    un pan du texte (constaté sur le DOC : articles 1-334 abandonnés à cause
    des articles 325-334 déplacés après le 335)."""
    cands = []
    for m in PATTERNS[lang].finditer(text):
        num_str, num_int = parse_num(m.group(2), lang)
        before = text[max(0, m.start() - 12):m.start()]
        base = {
            "start": m.start(), "end": m.end(),
            "marker": canonical_marker(m.group(1)),
            "num_str": num_str, "num": num_int,
            # un en-tête suit un saut de ligne (+ junk de pagination éventuel) ;
            # une référence croisée est précédée de mots
            "headerish": bool(re.search(r"\n[\s0-9\-–—.()]*$", before)) or m.start() == 0,
        }
        cands.append(base)
        # Les appels de note de bas de page se collent au numéro dans
        # l'extraction (`Article 19⁷` -> « Article 197 ») : on propose aussi
        # les interprétations tronquées, la chaîne DP choisit celle qui
        # s'insère dans la séquence (constaté sur immatriculation FR,
        # code pénal FR, code de commerce FR).
        if num_str.isdigit():
            for cut in (1, 2):
                if len(num_str) > cut:
                    alt = num_str[:-cut]
                    cands.append({**base, "num_str": alt, "num": int(alt)})
    if not cands:
        return [], ""

    # marqueur dominant (المادة vs الفصل) — l'autre famille relève de la
    # hiérarchie ou de références à d'autres textes
    dominant = Counter(c["marker"] for c in cands).most_common(1)[0][0]
    cands = [c for c in cands if c["marker"] == dominant]

    chain = _best_chain(cands)
    used = {c["start"] for c in chain}
    # préfixe : candidats avant le 1er en-tête retenu, numéros inférieurs
    while True:
        first = chain[0]
        prefix = [c for c in cands
                  if c["start"] < first["start"] and c["num"] < first["num"]
                  and c["start"] not in used]
        sub = _best_chain(prefix) if prefix else []
        if len(sub) < 3:  # en dessous, probablement du bruit de préambule
            break
        chain = sub + chain
        used |= {c["start"] for c in sub}
    # suffixe : candidats après le dernier en-tête retenu, numéros supérieurs
    while True:
        last = chain[-1]
        suffix = [c for c in cands
                  if c["start"] > last["end"] and c["num"] > last["num"]
                  and c["start"] not in used]
        sub = _best_chain(suffix) if suffix else []
        if len(sub) < 3:
            break
        chain = chain + sub
        used |= {c["start"] for c in sub}
    return chain, dominant


def _best_chain(cands: list) -> list:
    """Plus longue chaîne d'en-têtes à numéros croissants (positions
    croissantes), trous tolérés jusqu'à MAX_GAP."""
    n = len(cands)
    if n == 0:
        return []
    dp = [1] * n
    parent = [-1] * n
    WINDOW = 250  # un en-tête réel a son prédécesseur parmi les ~250 mentions précédentes

    def better_parent(a: int, b: int) -> bool:
        """a est-il un meilleur parent que b ? (dp, puis numéro le plus proche,
        puis aspect en-tête, puis position la plus tardive — le vrai en-tête N
        est plus proche de l'en-tête N+1 qu'une référence anticipée à N)"""
        if dp[a] != dp[b]:
            return dp[a] > dp[b]
        if cands[a]["num"] != cands[b]["num"]:
            return cands[a]["num"] > cands[b]["num"]
        if cands[a]["headerish"] != cands[b]["headerish"]:
            return cands[a]["headerish"]
        return cands[a]["start"] > cands[b]["start"]

    for j in range(n):
        best = -1
        for k in range(max(0, j - WINDOW), j):
            diff = cands[j]["num"] - cands[k]["num"]
            ok = (1 <= diff <= MAX_GAP + 1) or (
                diff == 0 and _is_sub_article(cands[j]["num_str"])
            )
            if not ok:
                continue
            if best == -1 or better_parent(k, best):
                best = k
        if best != -1:
            dp[j] = dp[best] + 1
            parent[j] = best

    # meilleure fin de chaîne (dp max ; à égalité, position la plus tardive
    # pour couvrir tout le document)
    end = max(range(n), key=lambda j: (dp[j], cands[j]["start"]))
    chain = []
    j = end
    while j != -1:
        chain.append(cands[j])
        j = parent[j]
    chain.reverse()
    return chain


# --- hiérarchie -------------------------------------------------------------

def hierarchy_spans(text: str, lang: str, article_marker: str) -> list:
    spans = []
    pat = HIERARCHY[lang]
    for line_match in re.finditer(r"^.*$", text, re.MULTILINE):
        line = line_match.group(0)
        m = pat.match(line)
        if not m:
            continue
        level = m.group(1)
        if lang == "ar" and level == "الفصل" and article_marker == "الفصل":
            continue  # ici الفصل = article, pas un niveau hiérarchique
        spans.append({"pos": line_match.start(), "level": level,
                      "label": line.strip()[:100]})
    return spans


def hierarchy_at(spans: list, pos: int) -> dict:
    state: dict = {}
    for s in spans:
        if s["pos"] > pos:
            break
        state[s["level"]] = s["label"]
    return state


# --- pipeline ---------------------------------------------------------------

def chunk_file(code: str, lang: str, entry: dict) -> list[ArticleChunk]:
    pdf = RAW / f"{code}_{lang}.pdf"
    if not pdf.exists():
        return []
    text = extract_text(pdf, lang)
    headers, marker = select_headers(text, lang)

    # Couche texte en ordre visuel ? Si la chaîne couvre mal la numérotation,
    # on retente avec l'extraction miroir et on garde la meilleure. Le ratio
    # est trompeur quand la chaîne est elle-même tronquée (le max l'est
    # aussi), donc seuil haut : seuls les fichiers à couverture quasi-parfaite
    # évitent la double extraction.
    if lang == "ar" and headers:
        coverage = len(headers) / max(h["num"] for h in headers)
        if coverage < 0.95:
            alt_text = extract_text_visual_reversed(pdf)
            alt_headers, alt_marker = select_headers(alt_text, lang)
            if len(alt_headers) > len(headers):
                print(f"  ({code} [{lang}] : extraction miroir retenue — "
                      f"{len(alt_headers)} vs {len(headers)} en-têtes)")
                text, headers, marker = alt_text, alt_headers, alt_marker

    spans = hierarchy_spans(text, lang, marker)
    reg = REGISTRY.get(f"{code}_{lang}", {})

    chunks = []
    for idx, h in enumerate(headers):
        end = headers[idx + 1]["start"] if idx + 1 < len(headers) else len(text)
        body = strip_junk_lines(text[h["start"]:end]).strip()
        body = re.sub(r"\s+", " ", body)
        chunks.append(ArticleChunk(
            code=code, langue=lang,
            article_num=h["num_str"], num_int=h["num"], marqueur=marker,
            hierarchie=hierarchy_at(spans, h["start"]),
            texte=body,
            version=entry.get(lang, {}).get("maj_adala", ""),
            sha256_source=reg.get("sha256", ""),
            source_pdf=pdf.name,
        ))
    return chunks


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    OUT.mkdir(exist_ok=True)
    for code, entry in MANIFEST["textes"].items():
        if only and code != only:
            continue
        for lang in ("ar", "fr"):
            if lang not in entry or entry[lang].get("url") == "A_COMPLETER":
                continue
            chunks = chunk_file(code, lang, entry)
            if not chunks:
                print(f"{code} [{lang}] : AUCUN chunk (fichier manquant ?)")
                continue
            out = OUT / f"{code}_{lang}.jsonl"
            with out.open("w") as f:
                for c in chunks:
                    f.write(json.dumps(asdict(c), ensure_ascii=False) + "\n")
            print(f"{code} [{lang}] : {len(chunks)} articles "
                  f"(marqueur {chunks[0].marqueur}, "
                  f"max n°{max(c.num_int for c in chunks)})")


if __name__ == "__main__":
    main()
