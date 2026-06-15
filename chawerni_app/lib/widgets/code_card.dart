import 'package:flutter/material.dart';

import '../data/lang.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'chw_icon.dart';
import 'version_badge.dart';

/// CodeCard — carte d'un code juridique dans la bibliothèque (hors-ligne).
/// Accent coloré par matière, titre AR + FR, dahir, lien « Consulter ».
class CodeCard extends StatelessWidget {
  final String titleAr;
  final String titleFr;
  final String accent;
  final String date;
  final String dahir;
  final String consultLabel;
  final Lang lang;
  final VoidCallback? onTap;

  const CodeCard({
    super.key,
    required this.titleAr,
    required this.titleFr,
    required this.accent,
    required this.date,
    required this.dahir,
    required this.consultLabel,
    required this.lang,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = C.matiere(accent);
    final titlePrimary = lang == Lang.fr ? titleFr : titleAr;
    final titleSecondary = lang == Lang.fr ? titleAr : titleFr;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: C.surfaceCard,
          borderRadius: BorderRadius.circular(S.radiusCard),
          border: Border.all(color: C.borderCard),
          boxShadow: S.shadowSoft,
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(S.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: ChwIcon('book-open', size: 20, color: color),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  titlePrimary,
                                  style: Typo.style(
                                    size: Typo.md,
                                    weight: Typo.bold,
                                    color: C.midad,
                                  ),
                                ),
                                Text(
                                  titleSecondary,
                                  style: Typo.style(
                                    size: Typo.xs,
                                    weight: Typo.medium,
                                    color: C.midad60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          VersionBadge(date: date),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        dahir,
                        style: Typo.style(
                          size: Typo.sm,
                          color: C.midad60,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            consultLabel,
                            style: Typo.style(
                              size: Typo.sm,
                              weight: Typo.citation,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 6),
                          ChwIcon('chevron', size: 16, color: color,
                              mirrorInRtl: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
