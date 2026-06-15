"""Schémas Pydantic des requêtes / réponses de l'API Chawerni."""

from __future__ import annotations

from pydantic import BaseModel, Field


class AskRequest(BaseModel):
    question: str = Field(min_length=2, max_length=2000)
    langue: str | None = Field(default=None, description="fr | ar (auto-détecté si absent)")
    code: str | None = Field(default=None, description="Restreindre à un code précis")


class SourceCard(BaseModel):
    code: str
    article_num: str
    marqueur: str
    version: str
    langue: str
    citation: str
    excerpt: str


class AskResponse(BaseModel):
    answer: str
    sources: list[SourceCard]
    refused: bool
    grave: bool = False
    lawyer_banner: str | None = None
    disclaimer: str
    langue: str


class ArticleResponse(BaseModel):
    code: str
    article_num: str
    marqueur: str
    hierarchie: dict
    texte: str
    version: str
    langue: str


class CodeInfo(BaseModel):
    code: str
    titleFr: str
    titleAr: str
    accent: str
    version: str
    articles: int


class ArticleListItem(BaseModel):
    article_num: str
    marqueur: str
    excerpt: str
    version: str


class ArticleListResponse(BaseModel):
    code: str
    langue: str
    total: int
    offset: int
    limit: int
    articles: list[ArticleListItem]


class FeedbackRequest(BaseModel):
    # Aucun contenu de question (loi 09-08) : juste un signal anonyme.
    helpful: bool
    message_id: str | None = Field(default=None, max_length=64)


class HealthResponse(BaseModel):
    status: str
    model: str
    collection: str
    points: int
