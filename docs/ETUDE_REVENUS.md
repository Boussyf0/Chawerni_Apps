# 💰 Étude de revenus — Chawerni

Analyse réaliste pour le marché marocain. Hypothèses conservatrices, à ajuster avec
tes vraies données AdMob une fois en production. (1 USD ≈ 10 MAD.)

> **Le point clé à retenir** : les **pubs seules, au Maroc, couvrent à peine le coût
> de l'IA** par question. Le vrai profit vient de **l'abonnement Pro** et surtout de
> **l'annuaire d'avocats (B2B)**, qui sont à forte marge.

---

## 1. Les sources de revenus

| Source | Type | Marge | Potentiel |
|---|---|---|---|
| **Publicités AdMob** | bannière, interstitiel, rewarded, app-open | faible | dépend du volume d'utilisateurs |
| **Abonnement Pro** | sans pub + questions illimitées | élevée | quelques % des utilisateurs |
| **Annuaire d'avocats** | abonnement B2B des avocats partenaires | **très élevée** | **le plus rentable** |
| **API / B2B** (futur) | accès pro pour cabinets, RH, assurances | élevée | long terme |

---

## 2. Économie unitaire (LE calcul important)

**Coût d'une question** (IA Groq, modèle 70B) :
- contexte (articles récupérés) + réponse ≈ 3 000 tokens
- ≈ **0,002–0,003 $ par question** (≈ 0,02–0,03 MAD)
- ⚠ le **palier gratuit Groq = 100 000 tokens/jour** ≈ **40–60 questions/jour offertes**. Au-delà → tier payant.

**Revenu publicitaire par question** (eCPM Maroc, conservateur) :
- 1 interstitiel toutes les 3 questions à eCPM ~1,2 $ → ≈ **0,0015 $/question** + bannière
- ⇒ **revenu pub/question ≈ coût IA/question** : marge quasi nulle sur la pub seule.

👉 **Conclusion unité** : tant que tu restes sous le palier Groq gratuit, chaque
question est **gratuite à servir** et la pub est du **bonus net**. Dès que tu dépasses
(succès), les pubs ne suffisent plus à payer l'IA → il faut le **Pro** et le **B2B**.
C'est pour ça que le **quota freemium (5 questions/jour)** est vital.

---

## 3. Hypothèses publicitaires (Maroc, conservateur)

| Format | eCPM | Impressions / utilisateur actif / jour |
|---|---|---|
| App-open | 1,0 $ | 1,0 |
| Bannière | 0,15 $ | 4,0 |
| Interstitiel | 1,2 $ | 1,5 |
| Rewarded | 4,0 $ | 0,3 |

**ARPDAU** (revenu moyen / utilisateur actif quotidien) ≈ **0,005 $/jour** ≈ **0,14 $/mois**.

---

## 4. Scénarios (revenu PUB mensuel)

| Utilisateurs actifs/jour (DAU) | Revenu pub /mois | ≈ MAD |
|---|---|---|
| 500 | ~70 $ | ~700 MAD |
| 1 000 | ~140 $ | ~1 400 MAD |
| 5 000 | ~700 $ | ~7 000 MAD |
| 20 000 | ~2 800 $ | ~28 000 MAD |

> ⚠ Atteindre 1 000 DAU demande souvent **10 000–30 000 téléchargements** (le DAU ≈
> 5–15 % des installs). C'est l'enjeu n°1 : **l'acquisition d'utilisateurs**.

---

## 5. L'abonnement Pro (forte marge)

Offre : **sans pub + questions illimitées + traduction**, ex. **29 MAD/mois (~3 $)**.
- Taux de conversion réaliste : **1–3 %** des utilisateurs actifs.
- 1 000 DAU × 2 % × 29 MAD = **~580 MAD/mois** (≈ 58 $) — en plus des pubs, à marge ~100 %.
- À 10 000 DAU × 2 % → **~5 800 MAD/mois**.

---

## 6. L'annuaire d'avocats (le vrai levier B2B)

Abonnement des avocats partenaires pour une fiche mise en avant (par ville/spécialité).
**Marge ~100 %** (aucun coût IA), et **indépendant du nombre d'utilisateurs grand public**.

| Avocats partenaires | Prix/mois | Revenu/mois |
|---|---|---|
| 10 | 300 MAD | **3 000 MAD** (~300 $) |
| 30 | 300 MAD | **9 000 MAD** (~900 $) |
| 50 | 400 MAD | **20 000 MAD** (~2 000 $) |

👉 **30 avocats à 300 MAD rapportent plus que 5 000 utilisateurs en pubs**, sans coût IA.
C'est la piste la plus rentable et la plus rapide — d'où la page « Trouver un avocat ».
⚠ Vérifier la conformité avec les règles de l'Ordre (annuaire pro, pas publicité).

---

## 7. Coûts mensuels

| Poste | Coût | Note |
|---|---|---|
| Droplet (serveur) | 48 $ | **gratuit ~4 mois** (crédit Student 200 $) |
| Qdrant Cloud | 0 $ | palier gratuit (l'index tient large) |
| Groq (IA) | 0 $ | tant que < 100k tokens/jour ; sinon ~0,002 $/question |
| Play Console | 25 $ | **une seule fois**, à vie |
| **Total récurrent** | **~48 $/mois** | ~0 $ pendant les premiers mois |

**Seuil de rentabilité** : ~350 DAU en pubs, OU **~2 avocats partenaires**, couvrent le serveur.

---

## 8. Leviers pour augmenter les revenus

1. **Recruter des avocats** (B2B) — le plus rentable, commence dès maintenant.
2. **Lancer l'abonnement Pro** (in_app_purchase) — marge ~100 %.
3. **Acquisition** : Play Store + ASO (mots-clés « droit marocain », « مدونة الأسرة »…), LinkedIn, TikTok juridique, bouche-à-oreille.
4. **Rétention** : notifications « nouveauté loi », contenu Hoquqi → plus de DAU = plus de pubs.
5. **Maîtriser le coût IA** :
   - ✅ **Déjà en place** : quota freemium **côté app** (5 questions/jour).
   - 🔜 **À ajouter (recommandé)** :
     - **Limite côté serveur** sur `/ask` (par IP) — aujourd'hui l'API est ouverte et le quota n'est que dans l'app ; un appel direct peut faire exploser le coût IA.
     - **Cache des questions fréquentes** (mêmes questions → même réponse, sans rappeler le 70B).
     - **Routage 8B pour les cas simples** (aujourd'hui toutes les réponses passent par le 70B).

---

## 9. Conclusion honnête

- **Court terme (0–6 mois)** : revenus **faibles** (quelques centaines de MAD/mois) le temps d'avoir des utilisateurs. Coûts ≈ 0 grâce aux paliers gratuits. **Objectif = installs + premiers avocats partenaires.**
- **Moyen terme** : le **mix pub + Pro + 20-30 avocats** peut viser **5 000–15 000 MAD/mois** à marge correcte.
- **La pub seule ne te rendra pas riche au Maroc** (eCPM bas) ; elle paie le serveur. **Le profit = B2B avocats + abonnement.**

*Chiffres à recalibrer avec tes vraies données AdMob et ton taux de conversion réels.*
