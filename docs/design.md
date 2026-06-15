# CHAWERNI — Design DNA  شاورني

> **Document autonome.** Tout le contexte nécessaire est dedans — collez-le tel
> quel dans votre outil de design IA. Cible : application mobile Flutter
> (iOS + Android), portrait, dark mode optionnel en v2.

---

## 1. Le produit en 30 secondes

**Chawerni** (شاورني — *« consulte-moi »* en darija marocaine) est un assistant
juridique IA pour le Maroc. L'utilisateur pose une question en **français, en
arabe ou en darija** ; l'app répond en citant **les articles de loi exacts**
(Code pénal, Moudawana, Code du travail…) avec leur date de version, jamais de
réponse inventée.

**Le concurrent (Qanun) joue la carte institutionnelle et froide. Chawerni
prend le contre-pied : le droit expliqué comme un ami marocain de confiance te
l'expliquerait autour d'un verre de thé.** Sérieux sur le fond, chaleureux sur
la forme. C'est LA tension créative à tenir dans chaque écran : **rigueur
notariale × hospitalité marocaine.**

### Persona de la voix : « صاحبك اللي قرا » (ton ami qui a fait des études)
- Il tutoie, il rassure, il va droit au but.
- Il ne joue JAMAIS à l'avocat : il montre le texte, explique, et dit quand il
  faut consulter un vrai professionnel.
- Il cite ses sources comme un réflexe d'honnêteté, pas comme une formalité.

---

## 2. Identité visuelle

### 2.1 Concept du logo
Une **bulle de dialogue** dont la pointe est un **coin de zellige** (losange
géométrique marocain). Pas de balance de justice, pas de marteau, pas de
colonnes grecques — ces clichés appartiennent au concurrent. La bulle dit
« conversation », le zellige dit « Maroc », la géométrie nette dit « précision ».
Wordmark bilingue : **شاورني** (dominant) + *Chawerni* en dessous.

### 2.2 Palette — tokens nommés en darija

| Token | Hex | Usage |
|---|---|---|
| `--nila` (نيلة, bleu Majorelle profond) | `#2D3A8C` | Couleur primaire : header, boutons principaux, bulle de l'app |
| `--nila-light` | `#E8EAFB` | Fond des bulles de réponse, surfaces secondaires |
| `--zellij` (vert zellige) | `#0E7C6B` | Succès, badge « version à jour », liens vers les sources |
| `--zaafran` (زعفران, safran) | `#E8A13D` | Accent : highlights de citation, étoiles, onboarding |
| `--warqa` (ورقة, papier) | `#FAF7F1` | Fond principal — chaud, jamais blanc pur hôpital |
| `--midad` (مداد, encre) | `#1E1B18` | Texte principal |
| `--midad-60` | `#5C564F` | Texte secondaire, métadonnées |
| `--aker` (عكر فاسي, rouge fassi) | `#B3382C` | Disclaimers, alertes « consultez un avocat » |

Règle d'or : **fond `--warqa` partout**. La chaleur du papier crème est la
signature sensorielle de l'app — on lit la loi sur du beau papier, pas sur un
écran d'administration.

### 2.3 Typographie

| Rôle | Police | Notes |
|---|---|---|
| Arabe (UI + contenu) | **IBM Plex Sans Arabic** | Excellente lisibilité, moderne sans froideur |
| Latin (UI + contenu) | **IBM Plex Sans** | Même famille = cohérence bilingue parfaite |
| Citations d'articles | IBM Plex Sans, graisse 600, interligne 1.6 | Les articles de loi sont le héros typographique |
| Numéros d'articles | Tabular figures, `--zaafran` sur puce | « Art. 446 » doit se repérer d'un coup d'œil |

Échelle : 12 / 14 / 16 (corps) / 18 / 22 / 28. Corps de texte généreux —
l'app sera lue par des gens stressés (litige, licenciement, divorce).

### 2.4 Forme & matière
- Rayons d'angle : **16 px** (cartes), **24 px** (bulles de chat) — rondeur
  hospitalière, jamais de coins vifs sauf le motif zellige décoratif.
- Ombres très douces (`y=2, blur=12, 6 %`) ; la hiérarchie vient de la couleur
  de fond, pas des ombres.
- **Motif signature** : frise de losanges zellige en filigrane 4 % d'opacité en
  haut des écrans clés (onboarding, accueil) — identité sans bruit.

---

## 3. Architecture des écrans

```
Onboarding (3 écrans) → Disclaimer légal (bloquant, 1re fois)
└── Accueil = Chat
    ├── Carte source (bottom sheet) → Texte intégral de l'article
    ├── Bibliothèque (mode hors-ligne : les 13 codes consultables)
    ├── Hoquqi حقوقي (fiches pratiques par situation — v2, entrée visible « bientôt »)
    └── Réglages (langue, taille de texte, à propos, confidentialité)
```

### 3.1 Onboarding — 3 écrans, 3 promesses
1. **« شاورني قبل ما توقّع »** (*Consulte-moi avant de signer*) — illustration
   d'une main qui hésite sur un contrat. Promesse : comprendre avant d'agir.
2. **« Chaque réponse cite la loi. »** — mockup d'une bulle avec sa carte
   source. Promesse : zéro invention, traçabilité totale.
3. **« بالدارجة، بالعربية، en français »** — sélecteur de langue en action.
   Promesse : la loi dans TA langue.

### 3.2 Disclaimer légal (écran bloquant, design soigné — pas un popup moche)
Fond `--warqa`, icône main ouverte (pas de panneau danger), texte en
`--midad`, encadré `--aker` léger :
> « Chawerni t'informe sur ce que disent les textes de loi marocains.
> Ce n'est **pas un avis juridique** : pour une décision importante,
> consulte un avocat ou un professionnel agréé. »
Bouton unique : **« فهمت — J'ai compris »**. Lien discret : « Trouver un
avocat près de chez toi ».

### 3.3 Écran principal — le Chat
- Header : logo + sélecteur de langue (FR / ع / دارجة) toujours accessible.
- **Bulle utilisateur** : `--nila`, texte blanc, alignée selon la direction
  (droite en FR, gauche en AR — RTL natif total).
- **Bulle Chawerni** : `--nila-light`, texte `--midad`. La réponse est
  structurée : explication courte → **cartes sources** → suggestion de suite.
- **État de réflexion** : trois points qui pulsent en `--zaafran` + micro-texte
  rotatif (« أنا كنقلّب في النصوص… » / « Je fouille les textes… »).
- Suggestions de départ (chips scrollables) : « واش خصني نخلص الكراء إلا… »,
  « Mes droits si je suis licencié », « الطلاق بالاتفاق كيفاش ».

### 3.4 La Carte Source — LE composant signature ⭐
C'est elle qui différencie Chawerni de tous les chatbots. Chaque article cité
apparaît sous la réponse comme une carte horizontale scrollable :

```
┌──────────────────────────────────────────┐
│ ▌Art. 446 — Code pénal                   │  ← barre latérale --zaafran
│ « …secret professionnel… » (2 lignes)    │  ← extrait, italique
│ ⬤ Version du 28/04/2026  · العربية تعتمد │  ← badge --zellij
└──────────────────────────────────────────┘
```

- Tap → **bottom sheet** avec le texte intégral de l'article, sa hiérarchie
  (Livre > Titre > Chapitre), un toggle **ع / FR** pour basculer de langue, et
  un bouton « copier la référence ».
- Le badge de version est NON NÉGOCIABLE : un consultant qui cite une loi
  abrogée est mort — la date rassure et engage.
- Mention permanente discrète : « النص العربي هو المعتمد قانونياً » (le texte
  arabe fait foi).

### 3.5 États sensibles (à designer avec autant d'amour que le happy path)
| État | Design |
|---|---|
| **Hors corpus** | Bulle honnête : « ما لقيتش نص قانوني واضح على هادشي » + « Je n'ai pas trouvé de texte applicable — je préfère te le dire que d'inventer. » Pas d'excuse robotique. |
| **Enjeu grave** (pénal, garde d'enfants, violence) | Réponse informative + bandeau `--aker` doux : « هاد الموضوع مهم بزاف — Pour ça, un avocat est indispensable » + bouton « Trouver un avocat ». Ton protecteur, jamais alarmiste. |
| **Hors-ligne** | Le chat se grise avec : « الشات خاصو الإنترنت، ولكن النصوص هنا 👇 » et bascule vers la Bibliothèque locale. |

### 3.6 Bibliothèque (hors-ligne)
Grille de cartes — une par code, couleur d'accent par matière (pénal `--aker`,
famille `--zaafran`, travail `--zellij`, civil `--nila`). Recherche par numéro
d'article (« 446 ») ou mot-clé. Chaque code affiche sa date de version.

---

## 4. Micro-copy — la darija est une feature, pas une traduction

| Moment | FR | Darija (signature) |
|---|---|---|
| Placeholder input | « Pose ta question… » | « سوّل اللي بغيتي… » |
| Pull-to-refresh | « Mise à jour des textes » | « كنجدد النصوص » |
| Réponse envoyée | — | « شاورني فاش بغيتي 🤝 » |
| Erreur réseau | « Connexion perdue » | « الكونيكسيون قاطعة، عاود من بعد » |
| Vide (1re visite) | « Par quoi on commence ? » | « منين نبداو؟ » |

Règles : darija en **graphie arabe** (pas de translittération latine dans
l'UI) ; les **citations légales restent textuelles** (arabe classique ou
français officiel) — la darija explique, la loi cite.

---

## 5. Interactions & accessibilité

- **RTL d'abord** : l'app doit être pensée miroir-natif (layouts, icônes
  directionnelles, animations d'entrée). Le FR est le cas « LTR dans une app
  RTL », pas l'inverse.
- Taille de texte ajustable (3 crans) dès la v1 — public large, dont seniors.
- Cibles tactiles ≥ 48 px ; contraste AA minimum sur `--warqa`.
- Haptique légère quand une carte source apparaît (la preuve « tombe »).
- Animations : 200-250 ms, ease-out, sobres. La seule animation signature :
  la carte source qui **se déplie comme un document** sous la réponse.

## 6. Ce que Chawerni n'est PAS (anti-brief)

- ❌ Pas de balance, marteau, colonnes, toge — clichés justice interdits.
- ❌ Pas de bleu corporate froid sur blanc pur — on n'est pas une banque.
- ❌ Pas de mascotte cartoon — la confiance se joue au sérieux du contenu.
- ❌ Pas de dark patterns, pas de paywall agressif sur les textes de loi
  (ils sont publics et gratuits — notre valeur est l'explication).
- ❌ Jamais un seul écran qui laisse croire qu'on remplace un avocat.

## 7. Livrables attendus de l'assistant design

1. Design system Figma-ready à partir des tokens §2.
2. Les 6 écrans clés : onboarding ×1, disclaimer, chat (avec cartes sources),
   bottom sheet article, bibliothèque, état « enjeu grave ».
3. Chaque écran en **double version AR (RTL) et FR (LTR)**.
4. Le composant Carte Source en états : défaut, pressé, déplié, version
   obsolète (badge orange « نسخة قديمة — vérification en cours »).
