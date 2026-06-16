import 'package:flutter/material.dart';

import '../data/contact.dart';
import '../data/strings.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/chw_icon.dart';

/// Page « Trouver un avocat ».
///
/// L'annuaire de vrais avocats partenaires n'existe pas encore : on n'affiche
/// donc AUCUNE fiche fictive. La page explique que l'annuaire arrive, et propose
/// aux avocats de **contacter le fondateur** pour participer (e-mail / LinkedIn).
/// Atteinte depuis le bandeau « enjeu grave » du chat et depuis les Réglages.
class FindLawyerScreen extends StatelessWidget {
  const FindLawyerScreen({super.key});

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
                  Text(t.lawyerTitle,
                      style: Typo.style(
                          size: Typo.lg, weight: Typo.bold, color: C.midad)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  // Bloc « annuaire à venir » (pour les utilisateurs)
                  Row(
                    children: [
                      const Icon(Icons.balance, size: 20, color: C.nila),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(t.lawyerSoonTitle,
                            style: Typo.style(
                                size: Typo.base,
                                weight: Typo.bold,
                                color: C.midad)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(t.lawyerForUsers,
                      style: Typo.style(
                          size: Typo.sm, color: C.midad60, height: 1.6)),

                  const SizedBox(height: 24),

                  // Bloc recrutement (pour les avocats) → contact fondateur
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
                        Text(t.lawyerJoinTitle,
                            style: Typo.style(
                                size: Typo.base,
                                weight: Typo.bold,
                                color: C.nila)),
                        const SizedBox(height: 8),
                        Text(t.lawyerJoinBody,
                            style: Typo.style(
                                size: Typo.sm, color: C.midad, height: 1.6)),
                        const SizedBox(height: 16),
                        _ContactBtn(
                          icon: Icons.mail_outline,
                          label: t.lawyerContactEmail,
                          color: C.nila,
                          onTap: () => openEmail(context, Contact.email,
                              subject: 'Avocat partenaire — Chawerni'),
                        ),
                        const SizedBox(height: 8),
                        _ContactBtn(
                          icon: Icons.business_center_outlined,
                          label: t.lawyerContactLinkedin,
                          color: const Color(0xFF0A66C2),
                          onTap: () => openExternal(context, Contact.linkedin),
                        ),
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
            Expanded(
              child: Text(label,
                  style: Typo.style(
                      size: Typo.sm, weight: Typo.citation, color: color)),
            ),
            Icon(Icons.open_in_new, size: 14, color: color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}
