import 'package:flutter/material.dart';

import '../data/lang.dart';
import '../data/strings.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chw_button.dart';
import '../widgets/lang_switcher.dart';
import '../widgets/logo_mark.dart';
import '../widgets/source_card.dart';
import '../widgets/zellij_frieze.dart';

/// Onboarding — 3 écrans. Promesse → preuve (carte source) → trilingue.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = T(app.lang);
    final last = _page == 2;
    final pageContent = t.onb[_page];

    return SafeArea(
      child: Column(
        children: [
          // Frise zellige en filigrane, en haut.
          SizedBox(
            height: 56,
            child: Stack(
              children: [
                const ZellijFrieze.dark(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _Wordmark(),
                      LangSwitcher(
                        value: app.lang,
                        onChange: app.setLang,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: _visual(app.lang),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
            child: Column(
              children: [
                Text(
                  pageContent[0],
                  textAlign: TextAlign.center,
                  textDirection: dirOf(pageContent[0]),
                  style: Typo.style(
                    size: Typo.xl,
                    weight: Typo.bold,
                    color: C.midad,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  pageContent[1],
                  textAlign: TextAlign.center,
                  style: Typo.style(
                    size: Typo.base,
                    color: C.midad60,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          // Dots losange.
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ZellijDiamond(
                    size: 10,
                    color: i == _page ? C.zaafran : C.midad10,
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: ChwButton(
              label: last ? t.start : t.next,
              large: true,
              fullWidth: true,
              leading: last
                  ? null
                  : const ChwArrow(),
              onPressed: () {
                if (last) {
                  widget.onDone();
                } else {
                  setState(() => _page++);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TextButton(
              onPressed: widget.onDone,
              child: Text(
                t.skip,
                style: Typo.style(size: Typo.sm, color: C.midad60),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _visual(Lang lang) {
    switch (_page) {
      case 0:
        return const Center(child: LogoMark(size: 148));
      case 1:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChatBubble(
                isUser: false,
                fontSize: Typo.sm,
                text: lang == Lang.fr
                    ? 'Après 6 mois, tu as droit à une indemnité :'
                    : 'من بعد 6 شهور، عندك الحق فالتعويض:',
              ),
              const SizedBox(height: 10),
              SourceCard(
                num: lang == Lang.fr ? 'Art. 52' : 'المادة 52',
                code: lang == Lang.fr ? 'Code du travail' : 'مدونة الشغل',
                excerpt: lang == Lang.fr
                    ? '« Le salarié lié par un contrat à durée indéterminée a droit à une indemnité… »'
                    : '« يستحق الأجير المرتبط بعقد شغل غير محدد المدة تعويضاً عند فصله… »',
                date: lang == Lang.fr ? '10/11/2025' : '08/2019',
              ),
            ],
          ),
        );
      default:
        return Center(
          child: Transform.scale(
            scale: 1.4,
            child: LangSwitcher(
              value: AppScope.of(context).lang,
              onChange: AppScope.of(context).setLang,
            ),
          ),
        );
    }
  }
}

/// Petite flèche « suivant » qui se met en miroir en RTL.
class ChwArrow extends StatelessWidget {
  const ChwArrow({super.key});
  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Transform.flip(
      flipX: rtl,
      child: const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
    );
  }
}

/// Wordmark bilingue : شاورني (dominant) + Chawerni dessous.
class _Wordmark extends StatelessWidget {
  const _Wordmark();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const LogoMark(size: 30),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'شاورني',
              textDirection: TextDirection.rtl,
              style: Typo.style(size: 18, weight: Typo.citation, color: C.nila),
            ),
            Text(
              'CHAWERNI',
              style: Typo.style(
                size: 9,
                weight: Typo.medium,
                color: C.midad60,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
