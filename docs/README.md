# Documentation Chawerni (شاورني)

Assistant juridique IA pour le droit marocain — chat RAG qui cite les articles
de loi exacts (FR / AR / darija), basé exclusivement sur les textes officiels.

| Document | Contenu |
|---|---|
| [design.md](design.md) | Design DNA — brief autonome pour assistant IA de design (identité, tokens, écrans, micro-copy) |
| [architecture.md](architecture.md) | Vue d'ensemble + diagrammes de tous les pipelines (corpus, chunking, RAG, safety, veille) |
| [plan.md](plan.md) | Plan complet approuvé : phases 1b → 5, jalons, critères de passage |
| [structure.md](structure.md) | Arborescence du repo : état actuel et cible |
| [etat_des_lieux_corpus_juridique.md](etat_des_lieux_corpus_juridique.md) | Périmètre juridique du corpus (Tiers 1-3), vérifications, points de veille |

## Les 5 principes non négociables

1. **RAG, pas fine-tuning** — chaque réponse cite l'article source vérifiable ;
   hors corpus → « je ne trouve pas de texte applicable ».
2. **Information juridique, jamais conseil** (loi 28-08) — disclaimer permanent,
   redirection vers un professionnel pour les enjeux graves.
3. **Le texte arabe fait foi** ; le français sert le retrieval multilingue.
4. **Versionnage du corpus** — chaque chunk porte sa date de consolidation ;
   hash SHA-256 modifié = ré-indexation.
5. **Loi 09-08** — pas de données personnelles dans les logs, hébergement des
   données utilisateurs au Maroc en production.

## Décisions actées

| Sujet | Décision | Pourquoi |
|---|---|---|
| Nom | **Chawerni** (شاورني) | Verbe darija à l'impératif = l'usage est dans le nom ; « Haqqi » gardé pour le module fiches pratiques |
| LLM | **API Groq** (OpenAI-compatible) | Rapide, peu coûteux, bon FR/AR ; couche d'abstraction pour changer de fournisseur |
| MVP | **FR + AR dès le départ** | Corpus déjà bilingue, BGE-M3 multilingue natif ; darija = couche de reformulation LLM |
| Embeddings | **BGE-M3** | Dense + sparse en une passe, multilingue AR/FR |
| Vector DB | **Qdrant** (hybride + RRF) | BM25 vital en droit : « article 446 » est une requête lexicale exacte |
| Backend / Mobile | FastAPI / Flutter | Stack maîtrisée, un codebase iOS+Android |
