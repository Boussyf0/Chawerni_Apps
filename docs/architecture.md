# Architecture Chawerni

Diagrammes Mermaid — rendus nativement par GitHub, VS Code (extension Markdown
Preview Mermaid) et la plupart des viewers Markdown.

## 1. Vue d'ensemble

```mermaid
flowchart TB
    subgraph SOURCES["Sources officielles (.gov.ma)"]
        ADALA["Adala<br/>adala.justice.gov.ma<br/>(FR: racine 338, AR: racine 1)"]
        SGG["SGG / B.O.<br/>sgg.gov.ma"]
        MIEPEEC["Ministères sectoriels<br/>(miepeec, narsa…)"]
    end

    subgraph CORPUS["Pipeline corpus (Phase 1 ✅)"]
        CRAWL["crawl_adala.py<br/>inventaire __NEXT_DATA__"]
        DL["download_corpus.py<br/>validation %PDF + SHA-256"]
        MANIFEST[("manifest.json<br/>source de vérité")]
        REGISTRY[("registry.json<br/>hash par fichier")]
        CHUNK["chunk_codes.py<br/>1 chunk = 1 article"]
        VALIDATE["validate_chunks.py<br/>continuité + FR/AR"]
        JSONL[("chunks/*.jsonl<br/>~11 000 articles")]
    end

    subgraph RAG["RAG core (Phase 2)"]
        BGE["BGE-M3<br/>dense + sparse"]
        QDRANT[("Qdrant<br/>collection chawerni_articles")]
        RETRIEVE["retrieve.py<br/>hybride + RRF<br/>+ court-circuit lexical"]
        LLM["llm.py<br/>abstraction → API Groq"]
        EVAL["eval/ : 50 questions<br/>gate precision@5 ≥ 0.8"]
    end

    subgraph BACKEND["Backend (Phase 3)"]
        API["FastAPI<br/>/ask /sources /feedback"]
        SAFETY["Safety gates<br/>pré + post LLM"]
    end

    subgraph MOBILE["Mobile (Phase 4)"]
        FLUTTER["Flutter<br/>chat + cartes sources<br/>RTL + offline"]
    end

    ADALA --> CRAWL --> MANIFEST
    SGG -.fallback.-> MANIFEST
    MIEPEEC -.fallback.-> MANIFEST
    MANIFEST --> DL --> REGISTRY
    DL --> CHUNK --> VALIDATE --> JSONL
    JSONL --> BGE --> QDRANT
    QDRANT --> RETRIEVE --> LLM
    EVAL -.mesure.-> RETRIEVE
    LLM --> SAFETY --> API --> FLUTTER
```

## 2. Pipeline de chunking (Phase 1b — les pièges résolus)

```mermaid
flowchart TB
    PDF["PDF officiel<br/>(corpus/raw/)"] --> EXTRACT["Extraction PyMuPDF"]
    EXTRACT --> EDGE["Suppression titres courants<br/>⚠ bords de page UNIQUEMENT<br/>(sinon المادة isolé est effacé)"]
    EDGE --> NORM["normalize_ar.py<br/>NFKC + lam-alef (األ→الأ)<br/>+ chiffres ٠-٩→0-9"]
    NORM --> CANDS["Candidats : المادة/الفصل/Article + N<br/>pattern flou (lettres espacées)<br/>+ variantes notes collées (197→19)"]
    CANDS --> DP["Plus longue chaîne croissante (DP)<br/>les refs croisées brisent la monotonie"]
    DP --> STITCH["Raccordement préfixe/suffixe<br/>(pages déplacées : DOC 325-334)"]
    STITCH --> COVERAGE{"Couverture<br/>sous 95 % ?"}
    COVERAGE -- oui --> MIRROR["Fallback pdfminer miroir<br/>orientation ligne par ligne<br/>(score de vraisemblance AR)"]
    MIRROR --> BEST["Meilleure extraction retenue"]
    COVERAGE -- non --> BEST
    BEST --> BODY["Découpe des corps d'articles<br/>⚠ JAMAIS supprimer les lignes<br/>de chiffres nus (art. 23 : 20 points)"]
    BODY --> OUT[("chunks/{code}_{langue}.jsonl<br/>+ hiérarchie + version + sha256")]
    OUT --> VAL["validate_chunks.py<br/>trous = abrogations si<br/>identiques FR et AR"]
```

## 3. Flux d'une question utilisateur (Phases 2-3)

```mermaid
sequenceDiagram
    actor U as Utilisateur
    participant APP as Flutter
    participant API as FastAPI /ask
    participant PRE as Gate pré-LLM
    participant R as Retriever (Qdrant)
    participant G as LLM (Groq)
    participant POST as Gate post-LLM

    U->>APP: question (FR/AR/darija)
    APP->>API: POST /ask
    API->>PRE: détection enjeu grave ?
    alt enjeu personnel grave (pénal, garde d'enfants…)
        PRE-->>APP: réponse informative + redirection avocat
    else question standard
        PRE->>R: requête
        alt numéro d'article explicite (« article 446 »)
            R->>R: court-circuit lexical (payload direct)
        else question sémantique
            R->>R: hybride dense+sparse → fusion RRF
        end
        alt score < seuil
            R-->>APP: « je ne trouve pas de texte applicable »
        else chunks pertinents
            R->>G: contexte (articles + versions)
            G->>POST: réponse + citations [Code, Art. N, version]
            POST->>POST: chaque citation existe dans le contexte ?
            alt citation inventée
                POST->>G: régénération (1 retry) sinon dégradé « voir sources »
            end
            POST-->>APP: réponse + cartes sources cliquables + disclaimer
        end
    end
    Note over API: Logs loi 09-08 : compteurs/latences,<br/>jamais le contenu des questions
```

## 4. Veille juridique (Phase 5)

```mermaid
flowchart LR
    CRON["Hebdomadaire<br/>(cron/launchd)"] --> RECRAWL["crawl_adala.py<br/>FR 338 + AR 1"]
    RECRAWL --> DIFF{"updatedAt modifié<br/>sur un texte<br/>du manifeste ?"}
    DIFF -- non --> REPORT["Rapport : RAS"]
    DIFF -- oui --> REDL["download_corpus.py"]
    REDL --> HASH{"SHA-256<br/>modifié ?"}
    HASH -- non --> REPORT
    HASH -- oui --> RECHUNK["chunk_codes.py (ce code)<br/>+ validate"]
    RECHUNK --> REINDEX["Ré-indexation Qdrant<br/>(idempotente : point ID =<br/>hash(code,article,langue,version))"]
    REINDEX --> NOTIF["Notification<br/>+ maj date de version affichée"]

    WATCH["Alertes prioritaires :<br/>réforme Moudawana<br/>loi 03-23 (proc. pénale)<br/>projet santé/sécurité travail"] -.surveille.-> DIFF
```

## 5. Modèle de données d'un chunk

```mermaid
classDiagram
    class ArticleChunk {
        +str code
        +str langue
        +str article_num
        +int num_int
        +str marqueur
        +dict hierarchie
        +str texte
        +str version
        +str sha256_source
        +str source_pdf
    }
    class Manifest
    class Registry
    ArticleChunk --> Manifest : version
    ArticleChunk --> Registry : sha256_source
```

| Champ | Exemple | Rôle |
|---|---|---|
| `code` | `code_penal` | clé du manifeste, partout identique |
| `langue` | `ar` / `fr` | filtre de retrieval |
| `article_num` | `446`, `19-1`, `premier` | numéro affiché dans la citation |
| `num_int` | `446` | tri et contrôle de continuité |
| `marqueur` | `المادة` / `الفصل` / `Article` | varie selon le code — piège classique |
| `hierarchie` | `{"الكتاب": …, "الباب": …}` | contexte Livre/Titre/Chapitre |
| `texte` | corps intégral | jamais tronqué par fenêtre de tokens |
| `version` | `2026-04-28` | date de consolidation, affichée dans l'app |
| `sha256_source` | lien `registry.json` | traçabilité veille |

Point d'indexation Qdrant : `ID = hash(code, article_num, langue, version)` —
ré-indexer un code remplace ses points sans toucher au reste.

## 6. Contraintes transverses

| Contrainte | Implémentation |
|---|---|
| Loi 28-08 (exercice du droit) | Gates pré/post + disclaimer systématique + écran 1er lancement |
| Loi 09-08 (données perso) | Logs sans contenu, opt-in collecte, hébergement MA en prod |
| Texte AR fait foi | Réponse cite la version AR ; FR = aide à la lecture |
| Versionnage | `version` affichée dans chaque carte source de l'app |
