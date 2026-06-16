import 'package:flutter/material.dart';

import '../ads/banner_ad_widget.dart';
import '../data/strings.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/chw_icon.dart';
import '../widgets/lang_switcher.dart';
import 'about_screen.dart';
import 'find_lawyer_screen.dart';
import 'privacy_screen.dart';

/// Réglages — langue, taille de texte (3 crans), à propos, confidentialité.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = T(app.lang);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
            child: Text(
              t.settingsTitle,
              style: Typo.style(size: Typo.lg, weight: Typo.bold, color: C.midad),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _Row(
                  label: t.settingLang,
                  trailing: LangSwitcher(value: app.lang, onChange: app.setLang),
                ),
                const SizedBox(height: 10),
                _Row(
                  label: t.settingTextSize,
                  trailing: _TextSizeToggle(
                    value: app.textScale,
                    onChange: app.setTextScale,
                  ),
                ),
                const SizedBox(height: 10),
                _Row(
                  label: t.lawyerTitle,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FindLawyerScreen()),
                  ),
                  trailing: const ChwIcon('chevron', size: 18,
                      color: C.midad30, mirrorInRtl: true),
                ),
                const SizedBox(height: 10),
                _Row(
                  label: t.settingAbout,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                  trailing: const ChwIcon('chevron', size: 18,
                      color: C.midad30, mirrorInRtl: true),
                ),
                const SizedBox(height: 10),
                _Row(
                  label: t.settingPrivacy,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                  ),
                  trailing: const ChwIcon('chevron', size: 18,
                      color: C.midad30, mirrorInRtl: true),
                ),
                const SizedBox(height: 10),
                // Rejouer l'onboarding (bouton ↺ du prototype).
                _Row(
                  label: 'Onboarding ↺',
                  onTap: app.replayOnboarding,
                  trailing: const ChwIcon('chevron', size: 18,
                      color: C.midad30, mirrorInRtl: true),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Center(
              child: Column(
                children: [
                  Text(
                    t.aboutTagline,
                    style: Typo.style(size: Typo.xs, color: C.midad60),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Chawerni v1.0 · ',
                        style: Typo.style(size: Typo.xs, color: C.midad30),
                      ),
                      Text(
                        T.faith,
                        textDirection: TextDirection.rtl,
                        style: Typo.style(size: Typo.xs, color: C.midad30),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;
  const _Row({required this.label, required this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: C.surfaceCard,
          borderRadius: BorderRadius.circular(S.radiusCard),
          border: Border.all(color: C.borderCard),
          boxShadow: S.shadowSoft,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Typo.style(
                  size: Typo.base,
                  weight: Typo.medium,
                  color: C.midad,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _TextSizeToggle extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChange;
  const _TextSizeToggle({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: C.midad10,
        borderRadius: BorderRadius.circular(S.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final selected = i == value;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChange(i),
            child: Container(
              constraints: const BoxConstraints(minWidth: 38),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(S.radiusPill),
                boxShadow: selected ? S.shadowSoft : null,
              ),
              child: Text(
                'A',
                textAlign: TextAlign.center,
                style: Typo.style(
                  size: 12 + i * 3,
                  weight: Typo.citation,
                  color: selected ? C.nila : C.midad60,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
