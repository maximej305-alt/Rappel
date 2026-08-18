import 'package:flutter/material.dart';

import 'app_colors.dart';

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
  sunset,
  rose,
  azure,
  slate;

  /// Couleur d'accent (seed) en thème clair.
  Color get seedLight => switch (this) {
        ThemePalette.classic => const Color(0xFF4F5DFF),
        ThemePalette.ocean => const Color(0xFF00796B),
        ThemePalette.purple => const Color(0xFF7B1FA2),
        ThemePalette.forest => const Color(0xFF2E7D32),
        ThemePalette.sunset => const Color(0xFFE64A19),
        ThemePalette.rose => const Color(0xFFC2185B),
        ThemePalette.azure => const Color(0xFF0277BD),
        ThemePalette.slate => const Color(0xFF455A64),
      };

  /// Couleur d'accent (seed) en thème sombre — souvent plus claire pour
  /// préserver le contraste sur fond sombre.
  Color get seedDark => switch (this) {
        ThemePalette.classic => const Color(0xFF9AA5FF),
        ThemePalette.ocean => const Color(0xFF80CBC4),
        ThemePalette.purple => const Color(0xFFCE93D8),
        ThemePalette.forest => const Color(0xFFA5D6A7),
        ThemePalette.sunset => const Color(0xFFFFAB91),
        ThemePalette.rose => const Color(0xFFF48FB1),
        ThemePalette.azure => const Color(0xFF81D4FA),
        ThemePalette.slate => const Color(0xFFB0BEC5),
      };

  /// Couleur d'accent effective selon la luminosité.
  Color seedFor(Brightness brightness) =>
      brightness == Brightness.dark ? seedDark : seedLight;

  /// Dégradé d'en-tête/logo en thème clair.
  LinearGradient get headerGradient => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: _headerColors(false),
      );

  /// Dégradé d'en-tête/logo en thème sombre.
  LinearGradient get headerGradientDark => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: _headerColors(true),
      );

  /// Dégradé d'en-tête effective selon la luminosité.
  LinearGradient headerGradientFor(Brightness brightness) =>
      brightness == Brightness.dark ? headerGradientDark : headerGradient;

  List<Color> _headerColors(bool dark) => switch (this) {
        // « Classic » reproduit le dégradé historique.
        ThemePalette.classic => dark
            ? const [Color(0xFF3B47D6), Color(0xFF6749D6)]
            : const [Color(0xFF4F5DFF), Color(0xFF7A5CFF)],
        ThemePalette.ocean => dark
            ? const [Color(0xFF005A4B), Color(0xFF00897B)]
            : const [Color(0xFF00796B), Color(0xFF00A896)],
        ThemePalette.purple => dark
            ? const [Color(0xFF4A148C), Color(0xFF7B1FA2)]
            : const [Color(0xFF7B1FA2), Color(0xFF9C27B0)],
        ThemePalette.forest => dark
            ? const [Color(0xFF1B5E20), Color(0xFF2E7D32)]
            : const [Color(0xFF2E7D32), Color(0xFF43A047)],
        ThemePalette.sunset => dark
            ? const [Color(0xFFBF360C), Color(0xFFE64A19)]
            : const [Color(0xFFE64A19), Color(0xFFFF7043)],
        ThemePalette.rose => dark
            ? const [Color(0xFF880E4F), Color(0xFFC2185B)]
            : const [Color(0xFFC2185B), Color(0xFFE91E63)],
        ThemePalette.azure => dark
            ? const [Color(0xFF01579B), Color(0xFF0277BD)]
            : const [Color(0xFF0277BD), Color(0xFF29B6F6)],
        ThemePalette.slate => dark
            ? const [Color(0xFF263238), Color(0xFF455A64)]
            : const [Color(0xFF455A64), Color(0xFF607D8B)],
      };

  /// Couleurs de catégories : la première suit l'accent de la palette,
  /// les autres restent identiques pour préserver la reconnaissance des
  /// couleurs attribuées aux catégories.
  List<Color> get categoryColors {
    final base = AppColors.categoryPalette;
    return [seedLight, ...base.sublist(1)];
  }
}
