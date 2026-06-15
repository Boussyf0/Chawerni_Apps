"""Crawler de l'arborescence Adala (adala.justice.gov.ma).

Parcourt récursivement les dossiers de ressources et inventorie tous les
fichiers (PDF) avec leur chemin hiérarchique. Produit corpus/adala_inventory.json,
qui sert ensuite à construire/mettre à jour manifest.json.

Usage : python3 crawl_adala.py [root_id] [lang]
  - racine FR : 338 (Références légales et réglementaires), défaut
  - racine AR : 1   (نصوص تشريعية وتنظيمية)
"""

import json
import re
import sys
import time
from pathlib import Path
from urllib.parse import quote

import requests

BASE = "https://adala.justice.gov.ma"
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
    ),
    "Accept-Language": "fr,ar;q=0.8",
}
NEXT_DATA_RE = re.compile(
    r'__NEXT_DATA__" type="application/json">(.*?)</script>', re.DOTALL
)

def fetch_node(node_id: int, lang: str = "fr", retries: int = 3) -> dict | None:
    url = f"{BASE}/{lang}/resources/{node_id}"
    for attempt in range(retries):
        try:
            r = requests.get(url, headers=HEADERS, timeout=30)
            m = NEXT_DATA_RE.search(r.text)
            if not m:
                raise ValueError("pas de __NEXT_DATA__ (WAF ?)")
            return json.loads(m.group(1))["props"]["pageProps"]["content"]
        except Exception as e:
            wait = 2 ** attempt
            print(f"  ! nœud {node_id} tentative {attempt + 1}: {e} — retry {wait}s")
            time.sleep(wait)
    return None


def walk(node_id: int, path: list[str], inventory: list[dict], seen: set[int], lang: str):
    if node_id in seen:
        return
    seen.add(node_id)
    node = fetch_node(node_id, lang)
    if node is None:
        inventory.append({"error": f"nœud {node_id} inaccessible", "path": path})
        return
    name = (node.get("name") or "").strip()
    here = path + [name] if name else path
    print("/".join(here))

    for f in node.get("files") or []:
        fname = f.get("name") or f.get("fileName") or ""
        fpath = f.get("path") or f.get("url") or f.get("file") or ""
        if fpath and not fpath.startswith("http"):
            # path en base = "uploads/AAAA/MM/JJ/nom.pdf" -> /api/uploads/...
            fpath = BASE + "/api/" + quote(fpath.lstrip("/"))
        inventory.append(
            {
                "folder": "/".join(here),
                "name": fname,
                "url": fpath,
                "language": f.get("language"),
                "updatedAt": f.get("updatedAt"),
                "file_id": f.get("id"),
            }
        )

    for child in node.get("folders") or []:
        walk(child["id"], here, inventory, seen, lang)
        time.sleep(0.5)  # politesse vis-à-vis du serveur


def main():
    root = int(sys.argv[1]) if len(sys.argv) > 1 else 338
    lang = sys.argv[2] if len(sys.argv) > 2 else "fr"
    out = Path(__file__).resolve().parent.parent / f"adala_inventory_{lang}.json"
    inventory: list[dict] = []
    walk(root, [], inventory, set(), lang)
    out.write_text(json.dumps(inventory, ensure_ascii=False, indent=2))
    print(f"\n{len(inventory)} fichiers inventoriés -> {out}")


if __name__ == "__main__":
    main()
