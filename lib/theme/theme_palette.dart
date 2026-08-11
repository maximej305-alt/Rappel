import 'package:flutter/material.dart';

/// Palettes de couleurs du système de design « Rappel + ».
///
/// Chaque palette fournit une couleur d'accent (seed Material 3) pour le
/// thème clair et pour le thème sombre. « Classic » reproduit l'identité
/// historique de l'application (seed indigo actuel).
enum ThemePalette {
  classic,
  ocean,
  purple,
  forest,
  sunset;

  /// Couleur d'accent (seed) en thème clair.
  Color get seedLight => switch (this) {
        ThemePalette.classic => const Color(0xFF4F5DFF),
        ThemePalette.ocean => const Color(0xFF00796B),
        ThemePalette.purple => const Color(0xFF7B1FA2),
        ThemePalette.forest => const Color(0xFF2E7D32),
        ThemePalette.sunset => const Color(0xFFE64A19),
      };

  /// Couleur d'accent (seed) en thème sombre — souvent plus claire pour
  /// préserver le contraste sur fond sombre.
  Color get seedDark => switch (this) {
        ThemePalette.classic => const Color(0xFF9AA5FF),
        ThemePalette.ocean => const Color(0xFF80CBC4),
        ThemePalette.purple => const Color(0xFFCE93D8),
        ThemePalette.forest => const Color(0xFFA5D6A7),
        ThemePalette.sunset => const Color(0xFFFFAB91),
      };

  /// Couleur d'accent effective selon la luminosité.
  Color seedFor(Brightness brightness) =>
      brightness == Brightness.dark ? seedDark : seedLight;
}
