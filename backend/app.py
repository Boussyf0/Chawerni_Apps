"""API HTTP Chawerni (FastAPI) — sert le cœur RAG aux clients mobiles.

Endpoints :
  GET  /health                      état + modèle + nombre d'articles indexés
  POST /ask                         question → réponse sourcée (+ gates de sécurité)
  GET  /sources/{code}/{article}    texte intégral d'un article (carte cliquable)
  POST /feedback                    signal anonyme (loi 09-08 : aucun contenu)

Journalisation loi 09-08 : on ne loggue JAMAIS le contenu des questions, seulement
des compteurs et latences. Disclaimer systématique (loi 28-08).
"""

from __future__ import annotations

import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from rag import config, embedding, pipeline
from rag.retrieve import detect_langue, retrieve
from rag.store import get_client
from qdrant_client import models

from . import safety
from .schemas import (
    AskRequest,
    AskResponse,
    ArticleListItem,
    ArticleListResponse,
    ArticleResponse,
    CodeInfo,
    FeedbackRequest,
    HealthResponse,
    SourceCard,
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("chawerni")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Charge BGE-M3 au démarrage pour éviter la latence du 1er appel.
    log.info("Préchauffage BGE-M3…")
    embedding.embed_one("préchauffage")
    log.info("Modèle prêt. Collection=%s", config.COLLECTION)
    yield


app = FastAPI(title="Chawerni API", version="1.0",
              description="Assistant juridique RAG (droit marocain)", lifespan=lifespan)

# Mobile : pas d'origine web fixe → CORS ouvert (l'app native n'envoie pas d'Origin).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


import re

_PUNCT_SPACE = re.compile(r"\s+([،؛.,:!؟»])")
_OPEN_SPACE = re.compile(r"([«])\s+")


def _clean(texte: str) -> str:
    """Nettoyage d'affichage SÛR (sans toucher aux lettres) : espaces multiples
    réduits, espace avant ponctuation retiré. Les artefacts intra-mot et lam-alef
    de l'extraction AR relèvent d'un re-chunking (Phase 1), pas de l'affichage."""
    t = " ".join(texte.split())
    t = _PUNCT_SPACE.sub(r"\1", t)
    t = _OPEN_SPACE.sub(r"\1", t)
    return t.strip()


def _excerpt(texte: str, n: int = 180) -> str:
    t = _clean(texte)
    return t[:n] + ("…" if len(t) > n else "")


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    try:
        count = get_client().count(collection_name=config.COLLECTION, exact=True).count
    except Exception as e:  # collection absente / Qdrant injoignable
        raise HTTPException(status_code=503, detail=f"Qdrant indisponible: {e}")
    return HealthResponse(status="ok", model=config.GROQ_MODEL,
                          collection=config.COLLECTION, points=count)


@app.post("/ask", response_model=AskResponse)
def ask(req: AskRequest) -> AskResponse:
    t0 = time.time()
    langue = req.langue or detect_langue(req.question)
    grave = safety.is_grave(req.question)

    result = pipeline.ask(req.question, langue=langue, code=req.code)

    # Post-gate : aucune citation inventée hors des sources fournies.
    source_nums = {
        int(s.payload["num_int"])
        for s in result.sources
        if str(s.payload.get("num_int", "")).isdigit()
    }
    citations_ok, invented = safety.verify_citations(result.answer, source_nums)
    if invented:
        log.warning("citations inventées détectées: %s (sources réelles=%s)",
                    invented, sorted(source_nums))

    cards = [
        SourceCard(
            code=s.payload.get("code", ""),
            article_num=str(s.payload.get("article_num", "")),
            marqueur=s.payload.get("marqueur", ""),
            version=s.payload.get("version", ""),
            langue=s.payload.get("langue", ""),
            citation=s.citation,
            excerpt=_excerpt(s.payload.get("texte", "")),
        )
        for s in result.sources
    ]

    latency_ms = int((time.time() - t0) * 1000)
    # Loi 09-08 : compteurs/latence uniquement, jamais le texte de la question.
    log.info("ask lang=%s grave=%s refused=%s sources=%d citations_ok=%s latency=%dms",
             langue, grave, result.refused, len(cards), citations_ok, latency_ms)

    return AskResponse(
        answer=result.answer,
        sources=cards,
        refused=result.refused,
        grave=grave and not result.refused,
        lawyer_banner=safety.lawyer_banner_for(langue) if grave else None,
        disclaimer=safety.disclaimer_for(langue),
        langue=langue,
    )


def _fetch_article(code: str, article: str, langue: str):
    """Récupère un article par son numéro EXACT (« 52 », « premier », « 19-1 »)."""
    conds = [
        models.FieldCondition(key="code", match=models.MatchValue(value=code)),
        models.FieldCondition(key="langue", match=models.MatchValue(value=langue)),
        models.FieldCondition(key="article_num", match=models.MatchValue(value=article)),
    ]
    points, _ = get_client().scroll(
        collection_name=config.COLLECTION,
        scroll_filter=models.Filter(must=conds), limit=1, with_payload=True)
    if points:
        return points[0].payload
    # Repli : match numérique (« 19-1 » → num_int 19) si le n° exact n'existe pas.
    base = str(article).split("-")[0]
    if base.isdigit():
        conds[-1] = models.FieldCondition(
            key="num_int", match=models.MatchValue(value=int(base)))
        points, _ = get_client().scroll(
            collection_name=config.COLLECTION,
            scroll_filter=models.Filter(must=conds), limit=1, with_payload=True)
        if points:
            return points[0].payload
    return None


@app.get("/sources/{code}/{article}", response_model=ArticleResponse)
def get_source(code: str, article: str, langue: str = "ar") -> ArticleResponse:
    """Texte intégral d'un article (carte source cliquable de l'app).

    Repli de langue : un code AR-only (code de la route, organisation judiciaire,
    accidents du travail) reste consultable même si l'app demande le FR.
    """
    other = "ar" if langue == "fr" else "fr"
    p = _fetch_article(code, article, langue) or _fetch_article(code, article, other)
    if not p:
        raise HTTPException(status_code=404, detail="Article introuvable")
    return ArticleResponse(
        code=p.get("code", ""),
        article_num=str(p.get("article_num", "")),
        marqueur=p.get("marqueur", ""),
        hierarchie=p.get("hierarchie", {}) or {},
        texte=_clean(p.get("texte", "")),
        version=p.get("version", ""),
        langue=p.get("langue", ""),
    )


_codes_cache: list[CodeInfo] | None = None


def _code_filter(code: str, langue: str) -> models.Filter:
    return models.Filter(must=[
        models.FieldCondition(key="code", match=models.MatchValue(value=code)),
        models.FieldCondition(key="langue", match=models.MatchValue(value=langue)),
    ])


@app.get("/codes", response_model=list[CodeInfo])
def list_codes() -> list[CodeInfo]:
    """Liste des 13 codes officiels (Bibliothèque) avec version et nb d'articles."""
    global _codes_cache
    if _codes_cache is not None:
        return _codes_cache
    client = get_client()
    out: list[CodeInfo] = []
    for code in config.CODES:
        # La version AR fait foi ; on lit une version + le nombre d'articles AR.
        pts, _ = client.scroll(collection_name=config.COLLECTION,
                               scroll_filter=_code_filter(code, "ar"),
                               limit=1, with_payload=True)
        if not pts:  # code AR absent (improbable) → essaie FR
            pts, _ = client.scroll(collection_name=config.COLLECTION,
                                   scroll_filter=_code_filter(code, "fr"),
                                   limit=1, with_payload=True)
        if not pts:
            continue
        langue = pts[0].payload.get("langue", "ar")
        version = pts[0].payload.get("version", "")
        count = client.count(collection_name=config.COLLECTION,
                             count_filter=_code_filter(code, langue), exact=True).count
        out.append(CodeInfo(
            code=code,
            titleFr=config.CODE_NAMES.get(code, code),
            titleAr=config.CODE_NAMES_AR.get(code, code),
            accent=config.CODE_ACCENT.get(code, "civil"),
            version=version,
            articles=count,
        ))
    _codes_cache = out
    return out


@app.get("/codes/{code}/articles", response_model=ArticleListResponse)
def list_articles(code: str, langue: str = "fr", offset: int = 0,
                  limit: int = 30) -> ArticleListResponse:
    """Parcours paginé des articles d'un code, triés par numéro."""
    limit = max(1, min(limit, 100))
    client = get_client()
    points, _ = client.scroll(collection_name=config.COLLECTION,
                              scroll_filter=_code_filter(code, langue),
                              limit=5000, with_payload=True)
    if not points:
        # Repli langue (codes AR-only consultables même en mode FR).
        langue = "ar" if langue == "fr" else "fr"
        points, _ = client.scroll(collection_name=config.COLLECTION,
                                  scroll_filter=_code_filter(code, langue),
                                  limit=5000, with_payload=True)
    if not points:
        raise HTTPException(status_code=404, detail="Code introuvable")
    points.sort(key=lambda p: p.payload.get("num_int") or 0)
    total = len(points)
    page = points[offset:offset + limit]
    items = [
        ArticleListItem(
            article_num=str(p.payload.get("article_num", "")),
            marqueur=p.payload.get("marqueur", ""),
            excerpt=_excerpt(p.payload.get("texte", ""), 140),
            version=p.payload.get("version", ""),
        )
        for p in page
    ]
    return ArticleListResponse(code=code, langue=langue, total=total,
                               offset=offset, limit=limit, articles=items)


@app.get("/search", response_model=list[SourceCard])
def search(q: str, code: str | None = None, langue: str | None = None,
           k: int = 8) -> list[SourceCard]:
    """Recherche d'articles (hybride RRF + court-circuit n°) dans un code ou global."""
    lang = langue or detect_langue(q)
    # Code AR-only (route, organisation judiciaire, accidents) : si la langue
    # demandée n'existe pas pour ce code, basculer sur la langue disponible.
    if code:
        pts, _ = get_client().scroll(collection_name=config.COLLECTION,
                                     scroll_filter=_code_filter(code, lang),
                                     limit=1, with_payload=False)
        if not pts:
            lang = "ar" if lang == "fr" else "fr"
    hits = retrieve(q, langue=lang, code=code, top_k=max(1, min(k, 20)))
    return [
        SourceCard(
            code=s.payload.get("code", ""),
            article_num=str(s.payload.get("article_num", "")),
            marqueur=s.payload.get("marqueur", ""),
            version=s.payload.get("version", ""),
            langue=s.payload.get("langue", ""),
            citation=s.citation,
            excerpt=_excerpt(s.payload.get("texte", "")),
        )
        for s in hits
    ]


@app.post("/feedback")
def feedback(req: FeedbackRequest) -> dict:
    # Aucun contenu : juste un compteur utile/inutile.
    log.info("feedback helpful=%s", req.helpful)
    return {"ok": True}
