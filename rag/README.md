# Chawerni — Cœur RAG (Phase 2)

Indexation et retrieval hybride pour l'assistant juridique Chawerni. Transforme les
~11 000 chunks d'articles (`corpus/chunks/*.jsonl`, Phase 1) en un index Qdrant
interrogeable, avec un retriever hybride et une abstraction LLM qui cite les articles
de loi exacts. C'est ce qui remplacera les réponses scriptées de l'app (Phase 4).

## Pipeline

```
chunks JSONL ──▶ BGE-M3 (dense 1024 + sparse) ──▶ Qdrant « chawerni_articles »
                                                        │
question ──▶ retrieve.py ──────────────────────────────┘
              ├─ court-circuit lexical (« article 446 », « الفصل 490 »)
              ├─ hybride dense+sparse → fusion RRF
              └─ gate cosinus (sinon refus honnête)
                        │
                        ▼
              llm.py (Groq) ──▶ réponse + citations [Code, Art. N°, version]
```

## Installation

```bash
# venv réutilisant les paquets système (torch/qdrant déjà installés) :
python3 -m venv rag/.venv --system-site-packages
rag/.venv/bin/python -m pip install -r rag/requirements.txt
```

Clé LLM (pour `rag.llm` / `rag.pipeline` / l'éval LLM) — env ou `rag/.env` :

```bash
echo 'GROQ_API_KEY=gsk_…' > rag/.env        # git-ignoré
# (optionnel) GROQ_MODEL=llama-3.3-70b-versatile
```

## Utilisation

```bash
PY=rag/.venv/bin/python

$PY -m rag.index                 # indexe les 23 fichiers (1er run : DL BGE-M3 ~2,3 Go)
$PY -m rag.index code_travail    # ré-indexe un seul code (idempotent)
$PY -m rag.index --recreate      # repart d'une collection vierge

$PY -m rag.retrieve "article 446 du code pénal"
$PY -m rag.retrieve "ما حقوقي عند الفصل من العمل؟" --code code_travail
$PY -m rag.pipeline "Le divorce par accord, comment ça marche ?"

$PY -m rag.eval.eval                  # gate complète (retriever + LLM si clé)
$PY -m rag.eval.eval --retriever-only # sans LLM
```

## Modules

| Fichier | Rôle |
|---|---|
| `config.py` | chemins, env, constantes (collection, seuils, modèle) |
| `embedding.py` | wrapper BGE-M3 → dense + sparse (singleton) |
| `store.py` | client Qdrant (local disque ou serveur) + collection |
| `index.py` | indexation idempotente (ID = hash(code, article, langue, version)) |
| `retrieve.py` | court-circuit lexical + hybride RRF + gate cosinus |
| `llm.py` | abstraction LLM, `GroqProvider`, prompt système (loi 28-08) |
| `pipeline.py` | `ask()` : retrieve → contexte → LLM, ou refus honnête |
| `eval/dataset.jsonl` | 50 questions FR+AR (exact / semantic / darija / out_of_corpus) |
| `eval/eval.py` | success@5 / precision / recall + taux de citation LLM ; **gate** |

## La gate

**`success@5 ≥ 0,80`** : pour au moins 80 % des questions in-corpus, un article
attendu apparaît dans le top-5. (Le plan parle de « precision@5 ≥ 0,8 » ; comme une
question juridique n'a souvent qu'1 article vraiment pertinent, la précision brute
`pertinents/5` est bornée — on retient donc le taux de succès@5, métrique RAG
standard. precision@5 / recall@5 / MRR sont rapportés pour information.)
S'y ajoutent la `refusal_accuracy` (questions hors corpus → liste vide) et le
`citation_rate` du LLM (aucune citation inventée hors contexte).

## Configuration

- **Qdrant** : mode local sur disque par défaut (`rag/.qdrant/`). Pour un serveur :
  `export QDRANT_URL=http://localhost:6333` (Docker arrive en Phase 3).
- **Seuil de refus** : `DENSE_SCORE_MIN` dans `config.py` — similarité cosinus dense
  minimale du meilleur résultat ; sous ce seuil, « je ne trouve pas de texte applicable ».

## Hors périmètre (phases suivantes)

API FastAPI + safety gates pré/post + Docker + logs loi 09-08 (Phase 3) ;
branchement de l'app Flutter sur `/ask` (Phase 4) ; veille automatisée (Phase 5).
