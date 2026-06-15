"""Backend HTTP de Chawerni (Phase 3) — FastAPI au-dessus du cœur RAG.

Expose /ask, /sources, /feedback, /health. Garde-fous loi 28-08 (information,
jamais conseil) en amont et en aval du LLM ; journalisation loi 09-08 (jamais
le contenu des questions).
"""
