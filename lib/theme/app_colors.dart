import 'package:flutter/material.dart';

/// Couleurs brutes du système de design « Rappel + ».
///
/// Constantes de couleurs de base, partagées entre les thèmes, les
/// palettes et les composants. Les couleurs *thémées* (issue du
/// `ColorScheme`) restent calculées dans `AppTheme`.
abstract final class AppColors {
  /// Seed du thème clair (identité historique « Rappel + »).
  static const Color primary = Color(0xFF4F5DFF);

  /// Seed du thème sombre.
  static const Color primaryDark = Color(0xFF9AA5FF);

  /// Dégradé d'en-tête (clair).
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF4F5DFF), Color(0xFF7A5CFF)],
  );

  /// Dégradé d'en-tête (sombre).
  static const LinearGradient headerGradientDark = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF3B47D6), Color(0xFF6749D6)],
  );

  /// Palette des couleurs de catégories — indexée par `Category.colorIndex`.
  static const List<Color> categoryPalette = [
    Color(0xFF4F5DFF),
    Color(0xFFE85D4A),
    Color(0xFF2E9E6B),
    Color(0xFFE0A53B),
    Color(0xFF8B6FE8),
    Color(0xFF3FB6C9),
  ];
}
