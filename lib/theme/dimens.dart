/// Échelle des coins arrondis du système de design « Rappel + ».
///
/// Les valeurs reprennent exactement les rayons historiques : les introduire
/// ici ne change donc aucun rendu, cela centralise simplement l'échelle.
abstract final class AppRadius {
  /// 12 px — puces, petites surfaces.
  static const double sm = 12;

  /// 14 px — champs de saisie, boutons secondaires.
  static const double md = 14;

  /// 16 px — boutons principaux, listes.
  static const double lg = 16;

  /// 20 px — cartes.
  static const double xl = 20;

  /// 24 px — boîtes de dialogue.
  static const double xxl = 24;
}

/// Échelle d'espacement du système de design « Rappel + ».
abstract final class AppSpacing {
  /// 4 px — micro espacement interne.
  static const double xs = 4;

  /// 6 px — écart fin entre éléments compacts.
  static const double xsm = 6;

  /// 8 px — micro espacement interne.
  static const double sm = 8;

  /// 12 px — écart entre tuiles jumelles (Heure / Date).
  static const double md = 12;

  /// 16 px — espacement standard des écrans et cartes.
  static const double md2 = 16;

  /// 20 px — marge de page et espacement des grandes sections.
  static const double lg = 20;

  /// 24 px — espacement avant une action principale.
  static const double xl = 24;

  /// 32 px — marge généreuse (états vides).
  static const double xxl = 32;

  /// Marge horizontale des écrans.
  static const double page = lg;
}
