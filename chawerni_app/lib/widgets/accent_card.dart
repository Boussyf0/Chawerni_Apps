import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Carte blanche à barre d'accent latérale (couleur de matière).
///
/// La barre est peinte via `foregroundDecoration` (custom paint) : ZÉRO impact
/// sur le layout. Le contenu se dimensionne librement — plus d'overflow quand
/// un texte passe sur 2 lignes. RTL-aware.
class AccentCard extends StatelessWidget {
  final Color accent;
  final Widget child;
  final VoidCallback? onTap;
  const AccentCard({super.key, required this.accent, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
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
        foregroundDecoration: _AccentBarDeco(color: accent, isRtl: isRtl),
        // start = 4 (barre peinte) + 14
        padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 14, 14),
        child: child,
      ),
    );
  }
}

/// Peint une barre d'accent de 4 px sur le côté start.
class _AccentBarDeco extends Decoration {
  final Color color;
  final bool isRtl;
  const _AccentBarDeco({required this.color, required this.isRtl});

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
