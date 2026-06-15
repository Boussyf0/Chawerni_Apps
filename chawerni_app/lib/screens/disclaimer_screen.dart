import 'package:flutter/material.dart';

import '../data/strings.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/chw_button.dart';
import '../widgets/chw_icon.dart';

/// Disclaimer légal bloquant. Honnêteté structurelle : on n'est jamais avocat.
/// « فهمت — J'ai compris » + lien « Trouver un avocat ».
class DisclaimerScreen extends StatelessWidget {
  final VoidCallback onDone;
  const DisclaimerScreen({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final t = T(AppScope.of(context).lang);
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: C.nilaLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: ChwIcon('hand', size: 30, color: C.nila),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t.discTitle,
                    style: Typo.style(
                      size: Typo.lg,
                      weight: Typo.bold,
                      color: C.midad,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(S.s4),
                    decoration: BoxDecoration(
                      color: C.akerLight,
                      borderRadius: BorderRadius.circular(S.radiusCard),
                    ),
                    child: Text(
                      t.discBody,
                      style: Typo.style(
                        size: Typo.base,
                        color: C.midad,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    T.faith,
                    textDirection: TextDirection.rtl,
                    style: Typo.style(size: Typo.sm, color: C.midad60),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: ChwButton(
              label: t.discBtn,
              large: true,
              fullWidth: true,
              onPressed: onDone,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: GestureDetector(
              onTap: () {},
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: C.zellijLight, width: 1),
                  ),
                ),
                child: Text(
                  t.discLink,
                  style: Typo.style(
                    size: Typo.sm,
                    weight: Typo.medium,
                    color: C.zellij,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
