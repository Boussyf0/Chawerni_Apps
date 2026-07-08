# 📘 Guide maître — Chawerni (شاورني)

Tout ce qui a été construit, où ça vit, et comment l'opérer. Écrit pour que tu
puisses tout comprendre et tout refaire seul. Garde ce fichier sous la main.

> **Repère mental** : il y a **3 machines** dans ta tête.
> 1. 💻 **Ton Mac** : le code source, le build de l'app, les outils.
> 2. ☁️ **Le Droplet** (serveur DigitalOcean, IP `164.90.216.143`) : l'API en ligne.
> 3. 📱 **Le téléphone** : l'app installée.
>
> Et **2 services cloud externes** : **Qdrant** (la base de l'index) et **Groq** (l'IA).

---

## 1. Vue d'ensemble (l'architecture)

```
   📱 App mobile (Flutter)
        │  HTTPS
        ▼
   ☁️ Droplet 164.90.216.143  ───────────────┐
   ┌─────────────────────────────┐           │
   │ Caddy (HTTPS, certificat auto)│          │
   │        │                      │          │
   │        ▼                      │          │
   │ API FastAPI + BGE-M3 (Docker) │          │
   └───────┬───────────────┬───────┘          │
           │               │                  │
           ▼               ▼                  ▼
   🔎 Qdrant Cloud     🧠 Groq (LLM)    (app-ads.txt, /privacy)
   (index, 11096        120B + 20B
    fragments)
```

**Ce qui se passe quand tu poses une question :**
1. L'app envoie ta question (+ l'historique récent) à l'API.
2. Si c'est de la darija ou une question de suivi → le **modèle rapide** la reformule en
   question autonome en arabe standard.
3. L'API transforme la question en vecteur (**BGE-M3**) et cherche les articles les
   plus proches dans **Qdrant**.
4. Les articles trouvés + ta question partent au **modèle qualité (Groq)** qui rédige la
   réponse, dans **ta langue**, en citant les articles.
5. Des garde-fous vérifient qu'aucune citation n'est inventée, ajoutent le disclaimer.
6. L'app affiche la réponse + les cartes sources cliquables.

---

## 2. Les composants et où ils vivent

| Composant | Emplacement | Rôle |
|---|---|---|
| Code source | `github.com/Boussyf0/Chawerni_Apps` (privé) | source de vérité |
| API (backend) | Droplet `/opt/chawerni`, Docker | sert `/ask`, `/codes`, `/translate`… |
| Modèle BGE-M3 | **baké** dans l'image Docker | transforme texte → vecteur |
| Index vectoriel | **Qdrant Cloud** (`871b2393-…`) | 11 096 fragments d'articles |
| LLM | **Groq** (gpt-oss-120b réponses, 8B reformulation/traduction) | rédige les réponses |
| HTTPS | **Caddy** sur le droplet + `nip.io` | certificat Let's Encrypt auto |
| App | Flutter, package `ma.chawerni.chawerni` | l'app Android |
| Auto-deploy | GitHub Actions (`.github/workflows/deploy-api.yml`) | redéploie à chaque push |

---

## 3. Comptes, secrets et où ils sont

| Secret | Où il vit | Notes |
|---|---|---|
| `GROQ_API_KEY` | `/opt/chawerni/.env` (droplet) | clé de l'IA Groq |
| `QDRANT_URL` / `QDRANT_API_KEY` | `/opt/chawerni/.env` (droplet) | accès à l'index |
| Clé de déploiement (pull GitHub) | droplet `~/.ssh/deploy_key` | lecture seule |
| Clé GitHub Actions → droplet | secret repo `DROPLET_SSH_KEY` | + `DROPLET_HOST`, `DROPLET_USER` |
| Keystore de signature de l'app | `chawerni_app/android/app/chawerni-release.keystore` | **⚠ SAUVEGARDE-LE** |
| Mot de passe du keystore | `chawerni_app/android/key.properties` | hors git |

> 🔒 **Aucun secret n'est dans git** (`.env`, keystore, `key.properties` sont ignorés).
> Les secrets qui ont transité pendant la mise en place (Groq, Qdrant, token GitHub,
> clé `gha_deploy`) **devraient être régénérés** avant un lancement public — voir §11.

> 🚨 **À sauvegarder absolument** : le **keystore** + `key.properties`. Si tu les perds,
> tu ne pourras plus jamais mettre à jour l'app sur le Play Store. Copie-les dans un
> endroit sûr (gestionnaire de mots de passe / cloud privé).

---

## 4. Opérations courantes (commandes prêtes)

### 4.1 Se connecter au serveur (droplet)
Sur ton Mac, charge d'abord ta clé SSH (une fois par session) :
```
ssh-add ~/.ssh/id_rsa
```
Puis :
```
ssh root@164.90.216.143
```
Tu peux aussi utiliser la **console web** : DigitalOcean → ton droplet → *Access → Launch Console*.
⚠️ La console web **casse les collages multi-lignes** → colle **une commande à la fois**.

### 4.2 Voir si l'API va bien
Depuis n'importe où :
```
curl https://164.90.216.143.nip.io/health
```
Réponse attendue : `{"status":"ok","model":"openai/gpt-oss-120b","points":11096}`

### 4.3 Mettre à jour le backend (manuel)
Sur le droplet :
```
cd /opt/chawerni && git pull && docker compose up -d --build api
```

### 4.4 Voir les logs de l'API
Sur le droplet :
```
cd /opt/chawerni && docker compose logs -f api
```
(`Ctrl+C` pour quitter — ça n'arrête pas l'API.) On ne logge **jamais** le contenu des
questions (loi 09-08), seulement des compteurs.

### 4.5 Redémarrer / arrêter l'API
```
cd /opt/chawerni
docker compose restart api      # redémarrer
docker compose up -d            # tout relancer (api + caddy)
docker compose down             # tout arrêter
docker compose ps               # état des conteneurs
```

### 4.6 Modifier une variable d'environnement (ex. changer de modèle)
```
nano /opt/chawerni/.env         # édite la valeur
docker compose up -d api        # applique
```

---

## 5. Le déploiement automatique (CI/CD)

**Comment ça marche** : dès que tu **pushes sur `main`** un changement dans
`backend/`, `rag/`, `Dockerfile`, `docker-compose.yml` ou `Caddyfile`, GitHub Actions :
1. se connecte au droplet en SSH,
2. fait `git pull`,
3. `docker compose up -d --build api`.

**Ton flux de travail au quotidien** (depuis le Mac) :
```
git add .
git commit -m "ce que j'ai changé"
git push
```
→ Le serveur se met à jour tout seul en ~30 s à 2 min.

**Suivre / déclencher manuellement** (depuis le Mac, avec le CLI `gh`) :
```
gh run list --workflow=deploy-api.yml --limit 3        # voir les déploiements
gh workflow run deploy-api.yml --ref main              # forcer un déploiement
```

> ⚠️ Les changements de l'**app Flutter** (dossier `chawerni_app/`) **ne déclenchent
> PAS** ce déploiement (normal : l'app se rebuild séparément, voir §6).

---

## 6. Construire et installer l'app

### 6.1 Règle d'or
Après **toute modification de code Dart**, fais d'abord :
```
cd "/Users/abderrahim_boussyf/Chawerni _Apps/chawerni_app"
flutter clean
```
> Sinon un **cache périmé** peut produire un APK sans tes changements (piège rencontré).

### 6.2 Construire l'APK (pour installer / partager directement)
```
flutter build apk --release --dart-define=CHAWERNI_API_BASE=https://164.90.216.143.nip.io
```
Résultat : `build/app/outputs/flutter-apk/app-release.apk`

### 6.3 Construire l'AAB (pour le Play Store)
```
flutter build appbundle --release --dart-define=CHAWERNI_API_BASE=https://164.90.216.143.nip.io
```
Résultat : `build/app/outputs/bundle/release/app-release.aab`

### 6.4 Installer sur le téléphone (USB ou wifi-adb)
```
adb devices                                  # le téléphone doit apparaître
adb install -r build/app/outputs/flutter-apk/app-release.apk
```
- Si **« no devices found »** (le wifi-adb se déconnecte en veille) :
  ```
  adb reconnect && adb wait-for-device
  ```
- Si **« signatures do not match »** (changement de clé de signature) :
  ```
  adb uninstall ma.chawerni.chawerni
  adb install build/app/outputs/flutter-apk/app-release.apk
  ```

### 6.5 Partager l'app à des testeurs
Envoie-leur simplement le fichier `app-release.apk` (WhatsApp, Drive…). Ils activent
« sources inconnues » et l'installent.

---

## 7. Comprendre le RAG et les features

| Feature | Où dans le code | Comment ça marche |
|---|---|---|
| Recherche d'articles | `rag/retrieve.py` | court-circuit sur n° d'article + recherche hybride (sens + mots) |
| Réponse IA sourcée | `rag/pipeline.py`, `rag/llm.py` | modèle qualité, citations obligatoires, refus si rien trouvé |
| Darija → arabe standard | `rag/llm.py` `reformulate_darija` | la darija ne se cherche pas brute → reformulée (modèle rapide) |
| Mémoire de conversation | `rag/llm.py` `contextualize_question` | résout « et pour les femmes ? » en question autonome |
| Langue de réponse | `backend/app.py` + `rag/pipeline.py` | = langue de la **question** (pas de l'UI) |
| Traduction | `/translate`, `rag/llm.py` `translate_text` | fr/ar/darija/en, citations préservées |
| Sécurité (loi 28-08) | `backend/safety.py` | disclaimer + bandeau avocat + vérif citations |

---

## 8. Monétisation (AdMob) — état et activation

**État actuel** : l'app affiche des **pubs de TEST** (réglage `forceTestAds = true` dans
`chawerni_app/lib/ads/ads_config.dart`). **Elles ne rapportent rien** — c'est normal
tant que le compte AdMob n'est pas approuvé.

**Formats de pub** : bannière, interstitiel (1 toutes les 3 questions), app-open,
**rewarded** (regarder une pub = +5 questions). Freemium : **5 questions gratuites/jour**.

**Pourquoi 0 € aujourd'hui** : le compte AdMob est « Examen requis » et l'app n'est pas
sur le Play Store → les vraies pubs renvoient `NO_FILL`.

**Pour activer les revenus (dans l'ordre)** :
1. Publier sur le **Play Store** (§9).
2. **Lier** l'app dans AdMob (*Informations sur le magasin*) → approbation.
3. Passer **`forceTestAds = false`** dans `ads_config.dart`, rebuild + republier.
4. Les pubs réelles se remplissent → revenus dès que de **vrais utilisateurs** les voient.
5. Virement AdMob à partir de **100 $** cumulés.

> ⚠️ **Ne clique jamais tes propres pubs.** Ton Pixel est enregistré comme *appareil de
> test* (`testDeviceIds` dans `ads_config.dart`) justement pour ça.

---

## 9. Publier sur le Play Store

Tout le contenu prêt à coller est dans **`store/PLAY_STORE.md`**. Étapes :
1. Payer les **25 $** (compte Google Play Console, paiement unique à vie).
2. *Create app* → coller titre + descriptions (FR/AR) de `PLAY_STORE.md`.
3. Rebuild l'**AAB** à jour (§6.3) et l'uploader.
4. Fournir : icône **512×512**, feature graphic **1024×500**, **2-8 captures d'écran**.
5. URL politique de confidentialité : **https://164.90.216.143.nip.io/privacy** (déjà en ligne).
6. Remplir *Data safety* + *Classification du contenu* (réponses dans `PLAY_STORE.md`).
7. Lier l'app dans **AdMob** → débloque l'approbation + valide `app-ads.txt`.
8. Soumettre. Délai de revue Google : quelques jours.

---

## 10. Dépannage (les pièges déjà rencontrés)

| Symptôme | Cause | Solution |
|---|---|---|
| `/health` en erreur 503 | Qdrant injoignable ou `.env` incomplet | vérifier `/opt/chawerni/.env`, redémarrer |
| App en mode « démo » (réponses scriptées) | API non bakée au build | rebuild avec `--dart-define=CHAWERNI_API_BASE=…` |
| Boutons (Traduire/Modifier) absents après build | **cache Dart périmé** | `flutter clean` puis rebuild |
| Pub ne s'affiche pas, `Ad failed to load : 3` | compte AdMob non approuvé (NO_FILL) | `forceTestAds = true` (déjà fait) |
| `adb: no devices found` | wifi-adb en veille | `adb reconnect && adb wait-for-device` |
| `signatures do not match` à l'install | clé de signature changée | `adb uninstall ma.chawerni.chawerni` puis install |
| `git pull` demande un mot de passe sur le droplet | remote sans token | déjà résolu via clé de déploiement |
| Console DO casse un collage | collage multi-lignes | coller **une seule ligne** à la fois |
| Réponse arabe mais disclaimer français | langue forcée par l'UI | déjà corrigé (langue = celle de la question) |
| Build Docker OOM (App Platform) | image ML trop lourde | déjà résolu → on est sur le Droplet 8 Go |

---

## 11. Sécurité — à faire avant le lancement public

Régénérer les secrets qui ont circulé pendant la mise en place :
1. **Groq** : console Groq → révoquer l'ancienne clé, en créer une → mettre à jour
   `/opt/chawerni/.env` (`GROQ_API_KEY=`) → `docker compose up -d api`.
2. **Qdrant** : console Qdrant → régénérer l'API key → mettre à jour `.env`.
3. **Clé `gha_deploy`** : régénérer sur le droplet, remettre la privée dans le secret
   GitHub `DROPLET_SSH_KEY`.
4. **Token GitHub** : révoquer le fine-grained token utilisé pour le 1er clone
   (https://github.com/settings/tokens).

---

## 12. Glossaire express

- **RAG** : l'IA répond en s'appuyant sur des documents réels (tes codes de loi), pas
  sur sa mémoire → citations vérifiables, pas d'invention.
- **BGE-M3** : le modèle qui transforme un texte en vecteur (nombres) pour la recherche.
- **Qdrant** : la base de données qui stocke ces vecteurs et trouve les plus proches.
- **Groq** : le fournisseur qui fait tourner les modèles de langage (LLM) très vite.
- **Droplet** : un serveur virtuel chez DigitalOcean.
- **Docker / docker compose** : empaquette l'API + ses dépendances pour qu'elle tourne
  partout pareil ; `compose` orchestre plusieurs conteneurs (api + caddy).
- **Caddy** : le serveur web qui gère le HTTPS automatiquement.
- **AAB / APK** : AAB = format pour le Play Store ; APK = fichier installable direct.
- **Keystore** : ta signature numérique qui prouve que c'est bien TON app.
- **CI/CD** : automatisation qui déploie ton code dès que tu le pushes.
- **AdMob NO_FILL** : « pas de pub à servir » (compte pas encore actif).

---

*Dernière mise à jour : 16 juin 2026. Ce guide accompagne le code du dépôt
`Boussyf0/Chawerni_Apps`. Pour le détail technique de chaque choix, voir aussi
`STACK.md` et `DEPLOY.md`.*
