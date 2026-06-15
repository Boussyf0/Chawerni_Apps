"""Accès Qdrant partagé — client + (re)création de la collection.

Mode local sur disque par défaut (`rag/.qdrant/`, aucun serveur requis) ; si
`QDRANT_URL` est défini, on parle à un serveur. La collection `chawerni_articles`
porte deux vecteurs nommés : `dense` (1024, cosine) et `sparse` (BM25 appris).
"""

from __future__ import annotations

from qdrant_client import QdrantClient, models

from . import config

_client: QdrantClient | None = None


def get_client() -> QdrantClient:
    """Singleton QdrantClient (serveur si QDRANT_URL, sinon local disque)."""
    global _client
    if _client is None:
        if config.QDRANT_URL:
            # Serveur / Qdrant Cloud (api_key requis pour le Cloud).
            _client = QdrantClient(url=config.QDRANT_URL, api_key=config.QDRANT_API_KEY)
        else:
            config.QDRANT_PATH.mkdir(parents=True, exist_ok=True)
            _client = QdrantClient(path=str(config.QDRANT_PATH))
    return _client


def ensure_collection(client: QdrantClient, recreate: bool = False) -> None:
    """Crée la collection si absente (ou la recrée). Indexe les champs filtrables."""
    exists = client.collection_exists(config.COLLECTION)
    if exists and recreate:
        client.delete_collection(config.COLLECTION)
        exists = False
    if not exists:
        client.create_collection(
            collection_name=config.COLLECTION,
            vectors_config={
                config.DENSE_VECTOR: models.VectorParams(
                    size=config.DENSE_DIM,
                    distance=models.Distance.COSINE,
                ),
            },
            sparse_vectors_config={
                config.SPARSE_VECTOR: models.SparseVectorParams(
                    index=models.SparseIndexParams(on_disk=False),
                ),
            },
        )
        # Index de payload pour filtrage rapide (langue/code) et court-circuit
        # lexical (num_int).
        for field, schema in [
            ("langue", models.PayloadSchemaType.KEYWORD),
            ("code", models.PayloadSchemaType.KEYWORD),
            ("num_int", models.PayloadSchemaType.INTEGER),
            ("article_num", models.PayloadSchemaType.KEYWORD),  # fetch n° exact
            ("version", models.PayloadSchemaType.DATETIME),  # filtre version min.
        ]:
            client.create_payload_index(
                collection_name=config.COLLECTION,
                field_name=field,
                field_schema=schema,
            )
