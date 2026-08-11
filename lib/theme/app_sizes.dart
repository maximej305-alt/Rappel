/// Dimensions du système de design « Rappel + ».
///
/// Centralise les tailles structurelles (boutons, navigation, cibles
/// tactiles) utilisées par l'application. Les tailles de police sont dans
/// `AppTypography`.
abstract final class AppSizes {
  /// Cible tactile minimale recommandée (accessibilité).
  static const double minTouchTarget = 44;

  /// Hauteur des boutons principaux (FilledButton).
  static const double buttonHeightPrimary = 54;

  /// Hauteur des boutons secondaires (OutlinedButton).
  static const double buttonHeightSecondary = 48;

  /// Hauteur de la barre de navigation inférieure.
  static const double bottomNavHeight = 66;
}
