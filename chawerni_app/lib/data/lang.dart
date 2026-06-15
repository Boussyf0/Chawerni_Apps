import 'package:flutter/material.dart';

/// Les trois langues de Chawerni. La darija (`da`) s'écrit en graphie arabe,
/// jamais en translittération latine. FR est le cas « LTR dans une app RTL ».
enum Lang {
  fr('fr', TextDirection.ltr),
  ar('ar', TextDirection.rtl),
  da('da', TextDirection.rtl);

  const Lang(this.code, this.dir);

  final String code;
  final TextDirection dir;

  bool get isRtl => dir == TextDirection.rtl;

  /// Pour les contenus juridiques bilingues : la darija réutilise les textes ar.
  String get contentKey => this == Lang.fr ? 'fr' : 'ar';

  static Lang fromCode(String? c) =>
      Lang.values.firstWhere((l) => l.code == c, orElse: () => Lang.fr);
}

/// Direction d'un fragment de texte d'après son contenu (présence d'arabe).
/// Utile pour les chaînes mixtes (« بالدارجة … en français »).
TextDirection dirOf(String text) {
  final hasArabic = RegExp(r'[؀-ۿ]').hasMatch(text);
  return hasArabic ? TextDirection.rtl : TextDirection.ltr;
}
