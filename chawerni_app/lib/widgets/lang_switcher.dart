import 'package:flutter/material.dart';

import '../data/lang.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Sélecteur segmenté FR / ع / دارجة. `inverse` pour le header nila.
class LangSwitcher extends StatelessWidget {
  final Lang value;
  final ValueChanged<Lang> onChange;
  final bool inverse;

  const LangSwitcher({
    super.key,
    required this.value,
    required this.onChange,
    this.inverse = false,
  });

  static const _labels = {Lang.fr: 'FR', Lang.ar: 'ع', Lang.da: 'دارجة'};

  @override
  Widget build(BuildContext context) {
    final trackColor = inverse ? const Color(0x33FFFFFF) : C.midad10;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(S.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: Lang.values.map((l) {
          final selected = l == value;
          final fg = selected
              ? C.nila
              : (inverse ? Colors.white : C.midad60);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChange(l),
            child: AnimatedContainer(
              duration: S.durationFast,
              curve: S.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(S.radiusPill),
                boxShadow: selected ? S.shadowSoft : null,
              ),
              child: Text(
                _labels[l]!,
                style: Typo.style(size: 13, weight: Typo.medium, color: fg),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
