import 'package:flutter/material.dart';

import '../data/contact.dart';
import '../data/strings.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/chw_icon.dart';

/// Confidentialité — résumé clair des points clés (hors-ligne) + lien vers la
/// politique complète hébergée sur l'API (`/privacy`).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final t = T(app.lang);

    return Scaffold(
      backgroundColor: C.warqa,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const ChwIcon('chevron', size: 22, color: C.midad,
                        mirrorInRtl: true),
                  ),
                  Text(t.privacyTitle,
                      style: Typo.style(
                          size: Typo.lg, weight: Typo.bold, color: C.midad)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text(t.aboutTagline,
                      style: Typo.style(
                          size: Typo.sm, color: C.midad60, height: 1.5)),
                  const SizedBox(height: 16),
                  for (final p in t.privacyPoints) ...[
                    _Point(text: p),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => openExternal(context, Contact.privacyUrl),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: C.nila.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(S.radiusPill),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined,
                              size: 18, color: C.nila),
                          const SizedBox(width: 10),
                          Text(t.privacyFull,
                              style: Typo.style(
                                  size: Typo.sm,
                                  weight: Typo.citation,
                                  color: C.nila)),
                          const Spacer(),
                          const Icon(Icons.open_in_new, size: 14, color: C.nila),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final String text;
  const _Point({required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsetsDirectional.only(top: 2, end: 10),
          child: ChwIcon('check', size: 16, color: C.zellij),
        ),
        Expanded(
          child: Text(text,
              style: Typo.style(size: Typo.sm, color: C.midad, height: 1.5)),
        ),
      ],
    );
  }
}
