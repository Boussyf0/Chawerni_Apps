"""Wrapper BGE-M3 — embeddings dense + sparse en une seule passe.

BGE-M3 (BAAI/bge-m3) est multilingue (FR/AR couverts) et sort, pour un même
texte, un vecteur dense (1024 dims, sémantique cross-lingue) ET des poids
lexicaux sparse (façon BM25 appris) — exactement ce qu'il faut pour le retrieval
hybride avec fusion RRF côté Qdrant.

Le modèle est lourd (~2,3 Go au 1er téléchargement) : on le charge une seule fois
en singleton paresseux. `use_fp16=False` car on vise CPU/MPS (le fp16 n'accélère
que sur GPU CUDA).
"""

from __future__ import annotations

from dataclasses import dataclass

from . import config


@dataclass
class Embedding:
    """Sortie d'embedding pour un texte : dense + sparse (indices/valeurs)."""

    dense: list[float]
    sparse_indices: list[int]
    sparse_values: list[float]


_model = None


def get_model():
    """Charge BGEM3FlagModel une fois (téléchargement au 1er appel)."""
    global _model
    if _model is None:
        from FlagEmbedding import BGEM3FlagModel

        # devices=[un seul] => pas de pool multiprocessing (source de deadlock
        # sur macOS/MPS). use_fp16 réservé au GPU CUDA.
        _model = BGEM3FlagModel(
            config.BGE_MODEL,
            use_fp16=False,
            devices=[config.EMBED_DEVICE],
        )
    return _model


def _to_sparse(lexical_weights: dict) -> tuple[list[int], list[float]]:
    """Convertit les poids lexicaux BGE (token_id -> poids) en listes Qdrant."""
    indices: list[int] = []
    values: list[float] = []
    for token_id, weight in lexical_weights.items():
        w = float(weight)
        if w <= 0:
            continue
        indices.append(int(token_id))
        values.append(w)
    return indices, values


def embed(texts: list[str], batch_size: int | None = None) -> list[Embedding]:
    """Embarque une liste de textes en (dense, sparse).

    Renvoie un Embedding par texte, dans l'ordre d'entrée.
    """
    if not texts:
        return []
    model = get_model()
    out = model.encode(
        texts,
        batch_size=batch_size or config.EMBED_BATCH,
        max_length=config.EMBED_MAX_LEN,
        return_dense=True,
        return_sparse=True,
        return_colbert_vecs=False,
    )
    dense_vecs = out["dense_vecs"]
    lexical = out["lexical_weights"]
    results: list[Embedding] = []
    for i in range(len(texts)):
        idx, val = _to_sparse(lexical[i])
        results.append(
            Embedding(
                dense=[float(x) for x in dense_vecs[i]],
                sparse_indices=idx,
                sparse_values=val,
            )
        )
    return results


def embed_one(text: str) -> Embedding:
    """Raccourci pour une requête unique."""
    return embed([text])[0]
