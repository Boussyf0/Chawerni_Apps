# Structure du repo

## État actuel (Phases 1a + 1b ✅)

```
Chawerni _Apps/
├── README.md                      # principes, pièges du chunking, roadmap
├── docs/
│   ├── README.md                  # index de la documentation + décisions
│   ├── architecture.md            # diagrammes de tous les pipelines
│   ├── plan.md                    # plan complet phases 1b → 5
│   ├── structure.md               # ce fichier
│   └── etat_des_lieux_corpus_juridique.md   # périmètre juridique Tiers 1-3
└── corpus/
    ├── manifest.json              # SOURCE DE VÉRITÉ : 13 textes, URLs officielles,
    │                              #   notes de version, fallbacks
    ├── registry.json              # SHA-256 + taille + date par fichier téléchargé
    ├── adala_inventory_fr.json    # inventaire complet Adala FR (557 fichiers)
    ├── adala_inventory_ar.json    # inventaire complet Adala AR (4 254 fichiers)
    ├── raw/                       # 23 PDFs officiels (~106 Mo) — non versionnés git
    │   ├── code_penal_{ar,fr}.pdf
    │   ├── moudawana_{ar,fr}.pdf
    │   └── … (13 textes × langues disponibles)
    ├── chunks/                    # sortie Phase 1b : 1 ligne JSONL = 1 article
    │   ├── code_penal_ar.jsonl    # 605 articles
    │   ├── code_penal_fr.jsonl    # 713 articles
    │   └── … (23 fichiers, ~11 000 chunks)
    └── scripts/
        ├── crawl_adala.py         # inventaire de l'arborescence Adala (__NEXT_DATA__)
        ├── download_corpus.py     # téléchargement + validation %PDF + registre
        ├── normalize_ar.py        # normalisation arabe + tests intégrés
        ├── chunk_codes.py         # chunking par article (DP + stitching + variantes)
        └── validate_chunks.py     # contrôle qualité, exit 1 si anomalie bloquante
```

## Cible (fin de roadmap)

```
Chawerni _Apps/
├── corpus/                        # (inchangé — alimente l'index)
│   └── scripts/watch.py           # + Phase 5 : veille hebdomadaire
├── rag/                           # Phase 2
│   ├── index.py                   # chunks → BGE-M3 → Qdrant (idempotent)
│   ├── retrieve.py                # hybride dense+sparse + RRF + court-circuit lexical
│   ├── llm.py                     # abstraction LLM (impl. Groq, clé env GROQ_API_KEY)
│   ├── prompts.py                 # prompt système (citation obligatoire, refus hors corpus)
│   └── eval/
│       ├── questions.jsonl        # 50 questions de référence FR/AR + pièges
│       └── eval.py                # precision@5, recall@5, taux de citation correcte
├── backend/                       # Phase 3
│   ├── app/
│   │   ├── main.py                # FastAPI : /ask /sources /feedback /health
│   │   ├── safety.py              # gates pré (enjeu grave) + post (citations vérifiées)
│   │   └── auth.py                # JWT
│   ├── tests/                     # pytest : nominal, hors corpus, enjeu grave, citation inventée
│   ├── Dockerfile
│   └── docker-compose.yml         # API + Qdrant
└── app/                           # Phase 4 : projet Flutter
    └── lib/
        ├── chat/                  # UI conversation + cartes sources cliquables
        ├── sources/               # consultation texte intégral (online + SQLite offline)
        ├── l10n/                  # FR / AR (RTL) / darija
        └── hoquqi/                # module fiches pratiques (post-MVP, entrée réservée)
```

## Conventions

- **Nommage des fichiers corpus** : `{code}_{langue}.{ext}` — la clé `code` est
  celle du manifeste, partout (raw/, chunks/, points Qdrant).
- **manifest.json est la seule source de vérité** des URLs et versions ; le code
  ne contient jamais d'URL en dur.
- **registry.json ne se modifie jamais à la main** — il est tenu par
  `download_corpus.py` ; un hash modifié déclenche re-chunk + ré-indexation.
- Scripts exécutables depuis `corpus/scripts/` (chemins relatifs au parent).
- `corpus/raw/` et les modèles téléchargés sont à exclure de git (.gitignore à
  créer à l'init du repo git).
