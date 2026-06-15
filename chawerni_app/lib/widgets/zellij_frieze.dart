import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Motif signature : frise de losanges zellige, en filigrane.
/// Filigrane à ~4 % d'opacité en haut des écrans clés (onboarding, header chat).
/// Tile de 24 px, répété. Trois teintes comme dans `tokens/patterns.css`.
class ZellijFrieze extends StatelessWidget {
  final double opacity;
  final Color color;
  final double tile;

  const ZellijFrieze({
    super.key,
    this.opacity = 0.04,
    this.color = C.midad,
    this.tile = 24,
  });

  /// Filigrane sombre sur fond clair (warqa).
  const ZellijFrieze.dark({super.key})
      : opacity = 0.04,
        color = C.midad,
        tile = 24;

  /// Filigrane blanc sur le header nila.
  const ZellijFrieze.onNila({super.key})
      : opacity = 0.08,
        color = const Color(0xFFFFFFFF),
        tile = 24;

  /// Version accentuée zaafran (bandeaux décoratifs pleins).
  const ZellijFrieze.accent({super.key})
      : opacity = 0.35,
        color = C.zaafran,
        tile = 24;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _FriezePainter(
            color: color.withValues(alpha: opacity),
            tile: tile,
          ),
        ),
      ),
    );
  }
}

class _FriezePainter extends CustomPainter {
  final Color color;
  final double tile;
  _FriezePainter({required this.color, required this.tile});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final r = tile / 2;
    for (double y = 0; y < size.height + tile; y += tile) {
      for (double x = 0; x < size.width + tile; x += tile) {
        final cx = x + r;
        final cy = y + r;
        final d = r * 0.75; // losange un peu plus petit que la tuile
        final path = Path()
          ..moveTo(cx, cy - d)
          ..lineTo(cx + d, cy)
          ..lineTo(cx, cy + d)
          ..lineTo(cx - d, cy)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_FriezePainter old) =>
      old.color != color || old.tile != tile;
}

/// Petit losange zellige plein — puce / dot de réflexion / séparateur décoratif.
class ZellijDiamond extends StatelessWidget {
  final double size;
  final Color color;
  const ZellijDiamond({super.key, this.size = 10, this.color = C.zaafran});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.7853981633974483, // 45°
      child: Container(width: size, height: size, color: color),
    );
  }
}
