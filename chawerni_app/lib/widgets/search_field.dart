import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'chw_icon.dart';

/// Champ de recherche de la bibliothèque — pilule blanche sur warqa.
class SearchField extends StatelessWidget {
  final String placeholder;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;
  const SearchField({
    super.key,
    required this.placeholder,
    required this.onChanged,
    this.onSubmitted,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.surfaceCard,
        borderRadius: BorderRadius.circular(S.radiusPill),
        border: Border.all(color: C.borderCard),
        boxShadow: S.shadowSoft,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const ChwIcon('search', size: 18, color: C.midad30),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction:
                  onSubmitted != null ? TextInputAction.search : TextInputAction.none,
              cursorColor: C.nila,
              style: Typo.style(size: Typo.base, color: C.midad),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: InputBorder.none,
                hintText: placeholder,
                hintStyle: Typo.style(size: Typo.base, color: C.midad30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
