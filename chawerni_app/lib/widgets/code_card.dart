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
    final isRtl = Directionality.of(context) == TextDirection.rtl;

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
        // La barre d'accent est un CustomPaint en foreground : ZÉRO impact sur
        // le layout. Le Column-min reçoit une hauteur non-contrainte et se
        // dimensionne librement à son contenu — plus d'overflow.
        foregroundDecoration: _AccentBarDecoration(color: color, isRtl: isRtl),
        padding: EdgeInsetsDirectional.fromSTEB(
            4 + S.s4, S.s4, S.s4, S.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Typo.style(
                          size: Typo.md,
                          weight: Typo.bold,
                          color: C.midad,
                        ),
                      ),
                      Text(
                        titleSecondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Typo.style(
                          size: Typo.xs,
                          weight: Typo.medium,
                          color: C.midad60,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                VersionBadge(date: date),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              dahir,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
    );
  }
}

/// Peint une barre d'accent de 4 px sur le côté start (LTR → gauche, RTL → droite).
/// Utilisé en `foregroundDecoration` : aucun impact sur le layout.
class _AccentBarDecoration extends Decoration {
  final Color color;
  final bool isRtl;
  const _AccentBarDecoration({required this.color, required this.isRtl});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _AccentBarPainter(color: color, isRtl: isRtl);
}

class _AccentBarPainter extends BoxPainter {
  final Color color;
  final bool isRtl;
  _AccentBarPainter({required this.color, required this.isRtl});

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size ?? Size.zero;
    final rect = isRtl
        ? Rect.fromLTWH(offset.dx + size.width - 4, offset.dy, 4, size.height)
        : Rect.fromLTWH(offset.dx, offset.dy, 4, size.height);
    canvas.drawRect(rect, Paint()..color = color);
  }
}
