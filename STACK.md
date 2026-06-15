# Chawerni — Stack technique en profondeur (« quoi » et « pourquoi »)

Ce document explique **chaque** brique technique du projet, **pourquoi** elle a
été choisie, les **alternatives écartées**, et les **pièges** rencontrés. Il
complète `README.md` (vue d'ensemble), `docs/architecture.md` (diagrammes) et
`docs/design.md` (design system). Rien n'est laissé implicite.

> **Chawerni (شاورني, « consulte-moi »)** : assistant juridique mobile pour le
> droit marocain. L'utilisateur pose une question en **français / arabe / darija**,
> l'app répond en **citant l'article de loi exact** avec sa date de version —
> jamais de réponse inventée.

---

## Table des matières

1. [Les 4 contraintes qui dictent TOUS les choix](#1-les-4-contraintes)
2. [Vue d'ensemble du flux](#2-vue-densemble)
3. [Phase 1 — Pipeline corpus](#3-phase-1--corpus)
4. [Le problème de l'arabe + la solution OCR](#4-arabe--ocr)
5. [Phase 2 — Cœur RAG](#5-phase-2--rag)
6. [Phase 3 — Backend API](#6-phase-3--backend)
7. [Phase 4 — App mobile Flutter](#7-phase-4--flutter)
8. [Déploiement & infrastructure](#8-deploiement)
9. [Sécurité & conformité](#9-securite)
10. [Tableau récapitulatif des technologies](#10-recap)
11. [Limites connues & dette technique](#11-limites)

---

<a name="1-les-4-contraintes"></a>
## 1. Les 4 contraintes qui dictent TOUS les choix

Avant toute techno, ces contraintes expliquent **pourquoi** l'architecture est ce
qu'elle est :

| # | Contrainte | Conséquence technique |
|---|---|---|
| **C1** | **Zéro hallucination** — un assistant juridique qui invente un article est dangereux. | RAG **obligatoire** (pas de fine-tuning « par cœur »). La réponse doit être **ancrée** sur des textes récupérés, et chaque citation **vérifiée**. |
| **C2** | **Loi 28-08** (exercice du droit) — information juridique, **jamais** de conseil personnalisé. | Disclaimer systématique, bandeau « consulte un avocat » sur les sujets graves, prompt système strict, **refus honnête** quand le corpus ne couvre pas. |
| **C3** | **Loi 09-08** (données personnelles) — données au Maroc en prod, pas de contenu perso dans les logs. | Logs sans le **texte des questions** (compteurs/latence seulement). Hébergement marocain prévu pour la prod avec comptes utilisateurs. |
| **C4** | **Trilingue + le texte arabe fait foi** juridiquement. | RTL-first, pile de polices bilingue, **citations en arabe classique** (la darija = couche de reformulation, pas une couche de corpus), recherche cross-lingue. |

Tout le reste découle de ces quatre points.

---

<a name="2-vue-densemble"></a>
## 2. Vue d'ensemble du flux

```
PDFs officiels (Adala)                         App mobile Flutter
      │ download + hash                              │  HTTPS
      ▼                                              ▼
  chunking par article ──► chunks JSONL        Backend FastAPI
  (+ OCR arabe)                  │              /ask /codes /sources /search
                                 ▼                    │
                          BGE-M3 (dense+sparse)       ├─► retrieve hybride (RRF + n° exact)
                                 ▼                    │      └─ Qdrant (collection chawerni_articles)
                          Qdrant (index)  ◄───────────┤
                                                      ├─► reformulation darija→fusha (LLM 8B)
                                                      ├─► génération réponse (LLM 70B Groq)
                                                      └─► safety gates (pré/post) + disclaimer
```

Découpage en **phases** (chaque phase a sa propre vérification avant de passer à
la suivante) :

- **Phase 1** : corpus (téléchargement, chunking par article).
- **Phase 2** : RAG (index, retrieval, LLM, évaluation chiffrée).
- **Phase 3** : backend FastAPI + garde-fous.
- **Phase 4** : app mobile Flutter.
- **Phase 5** (à venir) : veille juridique automatisée.

---

<a name="3-phase-1--corpus"></a>
## 3. Phase 1 — Pipeline corpus (`corpus/`)

### 3.1 Sources
- **Adala** (`adala.justice.gov.ma`) — portail officiel du ministère de la
  Justice. Source primaire. Crawlé via le JSON `__NEXT_DATA__` des pages
  `/fr/resources/{id}` (racine FR : 338, racine AR : 1).
- **Pourquoi pas une API juridique tierce ?** Il n'existe pas de source ouverte,
  fiable et officielle pour le droit marocain consolidé. On part donc des PDFs
  officiels, ce qui garantit l'**authenticité** (et un hash SHA-256 par fichier).

### 3.2 Scripts (`corpus/scripts/`)
| Script | Rôle | Pourquoi |
|---|---|---|
| `crawl_adala.py` | Inventorie les textes via `__NEXT_DATA__`. | Les URLs Adala portent des **timestamps qui changent** à chaque réupload → il faut recrawler, pas hardcoder. |
| `download_corpus.py` | Télécharge + valide l'en-tête `%PDF` + calcule SHA-256. | Détecte les WAF/erreurs HTML servies à la place du PDF ; le hash sert à la **veille** (détecter une mise à jour). |
| `chunk_codes.py` | Découpe chaque PDF en **1 chunk = 1 article**. | Cœur de la qualité (voir 3.3). |
| `normalize_ar.py` | Normalise l'arabe extrait (NFKC, lam-alef, chiffres). | Sans ça, le matching des marqueurs `المادة`/`الفصل` échoue. |
| `validate_chunks.py` | Contrôle qualité (continuité des numéros, FR vs AR). | Un trou = article raté ; un chunk minuscule = parsing cassé. |
| `ocr_ar.py` | **Re-OCR des PDFs arabes** (voir §4). | La couche texte AR est corrompue. |

Fichiers pivots : `manifest.json` (**source de vérité** : URLs, dates de version
`maj_adala`), `registry.json` (SHA-256 par fichier), `adala_inventory_*.json`.

### 3.3 Chunking par article — la décision la plus importante
**1 chunk = 1 article de loi.** Jamais de découpe par fenêtre de tokens.

**Pourquoi ?** Un article tronqué au milieu = une citation fausse (viole C1). En
droit, l'unité de sens et de citation **est** l'article. Le chunk porte :
`code, langue, article_num, num_int, marqueur (المادة/الفصل/Article), hierarchie
(livre/titre/chapitre), texte intégral, version (date), sha256_source`.

**Pièges résolus** (documentés dans le code) :
- Détection auto du marqueur dominant par document : `الفصل` (Code pénal, DOC,
  Constitution) vs `المادة` (Moudawana, Code du travail…).
- **Plus longue chaîne croissante (DP)** pour sélectionner les vrais en-têtes :
  les références croisées (« المنصوص عليها في المادة 23 ») cassent une approche
  gloutonne ; la chaîne monotone la plus longue isole les vrais en-têtes.
- Suppression des **titres courants** uniquement aux **bords** de page (sinon on
  efface un `المادة` isolé sur sa ligne).
- On ne supprime **jamais** les lignes de chiffres nus (ce sont souvent des
  valeurs du texte : montants, durées, barèmes).

---

<a name="4-arabe--ocr"></a>
## 4. Le problème de l'arabe + la solution OCR

### 4.1 Le diagnostic (vérifié)
L'extraction de la **couche texte** des PDFs arabes (PyMuPDF) produit un texte
**corrompu et AMBIGU** :
- **Espaces intra-mot** : `المادة` → `ال مادة`, `يستحق` → `يس تحق`.
- **Ligatures lam-alef inversées** : `العلاقة` → `العالقة`, `خلال` → `خالل`.
- **Pire** : `لا` (négation) et `ال` (article défini) deviennent **indistinguables**.
  `ال تتنافى` devrait être `لا تتنافى` (négation), mais `ال مادة` devrait être
  `المادة` (article). **Même forme de surface, corrections opposées.**

Mesure : **tous** les codes AR sont touchés (15–23 % de tokens fragmentés). La
corruption est **dans la couche texte du PDF**, pas dans notre pipeline (vérifié
en comparant l'extraction brute au chunk).

**Conséquence : aucun correctif déterministe par chaîne de caractères n'est sûr**
pour un texte juridique (on risquerait de transformer `طالب`→`طلاب`, ou d'inverser
une négation = inverser le sens de la loi).

### 4.2 La solution : OCR des pages rendues (`ocr_ar.py`)
On **ignore** la couche texte cassée et on lit les **glyphes affichés** :
1. Rendu de chaque page en image (PyMuPDF, ~288 dpi).
2. **Tesseract** (`-l ara`, `--psm 4`) lit l'image → texte propre.

Preuve (Moudawana art. 114) :
- Couche texte : `إنهاء العالقة الزوجية … بشروط ال تتنافى … وال تضر`
- OCR : `إنهاء العلاقة الزوجية … بشروط لا تتنافى … ولا تضر` ✅
  (`العلاقة`, `لا`, `ولا` corrects — l'OCR lit les vrais glyphes, l'ambiguïté
  disparaît.)

### 4.3 Les deux garde-fous (sans quoi l'OCR régresse)
L'OCR n'est pas parfait : il rate ~10 % des en-têtes (erreurs sur les chiffres) et
parfois garbote un corps d'article. `chunk_codes.py` (mode OCR) applique donc :
- **Garde anti-garbage** : si un corps OCR est anormalement court vs l'ancien
  (texte couche), on **garde l'ancien** (ex. art. 19 OCRisé `المادة 19©0` → on
  conserve le texte d'origine, complet mais bruité).
- **Complétion** : tout article que l'OCR a manqué est **repris de l'ancien
  chunking** → **aucun article perdu**.

Résultat Moudawana : **346/400 articles en OCR propre, 54 conservés** (corrects mais
bruités), **0 perdu, 0 garboté**. Cache OCR dans `corpus/ocr/{code}_ar.txt` (OCR
lent → mis en cache, ré-utilisé par le chunker).

> **Pourquoi pas un LLM pour nettoyer l'arabe ?** Trop risqué (un LLM peut altérer
> un texte juridique **qui fait foi**) et trop coûteux (~5 500 chunks AR × quota).

---

<a name="5-phase-2--rag"></a>
## 5. Phase 2 — Cœur RAG (`rag/`)

### 5.1 Embeddings : **BGE-M3** (`BAAI/bge-m3`)
**Quoi** : modèle d'embedding qui produit, en **une passe**, un vecteur **dense**
(1024 dims, sémantique) **et** des poids **sparse** (lexical, façon BM25 appris).

**Pourquoi BGE-M3 ?**
- **Multilingue natif** (FR + AR couverts) → recherche cross-lingue sans traduire.
- **Dense + sparse en un seul modèle** → on obtient le retrieval hybride sans
  empiler deux systèmes (un encodeur dense + un BM25 séparé).
- Open-source, exécutable en local (pas de dépendance API pour l'indexation).

**Alternatives écartées** : OpenAI `text-embedding-3` (API payante, pas de sparse,
données envoyées à un tiers) ; `multilingual-e5` (dense seulement) ; BM25 pur
(pas de sémantique, rate les reformulations).

**Piège** : BGE-M3 **se bloque sur MPS** (GPU Apple) pour les longues séquences →
on **force le CPU** (`CHAWERNI_DEVICE=cpu`). Plus lent à l'indexation (~75 min pour
11k chunks) mais fiable et **une seule fois**.

### 5.2 Base vectorielle : **Qdrant**
**Pourquoi Qdrant ?**
- Support **natif des vecteurs nommés** (dense + sparse dans la même collection) et
  de la **fusion RRF** côté serveur (Query API) → le retrieval hybride est une seule
  requête.
- **Mode local sur disque** (`rag/.qdrant/`) pour le dev — aucun serveur, aucun
  Docker requis pour itérer. Bascule **Qdrant Cloud** (free 1 Go) en prod via
  `QDRANT_URL` + `QDRANT_API_KEY`, sans changer le code.
- Filtres de payload (langue, code, n° d'article) pour scoper la recherche.

**Alternatives écartées** : pgvector (pas de sparse natif ni RRF) ; Pinecone/Weaviate
(SaaS, moins simple en local) ; FAISS (pas de payload/filtres/serveur).

**Idempotence** : l'ID d'un point = `uuid5(code, article_num, langue, version)` →
réindexer un code **remplace** ses points sans toucher au reste (essentiel pour la
veille juridique : un texte mis à jour = ré-indexation ciblée).

### 5.3 Retrieval hybride (`rag/retrieve.py`)
Trois étages, dans l'ordre :
1. **Court-circuit lexical** : si la requête nomme un article (`article 446`,
   `الفصل 490`, ou un **numéro nu** « 446 »), on va le chercher **directement par
   payload** (`num_int` + code éventuel). Une référence exacte ne doit jamais
   dépendre du hasard vectoriel.
2. **Hybride dense + sparse → fusion RRF** (Qdrant) pour les questions sémantiques.
3. **Gate de pertinence** : on garde la **similarité cosinus dense** du meilleur
   résultat ; sous `DENSE_SCORE_MIN` (≈ 0,50) → liste vide → le bot **refuse
   honnêtement** (« je ne trouve pas de texte applicable ») plutôt que d'inventer (C1).

> Pourquoi gater sur le **cosinus dense** et pas le score RRF ? Le RRF n'est pas
> borné et la recherche dense renvoie toujours des voisins. Le cosinus borné [0,1]
> est un meilleur signal « hors-corpus ».

### 5.4 La darija = couche de reformulation LLM (décision clé)
**Mesure** : en embedding, la darija (cosinus médian ~0,53) est **inséparable** du
hors-corpus (~0,54). Elle ne se « retrieve » pas brute.
**Solution** : on **reformule** la darija → arabe standard (fusha) **avant** le
retrieval, via un LLM. La réponse, elle, reste en darija (langue de l'utilisateur).
→ la darija passe de **0,10** à **0,80** de succès@5.

### 5.5 Abstraction LLM : **Groq** (`rag/llm.py`)
**Quoi** : interface unique `LLMProvider.generate(messages)` ; implémentation Groq
via le SDK **OpenAI-compatible** (`base_url = https://api.groq.com/openai/v1`).

**Pourquoi Groq ?** Inférence très rapide, peu coûteuse, bon FR/AR, API standard.
**Pourquoi une abstraction ?** Changer de fournisseur = ajouter une classe, sans
toucher au retriever ni au backend.

**Architecture bi-modèle** (mesurée et décidée) :
- **Réponses → `llama-3.3-70b-versatile`** (qualité : sur « loyer », trouve le bon
  article 667, citations propres, complet — le 8B tronquait et cassait les citations).
- **Reformulation darija → `llama-3.1-8b-instant`** (`GROQ_MODEL_FAST`) : tâche
  courte où le 8B est **meilleur pour le retrieval** (0,80 vs 0,60 avec le 70B) **et**
  économe.

**Prompt système** : rôle (information, pas conseil — C2) ; **citation obligatoire**
au format `[Nom du code, Article N°, JJ/MM/AAAA]` reprise telle quelle du contexte ;
**refus** (`INSUFFISANT`) si le contexte ne répond pas ; réponse dans la **langue de
la question**. `build_context` injecte les vrais noms de code + dates formatées.

**Pièges** : `llama-3.3-70b` est plafonné à **100 000 tokens/jour** en free tier
(une éval complète l'épuise) → backoff sur 429, et Dev tier (payant) pour la charge.

### 5.6 Évaluation chiffrée — la **gate** (`rag/eval/`)
50 questions de référence (FR + AR) typées : `exact` (numéro), `semantic`, `darija`,
`out_of_corpus` (refus attendu). Métriques :
- **success@5** = au moins un article attendu dans le top-5 (la **gate** : ≥ 0,80).
  *Pourquoi pas la precision@5 brute ?* Une question juridique n'a souvent qu'**1**
  article pertinent → precision/5 plafonne à 0,2 ; le **taux de succès@5** est la
  métrique RAG pertinente.
- `citation_rate` du LLM (chaque `[Code, Art.]` cité existe dans le contexte → zéro
  invention), `refusal_accuracy` (hors-corpus → refus).

**Résultat** : success@5 = **0,93** (exact 1,00 / sémantique 0,95 / darija 0,80) ;
citation_rate **0,944**. On ne passe pas en Phase 3 sans cette gate.

---

<a name="6-phase-3--backend"></a>
## 6. Phase 3 — Backend API (`backend/`)

### 6.1 **FastAPI** + Uvicorn
**Pourquoi** : Python (même langage que le RAG → import direct de `rag.pipeline`,
pas de pont réseau interne), async, validation **Pydantic** automatique, OpenAPI
gratuit, léger.

### 6.2 Endpoints
| Endpoint | Rôle |
|---|---|
| `GET /health` | état + modèle + nb de points indexés |
| `POST /ask` | question → réponse sourcée + gates de sécurité + disclaimer |
| `GET /codes` | les 13 codes (titre FR/AR, version, nb d'articles) — Bibliothèque |
| `GET /codes/{code}/articles` | **parcours paginé** des articles d'un code |
| `GET /sources/{code}/{article}` | texte intégral d'un article (carte cliquable) |
| `GET /search` | recherche d'articles (hybride + n° exact), globale ou par code |
| `POST /feedback` | signal anonyme (loi 09-08 : aucun contenu) |

### 6.3 Garde-fous (C2/C3)
- **Pré-LLM** : détection d'enjeu grave (pénal, garde d'enfants, violence,
  licenciement…) → on lève un **bandeau « un avocat est indispensable »** sans
  bloquer l'information.
- **Post-LLM** : on **vérifie** que chaque citation `[Code, Article]` de la réponse
  existe dans les chunks fournis (sinon on logue/dégrade). Anti-hallucination (C1).
- **Disclaimer systématique** dans chaque réponse.
- **Logs loi 09-08** : on logue `langue / grave / refused / nb sources / latence` —
  **jamais** le texte de la question.

### 6.4 Repli de langue (codes AR-only)
3 codes n'ont **pas** de version FR (`code_route`, `organisation_judiciaire`,
`accidents_travail`). Le backend **bascule automatiquement** sur l'arabe pour le
parcours / la recherche / le texte intégral si la langue demandée n'existe pas pour
ce code → **les 13 codes fonctionnent** quelle que soit la langue de l'app.

---

<a name="7-phase-4--flutter"></a>
## 7. Phase 4 — App mobile Flutter (`chawerni_app/`)

### 7.1 **Flutter** (Dart)
**Pourquoi** : un seul code pour **iOS + Android**, rendu natif, **RTL natif** via
`Directionality` (crucial pour l'arabe), excellent pour des UIs sur-mesure (le
design system Chawerni est très spécifique).

### 7.2 Architecture d'état — volontairement légère
- `AppState` (`ChangeNotifier`) + `AppScope` (`InheritedNotifier`) : langue, étape
  du parcours, taille de texte, onglet actif, question en attente (Hoquqi→Chat).
- **Pourquoi pas Riverpod/Bloc/Provider ?** L'app a peu d'état global ; la solution
  Flutter native (`InheritedNotifier`) suffit, **zéro dépendance** d'état, persistance
  via `shared_preferences`.

### 7.3 Design system (`docs/design.md`, dossier `brand/`)
Tension « **rigueur notariale × hospitalité marocaine** ».
- **Couleurs nommées en darija** (tokens portés 1:1 du design system) : `nila`
  #2D3A8C (primaire), `zaafran` #E8A13D (accent citation), `zellij` #0E7C6B
  (succès/sources), `warqa` #FAF7F1 (**fond papier — jamais de blanc pur**), `aker`
  #B3382C (disclaimers), `midad` #1E1B18 (encre).
- **Motif zellige** (losange) : seul glyphe décoratif autorisé (frises, dots, puces).
- **Pas de clichés justice** (balance, marteau, colonnes) — sauf l'icône d'app
  fournie par l'utilisateur.

### 7.4 Dépendances Flutter et **pourquoi chacune**
| Paquet | Rôle | Pourquoi |
|---|---|---|
| `google_fonts` | **IBM Plex Sans** + **IBM Plex Sans Arabic** | Même famille des deux côtés = cohérence bilingue parfaite ; chargé au 1er run puis caché. |
| `flutter_svg` | icônes **Lucide** rendues depuis leurs path SVG | Trait fin cohérent « rigueur × hospitalité » ; les Material Icons sont pleines, pas tracées. |
| `http` | appels `/ask`, `/codes`, `/sources`, `/search` | Client HTTP simple, suffisant (pas besoin de dio). |
| `shared_preferences` | persistance langue / flow / taille de texte | Stockage clé-valeur natif, léger. |
| `flutter_launcher_icons` | génère les icônes iOS/Android depuis `image.png` | Une source → toutes les tailles + icône adaptative Android. |

### 7.5 Écrans
Onboarding (3) → Disclaimer bloquant (C2) → 4 onglets :
- **Chat** : bulles, **cartes sources** signature (barre zaafran, n° d'article,
  badge de version daté, animation « document qui se déplie »), bandeau enjeu grave,
  refus honnête, repli scénarios scriptés si pas d'API.
- **Bibliothèque** : 13 codes → détail (parcours paginé + recherche n°/mot-clé) →
  bottom-sheet texte intégral (toggle ع/FR, copie).
- **Hoquqi** (حقوقي) : fiches par situation → ouvrent le Chat avec la question
  pré-posée (RAG).
- **Réglages** : langue, taille de texte (3 crans), rejouer l'onboarding.

### 7.6 Intégration API
`CHAWERNI_API_BASE` injecté à la compilation (`--dart-define`). **Sans API** (build
démo) → l'app retombe sur des **scénarios scriptés** (chat hors-ligne pour la démo).
ATS iOS (`NSAllowsLocalNetworking`) autorise le HTTP local en test ; la prod est en
HTTPS (Caddy).

---

<a name="8-deploiement"></a>
## 8. Déploiement & infrastructure (V1 — GitHub Student Pack)

| Brique | Choix | Pourquoi |
|---|---|---|
| **Image API** | `Dockerfile` (Python 3.11-slim, **torch CPU-only**) | torch CPU = image bien plus légère que la build CUDA ; BGE-M3 tourne en CPU. |
| **Orchestration** | `docker-compose.yml` (api + Caddy) | Un `up -d --build` lance tout. |
| **TLS / reverse proxy** | **Caddy** (`Caddyfile`) | Certificat Let's Encrypt **automatique** (zéro config TLS). |
| **Compute** | **DigitalOcean** droplet 4 Go | Crédit **200 $** du GitHub Student Pack (~8 mois). BGE-M3 a besoin de ~4 Go RAM. |
| **Index vectoriel** | **Qdrant Cloud** (free 1 Go) | 11k articles tiennent large ; libère la RAM du droplet. |
| **LLM** | **Groq** API | hors pack, free tier. |
| **Domaine** | **Namecheap / .TECH** (gratuit 1 an) | du pack. |
| **CI/CD** | **GitHub Actions** (`deploy-api`, `build-apk`) | build image → GHCR → SSH deploy ; build APK en release. |
| **App** | **mobile** (APK/IPA) | distribution directe APK ou stores ; **pas** de version web. |

L'index se pousse sur le Cloud avec le **même script** (`QDRANT_URL`+`QDRANT_API_KEY`
puis `python -m rag.index`). Voir `DEPLOY.md` pour le pas-à-pas.

---

<a name="9-securite"></a>
## 9. Sécurité & conformité

- **Secrets** : `GROQ_API_KEY`, `QDRANT_API_KEY` dans `rag/.env` (**git-ignoré**) ou
  variables d'env. Seul `.env.example` (placeholders) est versionné. Vérifié : aucune
  vraie clé dans le dépôt.
- **Loi 28-08** : disclaimer + bandeau avocat + refus honnête + vérif des citations.
- **Loi 09-08** : logs sans contenu ; hébergement marocain prévu pour la prod avec
  comptes ; OCR/index/LLM ne stockent pas les questions utilisateurs.
- **CORS** ouvert (app native, pas d'origine web), TLS en prod.

---

<a name="10-recap"></a>
## 10. Tableau récapitulatif des technologies

| Couche | Techno | Rôle | Alternative écartée (et pourquoi) |
|---|---|---|---|
| Langage RAG/back | **Python 3.11+** | corpus, RAG, API | — (écosystème ML/PDF) |
| Extraction PDF | **PyMuPDF (fitz)** | texte + rendu pages | pdfminer (gardé en repli miroir) |
| OCR arabe | **Tesseract `ara`** | lire les glyphes (couche texte cassée) | LLM-clean (altère le texte de loi) |
| Embeddings | **BGE-M3** | dense + sparse multilingue | OpenAI embeddings (API, pas de sparse) ; e5 (dense seul) |
| Base vectorielle | **Qdrant** | index + RRF + filtres | pgvector (pas de sparse/RRF) ; Pinecone (SaaS) |
| LLM | **Groq** (Llama 3.3 70B / 3.1 8B) | génération + reformulation | OpenAI/Anthropic (coût/latence) — abstraction = swappable |
| API | **FastAPI** + Uvicorn | endpoints HTTP | Flask (pas d'async/validation native) |
| Validation | **Pydantic** | schémas req/resp | — |
| App | **Flutter / Dart** | iOS + Android, RTL | React Native (RTL/perf), natif ×2 (coût) |
| Polices | **IBM Plex Sans (+ Arabic)** via `google_fonts` | bilingue cohérent | Noto (moins « signature ») |
| Icônes | **Lucide** via `flutter_svg` | trait fin | Material Icons (pleines) |
| Conteneur | **Docker** + Compose | déploiement | — |
| TLS | **Caddy** | HTTPS auto | nginx + certbot (plus de config) |
| Hébergement | **DigitalOcean + Qdrant Cloud** | V1 (Student Pack) | — |
| CI/CD | **GitHub Actions** | build + deploy | — |

---

<a name="11-limites"></a>
## 11. Limites connues & dette technique

- **Qualité arabe** : l'OCR corrige ~87 % des articles ; ~13 % gardent le texte
  d'origine (bruité mais complet) + artefacts de ponctuation OCR (`»` pour `،`).
  Amélioration possible : OCR plus haute résolution / post-correction ciblée.
- **70B free tier** : 100k tokens/jour → suffisant pour des requêtes utilisateur
  ponctuelles, insuffisant pour des évals/charge lourdes (passer au Dev tier).
- **Refus hors-corpus** : ~0,5 au niveau pipeline (le 8B émet peu le sentinel
  `INSUFFISANT`) ; s'améliore avec un meilleur modèle.
- **Bibliothèque hors-ligne** : actuellement servie par l'API ; le design prévoit un
  embarquement **SQLite** des chunks pour une vraie consultation offline (à faire).
- **Hébergement Maroc** : requis (loi 09-08) dès qu'il y aura des comptes/données
  utilisateurs ; le V1 démo (anonyme, logs sans contenu) peut tourner ailleurs.
- **Veille juridique (Phase 5)** : non automatisée encore (recrawl + diff hash +
  ré-indexation idempotente prévus).
