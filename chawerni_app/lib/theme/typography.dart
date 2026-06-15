import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// CHAWERNI — Typographie. IBM Plex Sans (latin) + IBM Plex Sans Arabic (arabe).
/// Même famille des deux côtés = cohérence bilingue. On compose une pile :
/// latin en primaire, arabe en repli — un même style rend FR et عربية sans rupture.
class Typo {
  // Échelle : 12 / 14 / 16 / 18 / 22 / 28
  static const xs = 12.0; // métadonnées, badge version
  static const sm = 14.0; // texte secondaire, chips, extraits
  static const base = 16.0; // corps — généreux, lectorat stressé
  static const md = 18.0; // titres de carte, citations en exergue
  static const lg = 22.0; // titres d'écran
  static const xl = 28.0; // onboarding, grands titres

  // Graisses
  static const regular = FontWeight.w400;
  static const medium = FontWeight.w500;
  static const citation = FontWeight.w600; // articles de loi — héros typo
  static const bold = FontWeight.w700;

  static String? _arabicFamily;

  /// Repli arabe enregistré par google_fonts (chargé une fois).
  static String? get _arabic {
    _arabicFamily ??= GoogleFonts.ibmPlexSansArabic().fontFamily;
    return _arabicFamily;
  }

  /// Style de base : IBM Plex Sans, avec IBM Plex Sans Arabic en repli pour
  /// que l'arabe rende dans la même famille sans qu'on ait à brancher par script.
  static TextStyle style({
    double size = base,
    FontWeight weight = regular,
    Color color = C.midad,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.ibmPlexSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    ).copyWith(fontFamilyFallback: [if (_arabic != null) _arabic!]);
  }

  /// Chiffres tabulaires pour les numéros d'article (« Art. 446 » s'aligne).
  static TextStyle article({
    double size = base,
    FontWeight weight = citation,
    Color color = C.midad,
  }) {
    return style(size: size, weight: weight, color: color).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}

/// ThemeData global de l'app — fond warqa, primaire nila, pile bilingue.
ThemeData buildChawerniTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: C.warqa,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.nila,
      primary: C.nila,
      surface: C.warqa,
      brightness: Brightness.light,
    ),
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: GoogleFonts.ibmPlexSansTextTheme(base.textTheme).apply(
      bodyColor: C.midad,
      displayColor: C.midad,
      fontFamilyFallback: [if (Typo._arabic != null) Typo._arabic!],
    ),
  );
}
