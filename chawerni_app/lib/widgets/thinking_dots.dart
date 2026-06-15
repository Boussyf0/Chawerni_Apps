import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// État de réflexion : trois losanges zaafran qui pulsent + micro-texte rotatif
/// (« Je fouille les textes… » / « أنا كنقلّب في النصوص… »).
class ThinkingDots extends StatefulWidget {
  final List<String> labels;
  const ThinkingDots({super.key, required this.labels});

  @override
  State<ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _labelTimer;
  int _labelIndex = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    if (widget.labels.length > 1) {
      _labelTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
        if (mounted) {
          setState(() => _labelIndex = (_labelIndex + 1) % widget.labels.length);
        }
      });
    }
  }

  @override
  void dispose() {
    _labelTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: C.nilaLight,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(S.radiusBubble),
            topRight: Radius.circular(S.radiusBubble),
            bottomRight: Radius.circular(S.radiusBubble),
            bottomLeft: const Radius.circular(6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < 3; i++) ...[
              _Dot(controller: _c, phase: i / 3),
              if (i < 2) const SizedBox(width: 7),
            ],
            const SizedBox(width: 12),
            AnimatedSwitcher(
              duration: S.durationBase,
              child: Text(
                widget.labels[_labelIndex],
                key: ValueKey(_labelIndex),
                style: Typo.style(size: Typo.sm, color: C.midad60),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final AnimationController controller;
  final double phase;
  const _Dot({required this.controller, required this.phase});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = (controller.value + phase) % 1.0;
        final pulse = (0.4 + 0.6 * (1 - (2 * t - 1).abs())).clamp(0.0, 1.0);
        return Opacity(
          opacity: pulse,
          child: Transform.rotate(
            angle: 0.7853981633974483,
            child: Container(width: 8, height: 8, color: C.zaafran),
          ),
        );
      },
    );
  }
}
