# API Chawerni — FastAPI + BGE-M3 (CPU). Image auto-suffisante pour un droplet.
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HF_HOME=/models \
    TOKENIZERS_PARALLELISM=false

WORKDIR /app

# torch CPU-only (bien plus léger que la build CUDA par défaut).
RUN pip install --index-url https://download.pytorch.org/whl/cpu torch

# Dépendances applicatives.
COPY rag/requirements.txt rag/requirements.txt
COPY backend/requirements.txt backend/requirements.txt
RUN pip install -r backend/requirements.txt

# Pré-téléchargement de BGE-M3 DANS l'image (~2,3 Go) → démarrage rapide et
# fiable, indispensable sans disque persistant (App Platform) : pas de download
# au boot, donc pas de timeout du health check.
RUN python -c "from huggingface_hub import snapshot_download; snapshot_download('BAAI/bge-m3')"

# À partir d'ici, on lit le modèle depuis le cache local (aucun appel réseau HF).
ENV HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1

# Code.
COPY rag/ rag/
COPY backend/ backend/

# Index vectoriel : externe (Qdrant Cloud via QDRANT_URL / QDRANT_API_KEY).
EXPOSE 8000
CMD ["uvicorn", "backend.app:app", "--host", "0.0.0.0", "--port", "8000"]
