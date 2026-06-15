import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'accent_card.dart';
import 'version_badge.dart';

/// SourceCard ⭐ — LE composant signature. Carte de citation :
/// barre latérale zaafran, puce numéro d'article (chiffres tabulaires),
/// extrait 2 lignes, badge de version daté, mention « العربية تعتمد ».
/// `unfold` : entrée « comme un document qui se déplie » (translateY + scaleY
/// depuis le haut), la signature animée du design system.
class SourceCard extends StatefulWidget {
  final String num;
  final String code;
  final String excerpt;
  final String date;
  final bool stale;
  final bool unfold;
  final VoidCallback? onTap;

  const SourceCard({
    super.key,
    required this.num,
    required this.code,
    required this.excerpt,
    required this.date,
    this.stale = false,
    this.unfold = false,
    this.onTap,
  });

  @override
  State<SourceCard> createState() => _SourceCardState();
}

class _SourceCardState extends State<SourceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: S.durationBase);
    if (widget.unfold) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: S.durationFast,
        curve: S.easeOut,
        child: AccentCard(
          accent: C.zaafran,
          child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            // Puce numéro d'article.
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: C.zaafranLight,
                                borderRadius:
                                    BorderRadius.circular(S.radiusPill),
                              ),
                              child: Text(
                                widget.num,
                                style: Typo.article(
                                  size: Typo.sm,
                                  weight: Typo.citation,
                                  color: C.midad,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                widget.code,
                                overflow: TextOverflow.ellipsis,
                                style: Typo.style(
                                  size: Typo.sm,
                                  weight: Typo.medium,
                                  color: C.midad60,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.excerpt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Typo.style(
                            size: Typo.sm,
                            color: C.midad,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            VersionBadge(date: widget.date, stale: widget.stale),
                            const Spacer(),
                            Text(
                              'العربية تعتمد',
                              textDirection: TextDirection.rtl,
                              style: Typo.style(
                                size: Typo.xs,
                                color: C.midad30,
                              ),
                            ),
                          ],
                        ),
            ],
          ),
        ),
      ),
    );

    if (!widget.unfold) return card;

    // Déploiement « document » : scaleY depuis le haut + fondu + léger glissé.
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = S.easeOut.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * -8),
            child: Transform(
              alignment: Alignment.topCenter,
              transform: Matrix4.identity()
                ..scaleByDouble(1.0, 0.85 + 0.15 * t, 1.0, 1.0),
              child: child,
            ),
          ),
        );
      },
      child: card,
    );
  }
}
