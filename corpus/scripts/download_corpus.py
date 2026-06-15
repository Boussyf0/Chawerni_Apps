"""Téléchargeur du corpus juridique Chawerni.

Lit corpus/manifest.json, télécharge chaque texte (FR + AR) dans corpus/raw/,
valide que le contenu est bien un PDF (le WAF de justice.gov.ma peut renvoyer
une page d'erreur HTML avec un code 200), et tient corpus/registry.json :
un hash SHA-256 par fichier. Un hash qui change lors d'une relance = nouvelle
consolidation publiée = ré-indexation Qdrant nécessaire (veille Phase 5).

Usage :
  python3 download_corpus.py            # tout le manifeste
  python3 download_corpus.py code_penal # un seul texte
"""

import hashlib
import json
import sys
from datetime import date
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "manifest.json"
RAW = ROOT / "raw"
REGISTRY = ROOT / "registry.json"
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
    ),
    "Accept-Language": "fr,ar;q=0.8",
}


def download(key: str, lang: str, spec: dict, registry: dict) -> str:
    url = spec.get("url", "")
    if not url or url == "A_COMPLETER":
        return "A_COMPLETER"
    is_html = spec.get("type") == "html"
    ext = "html" if is_html else "pdf"
    dest = RAW / f"{key}_{lang}.{ext}"

    try:
        r = requests.get(url, headers=HEADERS, timeout=120)
        r.raise_for_status()
    except Exception as e:
        return f"ERREUR réseau : {e}"

    if not is_html and not r.content.startswith(b"%PDF"):
        return "ERREUR : la réponse n'est pas un PDF (page WAF/erreur ?)"

    sha = hashlib.sha256(r.content).hexdigest()
    prev = registry.get(f"{key}_{lang}", {}).get("sha256")
    dest.write_bytes(r.content)
    registry[f"{key}_{lang}"] = {
        "sha256": sha,
        "octets": len(r.content),
        "url": url,
        "source": spec.get("source", ""),
        "telecharge_le": date.today().isoformat(),
    }
    if prev and prev != sha:
        return f"OK ({len(r.content)//1024} Ko) ⚠️ HASH MODIFIÉ — ré-indexer ce texte"
    return f"OK ({len(r.content)//1024} Ko)"


def main():
    manifest = json.loads(MANIFEST.read_text())
    registry = json.loads(REGISTRY.read_text()) if REGISTRY.exists() else {}
    RAW.mkdir(exist_ok=True)

    only = sys.argv[1] if len(sys.argv) > 1 else None
    a_completer = []
    for key, entry in manifest["textes"].items():
        if only and key != only:
            continue
        print(f"\n{entry['titre']}")
        for lang in ("ar", "fr"):
            if lang not in entry:
                continue
            status = download(key, lang, entry[lang], registry)
            print(f"  [{lang}] {status}")
            if status == "A_COMPLETER":
                a_completer.append((key, lang, entry[lang].get("note", "")))

    REGISTRY.write_text(json.dumps(registry, ensure_ascii=False, indent=2))
    print(f"\nRegistre : {REGISTRY} ({len(registry)} entrées)")
    if a_completer:
        print("\nURLs à compléter dans manifest.json :")
        for key, lang, note in a_completer:
            print(f"  - {key} [{lang}] : {note}")


if __name__ == "__main__":
    main()
