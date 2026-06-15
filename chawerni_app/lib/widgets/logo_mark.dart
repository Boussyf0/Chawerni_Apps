import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Logo Chawerni : bulle de dialogue (rect arrondi) + pointe losange zellige
/// en bas à gauche. Porté de `assets/logo-mark.svg` (viewBox 96×96).
class LogoMark extends StatelessWidget {
  final double size;
  final Color color;
  const LogoMark({super.key, this.size = 96, this.color = C.nila});

  /// Variante claire (sur fond nila).
  const LogoMark.warqa({super.key, this.size = 96}) : color = C.warqa;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter(color)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color color;
  _LogoPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 96.0; // facteur d'échelle depuis le viewBox 96
    final paint = Paint()..color = color;

    // Bulle : rect(10,10,76,56) rayon 14
    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(10 * s, 10 * s, 76 * s, 56 * s),
      Radius.circular(14 * s),
    );
    canvas.drawRRect(bubble, paint);

    // Pointe losange : carré 18×18, rayon 3, tourné 45° autour de (31,67).
    canvas.save();
    canvas.translate(31 * s, 67 * s);
    canvas.rotate(0.7853981633974483);
    final tail = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 18 * s, height: 18 * s),
      Radius.circular(3 * s),
    );
    canvas.drawRRect(tail, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.color != color;
}
