import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

enum ChwButtonVariant { primary, secondary, ghost, danger }

/// Bouton Chawerni — hauteur ≥ 48, rayon 12. Press : assombrir + scale 0.98.
class ChwButton extends StatefulWidget {
  final String? label;
  final Widget? leading;
  final VoidCallback? onPressed;
  final ChwButtonVariant variant;
  final bool fullWidth;
  final bool large;

  const ChwButton({
    super.key,
    this.label,
    this.leading,
    this.onPressed,
    this.variant = ChwButtonVariant.primary,
    this.fullWidth = false,
    this.large = false,
  });

  @override
  State<ChwButton> createState() => _ChwButtonState();
}

class _ChwButtonState extends State<ChwButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.variant;
    late Color bg;
    late Color fg;
    BoxBorder? border;
    switch (v) {
      case ChwButtonVariant.primary:
        bg = _pressed ? C.nilaDeep : C.nila;
        fg = Colors.white;
        break;
      case ChwButtonVariant.secondary:
        bg = _pressed ? C.midad10 : C.surfaceCard;
        fg = C.nila;
        border = Border.all(color: C.borderCard);
        break;
      case ChwButtonVariant.ghost:
        bg = _pressed ? C.midad10 : Colors.transparent;
        fg = C.nila;
        break;
      case ChwButtonVariant.danger:
        bg = _pressed ? const Color(0xFF8F2C23) : C.aker;
        fg = Colors.white;
        break;
    }

    final child = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.leading != null) ...[
          widget.leading!,
          if (widget.label != null) const SizedBox(width: S.s2),
        ],
        if (widget.label != null)
          Flexible(
            child: Text(
              widget.label!,
              textAlign: TextAlign.center,
              style: Typo.style(
                size: widget.large ? Typo.base : Typo.sm,
                weight: Typo.citation,
                color: fg,
              ),
            ),
          ),
      ],
    );

    return GestureDetector(
      onTapDown: widget.onPressed == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: S.durationFast,
        curve: S.easeOut,
        child: AnimatedContainer(
          duration: S.durationFast,
          curve: S.easeOut,
          width: widget.fullWidth ? double.infinity : null,
          constraints: const BoxConstraints(minHeight: S.tapMin),
          padding: EdgeInsets.symmetric(
            horizontal: widget.large ? S.s6 : S.s5,
            vertical: S.s3,
          ),
          decoration: BoxDecoration(
            color: bg,
            border: border,
            borderRadius: BorderRadius.circular(S.radiusControl),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
