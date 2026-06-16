import 'package:flutter/material.dart';

import '../data/contact.dart';
import '../data/strings.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/chw_icon.dart';
import '../widgets/logo_mark.dart';

/// À propos — présentation de l'app, fondateur, contact (e-mail + LinkedIn), version.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
                  Text(t.aboutTitle,
                      style: Typo.style(
                          size: Typo.lg, weight: Typo.bold, color: C.midad)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const SizedBox(height: 8),
                  const Center(child: LogoMark(size: 96)),
                  const SizedBox(height: 12),
                  Center(
                    child: Text('شاورني · Chawerni',
                        style: Typo.style(
                            size: Typo.lg, weight: Typo.bold, color: C.nila)),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(t.aboutTagline,
                        textAlign: TextAlign.center,
                        style: Typo.style(size: Typo.sm, color: C.midad60)),
                  ),
                  const SizedBox(height: 24),
                  Text(t.aboutWhat,
                      style: Typo.style(
                          size: Typo.base, color: C.midad, height: 1.6)),
                  const SizedBox(height: 24),

                  // Fondateur + contact
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: C.surfaceCard,
                      borderRadius: BorderRadius.circular(S.radiusCard),
                      border: Border.all(color: C.borderCard),
                      boxShadow: S.shadowSoft,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.aboutDevBy,
                            style: Typo.style(size: Typo.xs, color: C.midad60)),
                        const SizedBox(height: 2),
                        Text(Contact.founderName,
                            style: Typo.style(
                                size: Typo.base,
                                weight: Typo.bold,
                                color: C.midad)),
                        const SizedBox(height: 14),
                        _ContactBtn(
                          icon: Icons.business_center_outlined,
                          label: t.aboutLinkedin,
                          color: const Color(0xFF0A66C2),
                          onTap: () => openExternal(context, Contact.linkedin),
                        ),
                        const SizedBox(height: 8),
                        _ContactBtn(
                          icon: Icons.mail_outline,
                          label: t.aboutEmail,
                          color: C.nila,
                          onTap: () => openEmail(context, Contact.email,
                              subject: 'Chawerni'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        Text('Chawerni v1.0',
                            style: Typo.style(size: Typo.xs, color: C.midad30)),
                        const SizedBox(height: 2),
                        Text(T.faith,
                            textDirection: TextDirection.rtl,
                            style: Typo.style(size: Typo.xs, color: C.midad30)),
                      ],
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

class _ContactBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ContactBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(S.radiusPill),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Text(label,
                style: Typo.style(
                    size: Typo.sm, weight: Typo.citation, color: color)),
            const Spacer(),
            Icon(Icons.open_in_new, size: 14, color: color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}
