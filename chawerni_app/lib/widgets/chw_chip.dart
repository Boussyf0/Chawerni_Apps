import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Chip — suggestion de départ scrollable, ou question de relance.
class ChwChip extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  const ChwChip({super.key, required this.label, this.onTap});

  @override
  State<ChwChip> createState() => _ChwChipState();
}

class _ChwChipState extends State<ChwChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: S.durationFast,
        curve: S.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: _pressed ? C.midad10 : C.surfaceCard,
            borderRadius: BorderRadius.circular(S.radiusPill),
            border: Border.all(color: C.borderCard),
            boxShadow: S.shadowSoft,
          ),
          child: Text(
            widget.label,
            style: Typo.style(size: Typo.sm, weight: Typo.medium, color: C.midad),
          ),
        ),
      ),
    );
  }
}
