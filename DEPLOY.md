# Déploiement Chawerni V1 (GitHub Student Pack)

App **mobile** (Flutter APK/IPA) + API **FastAPI/BGE-M3** sur un droplet DigitalOcean,
index sur **Qdrant Cloud** (free), LLM **Groq** (free). Coût ≈ 0 grâce au pack étudiant.

```
 App mobile (APK/IPA)  ──HTTPS──▶  Caddy ─▶ API FastAPI ──▶ Groq (LLM)
                                              │
                                              └──▶ Qdrant Cloud (index BGE-M3)
```

## 0. Ressources à réclamer (GitHub Student Pack)

| Ressource | Offre pack | Usage |
|---|---|---|
| **DigitalOcean** | crédit **200 $ / 1 an** | droplet API (≈ 24 $/mois → ~8 mois) |
| **Namecheap** ou **.TECH** | domaine gratuit 1 an + SSL | `chawerni.me` / `chawerni.tech` |
| **Sentry** | plan dev gratuit | suivi d'erreurs (optionnel) |
| Groq | hors pack, free tier | LLM (clé `GROQ_API_KEY`) |
| Qdrant Cloud | hors pack, free 1 Go | index vectoriel (11k articles tiennent large) |

> ⚠ Loi 09-08 : tant qu'il n'y a pas de comptes/données perso (V1 anonyme, logs sans
> contenu), l'hébergement hors Maroc est acceptable. À rapatrier au Maroc dès qu'on
> stocke des données utilisateurs.

## 1. Index → Qdrant Cloud

1. Crée un cluster gratuit sur cloud.qdrant.io → note l'**URL** et l'**API key**.
2. Depuis ta machine (l'index est déjà construit en local) :

```bash
cd "Chawerni _Apps"
export QDRANT_URL="https://xxxx.eu-central.aws.cloud.qdrant.io:6333"
export QDRANT_API_KEY="xxx"
rag/.venv/bin/python -m rag.index --recreate    # pousse les 10 960 points vers le Cloud
```

(Le même script qu'en local : `store.py` bascule sur le Cloud dès que `QDRANT_URL` est défini.)

## 2. Droplet DigitalOcean

1. Crée un droplet **Ubuntu 22.04, 4 Go RAM** (BGE-M3 a besoin de ~4 Go). Ajoute ta clé SSH.
2. Installe Docker :

```bash
ssh root@<IP_DROPLET>
curl -fsSL https://get.docker.com | sh
mkdir -p /opt/chawerni && cd /opt/chawerni
git clone <ton-repo> .            # ou rsync du dossier (sans rag/.venv ni corpus/raw)
cp .env.example .env && nano .env  # GROQ_API_KEY, QDRANT_URL, QDRANT_API_KEY, DOMAIN
docker compose up -d --build       # 1er boot : ~quelques min (téléchargement BGE-M3)
```

3. Vérifie : `curl -s localhost:8000/health` (via le conteneur api), puis attends le healthcheck vert.

## 3. Domaine + TLS

1. Dans Namecheap (domaine du pack), crée un enregistrement **A** : `chawerni.me` → `<IP_DROPLET>`.
2. Mets `DOMAIN=chawerni.me` dans `.env`. Caddy obtient le certificat Let's Encrypt automatiquement.
3. Test : `curl https://chawerni.me/health` → `{"status":"ok", ...}`.

## 4. App mobile

`CHAWERNI_API_BASE` est injecté à la compilation :

```bash
cd chawerni_app
flutter build apk --release --dart-define=CHAWERNI_API_BASE=https://chawerni.me   # Android
flutter build ipa --release --dart-define=CHAWERNI_API_BASE=https://chawerni.me   # iOS (Xcode/compte Apple)
```

Distribue l'APK directement (ou Play Store / TestFlight). En CI, le tag `v1.0.0`
déclenche `build-apk.yml` qui publie l'APK en release (variable repo `API_DOMAIN`).

## 5. CI/CD (optionnel)

`deploy-api.yml` build l'image (GHCR) et redéploie sur le droplet à chaque push `main`.
Secrets repo : `DROPLET_HOST`, `DROPLET_USER`, `DROPLET_SSH_KEY`. Variable : `API_DOMAIN`.

## 6. Réglages & qualité

- **Modèle LLM** : `GROQ_MODEL` dans `.env`. Aujourd'hui seul `llama-3.1-8b-instant`
  est servi par ton org Groq (scout 403, maverick 404). Dès qu'un modèle 70B est
  disponible, change cette seule ligne — citation_rate et refus s'amélioreront.
- **Seuil de refus** : `rag/config.py` → `DENSE_SCORE_MIN`.
- **Santé** : `GET /health` ; **logs** : `docker compose logs -f api` (jamais le
  contenu des questions — loi 09-08).
- **Sécurité** (loi 28-08) : disclaimer systématique + bandeau « avocat » sur les
  sujets graves + vérification des citations (gate post-LLM) déjà actifs.
