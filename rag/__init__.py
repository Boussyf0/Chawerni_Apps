"""Cœur RAG de Chawerni — indexation, retrieval hybride et abstraction LLM.

Voir rag/README.md. Pipeline : chunks JSONL → BGE-M3 (dense+sparse) → Qdrant →
retriever hybride (RRF + court-circuit lexical) → LLM (Groq) citant les articles.
"""
