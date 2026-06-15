import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'chw_button.dart';
import 'chw_icon.dart';

/// AlertBanner — bandeau « enjeu grave », protecteur jamais alarmiste.
/// Fond aker doux + bouton « Trouver un avocat ». Apparaît sous une réponse
/// quand le sujet est lourd (garde d'enfants, pension…).
class AlertBanner extends StatelessWidget {
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback? onAction;

  const AlertBanner({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(S.s4),
      decoration: BoxDecoration(
        color: C.akerLight,
        borderRadius: BorderRadius.circular(S.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: C.aker,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: ChwIcon('hand', size: 18, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      textDirection: TextDirection.rtl,
                      style: Typo.style(
                        size: Typo.base,
                        weight: Typo.citation,
                        color: C.aker,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: Typo.style(
                        size: Typo.sm,
                        color: C.midad,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ChwButton(
            label: actionLabel,
            variant: ChwButtonVariant.danger,
            fullWidth: true,
            leading: const ChwIcon('hand', size: 16, color: Colors.white),
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}
