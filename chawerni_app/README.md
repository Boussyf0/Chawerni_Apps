# Chawerni — App mobile (Flutter)

شاورني — assistant juridique IA pour le droit marocain. Prototype Flutter
fidèle au **Chawerni Design System** (`../Prototype_chawarni/`) : rigueur
notariale × hospitalité marocaine, RTL-first, trilingue (FR / عربية / دارجة).

## Lancer

```bash
flutter pub get
open -a Simulator                       # iOS
flutter run                             # choisit le device connecté
# ou cibler explicitement :
flutter run -d <udid-simulateur>
```

> Les polices **IBM Plex Sans** + **IBM Plex Sans Arabic** sont chargées via
> `google_fonts` (téléchargées au 1er lancement, puis mises en cache).

## Parcours

Onboarding (3 écrans) → Disclaimer bloquant → App à 4 onglets :
**Chat · Bibliothèque · Hoquqi (bientôt) · Réglages**.

Le chat joue 3 scénarios réels (chips ou saisie libre aiguillée par mot-clé) :
- **Licenciement** → Art. 52 + 41, Code du travail (+ relance).
- **Divorce par accord** → Art. 114 Moudawana (+ bandeau « enjeu grave »).
- **Bail** → hors corpus → réponse honnête, zéro source inventée.

Tap sur une carte source → bottom sheet : texte intégral, toggle ع/FR, copie de
référence, badge de version daté, mention « النص العربي هو المعتمد قانونياً ».

La langue et la taille de texte (3 crans) se changent en direct ; l'état persiste
(`shared_preferences`, clés `chw-lang` / `chw-flow` / `chw-scale`). Réglages →
« Onboarding ↺ » rejoue l'intro.

## Architecture

```
lib/
  theme/      tokens.dart (couleurs/espace/forme), typography.dart (pile bilingue + thème)
  data/       lang.dart, strings.dart (UI trilingue), scenarios.dart (textes de loi RÉELS)
  state/      app_state.dart (ChangeNotifier persistant), app_scope.dart (InheritedNotifier)
  widgets/    chw_icon (Lucide via SVG), logo_mark, zellij_frieze, chw_button, chw_chip,
              lang_switcher, version_badge, chat_bubble, thinking_dots,
              source_card ⭐, alert_banner, code_card, search_field, article_sheet
  screens/    onboarding, disclaimer, chat, library, hoquqi, settings, app_shell
  main.dart   MaterialApp + Directionality/textScaler pilotés par l'état, routeur de flow
```

## Fidélité au design system

- **Couleurs** nommées en darija portées 1:1 depuis `tokens/colors.css`
  (`nila`, `zellij`, `zaafran`, `warqa`, `midad`, `aker`…). Fond warqa partout,
  cartes blanches comme seul blanc autorisé.
- **SourceCard ⭐** : barre latérale zaafran, puce numéro à chiffres tabulaires,
  badge de version, animation « document qui se déplie » à l'apparition.
- **Motif zellige** en filigrane (CustomPainter) sur onboarding et header chat.
- **RTL d'abord** : propriétés logiques (`EdgeInsetsDirectional`,
  `BorderDirectional`, `AlignmentDirectional`), icônes directionnelles en miroir.
- **Contenu** : tutoiement, darija en graphie arabe, honnêteté structurelle
  (hors corpus → on le dit), jamais « avocat » ; textes de loi réels et datés.

> Prototype d'interface : les réponses sont scriptées (pas de RAG branché).
> Le backend FastAPI + Qdrant/BGE-M3 reste à connecter (Phase 2-3 du plan).
