"""Indexation des chunks juridiques dans Qdrant avec BGE-M3.

Lit `corpus/chunks/{code}_{langue}.jsonl` (1 chunk = 1 article, produit en
Phase 1b), embarque chaque article en dense + sparse, et upsert dans la
collection `chawerni_articles`.

Idempotent : l'ID de point = uuid5(code, article_num, langue, version). Réindexer
un code remplace ses points sans toucher au reste. On purge d'abord les points du
code traité (filtre payload) pour évacuer d'éventuels articles disparus.

Usage :
  python3 -m rag.index                 # tout le corpus (23 fichiers)
  python3 -m rag.index code_penal      # un seul code (FR + AR)
  python3 -m rag.index --recreate      # repart d'une collection vierge
"""

from __future__ import annotations

import json
import sys
import uuid
from pathlib import Path

from qdrant_client import models

from . import config, embedding
from .store import ensure_collection, get_client

_NS = uuid.UUID("c4a3e0d2-7b1f-4e6a-9c2d-000000000001")  # namespace stable Chawerni
UPSERT_BATCH = 256


def point_id(code: str, article_num: str, langue: str, version: str) -> str:
    """ID déterministe → réindexation idempotente."""
    return str(uuid.uuid5(_NS, f"{code}|{article_num}|{langue}|{version}"))


def _chunk_files(code: str | None) -> list[Path]:
    if code:
        files = sorted(config.CHUNKS_DIR.glob(f"{code}_*.jsonl"))
        if not files:
            sys.exit(f"Aucun fichier pour le code « {code} » dans {config.CHUNKS_DIR}")
        return files
    return sorted(config.CHUNKS_DIR.glob("*.jsonl"))


def _load_chunks(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def index_file(client, path: Path) -> int:
    """Indexe un fichier JSONL ; renvoie le nombre d'articles indexés."""
    chunks = _load_chunks(path)
    if not chunks:
        return 0
    code = chunks[0]["code"]

    # Purge des points existants de ce (code, langue) avant réindexation.
    langues = {c["langue"] for c in chunks}
    client.delete(
        collection_name=config.COLLECTION,
        points_selector=models.Filter(
            must=[
                models.FieldCondition(key="code", match=models.MatchValue(value=code)),
                models.FieldCondition(
                    key="langue", match=models.MatchAny(any=list(langues))
                ),
            ]
        ),
    )

    texts = [c["texte"] for c in chunks]
    embeddings = embedding.embed(texts)

    points: list[models.PointStruct] = []
    for chunk, emb in zip(chunks, embeddings):
        pid = point_id(
            chunk["code"], chunk["article_num"], chunk["langue"], chunk["version"]
        )
        points.append(
            models.PointStruct(
                id=pid,
                vector={
                    config.DENSE_VECTOR: emb.dense,
                    config.SPARSE_VECTOR: models.SparseVector(
                        indices=emb.sparse_indices, values=emb.sparse_values
                    ),
                },
                payload=chunk,  # tout le chunk : métadonnées + texte
            )
        )

    for start in range(0, len(points), UPSERT_BATCH):
        client.upsert(
            collection_name=config.COLLECTION,
            points=points[start : start + UPSERT_BATCH],
        )
    return len(points)


def main() -> None:
    args = [a for a in sys.argv[1:] if a]
    recreate = "--recreate" in args
    code = next((a for a in args if not a.startswith("--")), None)

    client = get_client()
    ensure_collection(client, recreate=recreate)

    files = _chunk_files(code)
    total = 0
    for path in files:
        n = index_file(client, path)
        total += n
        print(f"  ✓ {path.name:40s} {n:>5d} articles")

    info = client.count(collection_name=config.COLLECTION, exact=True)
    print(f"\n{total} articles indexés sur {len(files)} fichier(s).")
    print(f"Collection « {config.COLLECTION} » : {info.count} points au total.")


if __name__ == "__main__":
    main()
