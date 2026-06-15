import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Bulle de chat. user → nila / blanc, aligné à la fin (côté utilisateur).
/// app → nila-light / midad, aligné au début. Rayon 24, direction-aware.
class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final double fontSize;
  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.fontSize = Typo.base,
  });

  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(S.radiusBubble);
    // Coin « rentrant » côté émetteur, comme dans les maquettes.
    final shape = isUser
        ? BorderRadius.only(
            topLeft: radius,
            topRight: radius,
            bottomLeft: radius,
            bottomRight: const Radius.circular(6),
          )
        : BorderRadius.only(
            topLeft: radius,
            topRight: radius,
            bottomRight: radius,
            bottomLeft: const Radius.circular(6),
          );

    return Align(
      alignment:
          isUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isUser ? C.nila : C.nilaLight,
            borderRadius: shape,
          ),
          child: Text(
            text,
            style: Typo.style(
              size: fontSize,
              color: isUser ? Colors.white : C.midad,
              height: 1.55,
            ),
          ),
        ),
      ),
    );
  }
}
