import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Badge de version daté — ⬤ + date. Variante `stale` (« نسخة قديمة »).
/// Présent sur chaque citation : NON NÉGOCIABLE dans le design system.
class VersionBadge extends StatelessWidget {
  final String date;
  final bool stale;
  const VersionBadge({super.key, required this.date, this.stale = false});

  @override
  Widget build(BuildContext context) {
    final color = stale ? C.zaafran : C.zellij;
    final bg = stale ? C.zaafranLight : C.zellijLight;
    final label = stale ? 'نسخة قديمة · $date' : date;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(S.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Typo.article(size: Typo.xs, weight: Typo.medium, color: color),
          ),
        ],
      ),
    );
  }
}
