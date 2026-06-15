import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Carte blanche à barre d'accent latérale (couleur de matière).
///
/// La barre est posée en `PositionedDirectional` (pas d'`IntrinsicHeight`, qui
/// sous-estime la hauteur d'un texte qui passe sur 2 lignes → débordement). La
/// barre s'étire naturellement à la hauteur du contenu. RTL-aware.
class AccentCard extends StatelessWidget {
  final Color accent;
  final Widget child;
  final VoidCallback? onTap;
  const AccentCard({super.key, required this.accent, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
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
        child: Stack(
          children: [
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 4, color: accent),
            ),
            Padding(
              // start = 4 (barre) + 14
              padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 14, 14),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
