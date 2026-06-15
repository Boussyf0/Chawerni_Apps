import 'package:flutter/material.dart';

/// CHAWERNI — Design tokens (couleurs, espace, forme, mouvement).
/// Portage fidèle de `tokens/*.css` du design system. Tokens nommés en darija.
/// Règle d'or : `warqa` partout, jamais de blanc pur — les cartes blanches sont
/// le seul blanc autorisé, posées SUR warqa.
class C {
  // ——— Base palette ———
  static const nila = Color(0xFF2D3A8C); // نيلة — bleu Majorelle. Primaire.
  static const nilaLight = Color(0xFFE8EAFB); // bulle de réponse, surfaces 2nd
  static const zellij = Color(0xFF0E7C6B); // vert zellige — succès, sources
  static const zaafran = Color(0xFFE8A13D); // زعفران — accent citation
  static const warqa = Color(0xFFFAF7F1); // ورقة — papier. Fond principal.
  static const midad = Color(0xFF1E1B18); // مداد — encre. Texte principal.
  static const midad60 = Color(0xFF5C564F); // texte secondaire, métadonnées
  static const aker = Color(0xFFB3382C); // عكر فاسي — disclaimers, enjeu grave

  // ——— Derived tints ———
  static const nilaDeep = Color(0xFF232E73); // press state du primaire
  static const zellijLight = Color(0xFFE2F1EE); // fond badge « à jour »
  static const zaafranLight = Color(0xFFFBEEDA); // puce numéro d'article
  static const akerLight = Color(0xFFF8E9E7); // fond bandeau disclaimer
  static const midad30 = Color(0xFFB9B2A9); // placeholders, désactivés
  static const midad10 = Color(0xFFE9E4DC); // hairlines, séparateurs

  // ——— Semantic ———
  static const surfaceCard = Color(0xFFFFFFFF); // seul blanc autorisé
  static const borderCard = Color(0x121E1B18); // rgba(30,27,24,0.07)

  // Accents par matière (Bibliothèque)
  static const matierePenal = aker;
  static const matiereFamille = zaafran;
  static const matiereTravail = zellij;
  static const matiereCivil = nila;

  static Color matiere(String accent) {
    switch (accent) {
      case 'penal':
        return matierePenal;
      case 'famille':
        return matiereFamille;
      case 'travail':
        return matiereTravail;
      default:
        return matiereCivil;
    }
  }
}

/// Espacement (base 4), rayons, ombres, mouvement.
class S {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;
  static const s12 = 48.0;

  // Rayons — rondeur hospitalière, jamais de coins vifs.
  static const radiusCard = 16.0;
  static const radiusBubble = 24.0;
  static const radiusSheet = 24.0;
  static const radiusControl = 12.0;
  static const radiusPill = 999.0;

  // Cible tactile minimale.
  static const tapMin = 48.0;

  // Ombres très douces — la hiérarchie vient de la couleur de fond.
  static const List<BoxShadow> shadowSoft = [
    BoxShadow(color: Color(0x0F1E1B18), blurRadius: 12, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> shadowSheet = [
    BoxShadow(color: Color(0x1F1E1B18), blurRadius: 32, offset: Offset(0, -8)),
  ];

  // Mouvement : 200–250 ms, ease-out, sobre.
  static const durationFast = Duration(milliseconds: 200);
  static const durationBase = Duration(milliseconds: 250);
  static const Curve easeOut = Cubic(0.2, 0.8, 0.3, 1);
}
