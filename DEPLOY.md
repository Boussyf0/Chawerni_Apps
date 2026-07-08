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
| **DigitalOcean** | crédit **200 $ / 1 an** | droplet API 8 Go (≈ 48 $/mois → ~4 mois) |
| **Namecheap** ou **.TECH** | domaine gratuit 1 an + SSL | `chawerni.me` / `chawerni.tech` |
| **Sentry** | plan dev gratuit | suivi d'erreurs (optionnel) |
| Groq | hors pack, free tier | LLM (clé `GROQ_API_KEY`) |
| Qdrant Cloud | hors pack, free 1 Go | index vectoriel (11k articles tiennent large) |

> ⚠ Loi 09-08 : tant qu'il n'y a pas de comptes/données perso (V1 anonyme, logs sans
> contenu), l'hébergement hors Maroc est acceptable. À rapatrier au Maroc dès qu'on
> stocke des données utilisateurs.

## 1. Index → Qdrant Cloud ✅ FAIT (2026-06-15)

Cluster free déjà créé et **index poussé** : collection `chawerni_articles` =
**11 096 points** (23 fichiers FR+AR), retrieval vérifié OK. Rien à refaire.

> Pour re-pousser un jour (ex. corpus mis à jour) : `store.py` bascule sur le Cloud
> dès que `QDRANT_URL` est défini. Le push ré-embed BGE-M3 en CPU (~plusieurs h) ;
> upsert durci (timeout 120 s, batch 128, retry) pour éviter les « write timed out ».
> ```bash
> QDRANT_URL="https://…:6333" QDRANT_API_KEY="…" CHAWERNI_DEVICE=cpu \
>   rag/.venv/bin/python -m rag.index --recreate
> ```

## 2. Droplet DigitalOcean

1. Crée un droplet **Ubuntu 24.04, 8 Go RAM / 2 vCPU** (≈ 48 $/mois, gratuit ~4 mois
   avec le crédit Student). 8 Go est nécessaire : le **build Docker** de l'image ML
   (torch + BGE-M3 2,3 Go) ET le runtime (BGE-M3 en RAM ~2,5–3 Go) ne tiennent pas
   sur 4 Go — c'est ce qui faisait planter le builder d'App Platform. Ajoute ta clé SSH.
2. Installe Docker et build :

```bash
ssh root@<IP_DROPLET>
curl -fsSL https://get.docker.com | sh
mkdir -p /opt/chawerni && cd /opt/chawerni
git clone https://github.com/Boussyf0/Chawerni_Apps .   # ou rsync (sans rag/.venv ni corpus/raw)
cp .env.example .env && nano .env   # GROQ_API_KEY, GROQ_MODEL(_FAST), QDRANT_URL, QDRANT_API_KEY, DOMAIN
docker compose up -d --build        # build ~5-10 min (DL BGE-M3 baké dans l'image)
```

3. Vérifie : `docker compose exec api curl -s localhost:8000/health`, puis attends le
   healthcheck vert (`docker compose ps`). Le modèle est **baké dans l'image** → pas
   de download au boot, juste le chargement en RAM (~1 min).

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

- **Modèle LLM** (bi-modèle) : `GROQ_MODEL=openai/gpt-oss-120b` (réponses, qualité ;
  remplace llama-3.3-70b, décommissionné le 16/08/2026) + `GROQ_MODEL_FAST=openai/gpt-oss-20b`
  (reformulation darija ; remplace llama-3.1-8b, décommissionné le 16/08/2026). ⚠ Le free
  tier est plafonné en tokens/JOUR ; si tu épuises le quota (429 TPD), rabats temporairement
  `GROQ_MODEL` sur le modèle rapide ou passe au Dev tier payant.
- **Seuil de refus** : `rag/config.py` → `DENSE_SCORE_MIN`.
- **Santé** : `GET /health` ; **logs** : `docker compose logs -f api` (jamais le
  contenu des questions — loi 09-08).
- **Sécurité** (loi 28-08) : disclaimer systématique + bandeau « avocat » sur les
  sujets graves + vérification des citations (gate post-LLM) déjà actifs.
