import 'package:flutter/material.dart';

/// Couleurs d'accent « de mise en avant » — indépendantes de la palette.
///
/// La palette définit l'identité globale (thème Material 3 + dégradés
/// d'en-tête) ; l'accent colore les éléments d'action ponctuels (bouton
/// flottant, série, barres du graphique d'habitudes).
enum AccentColor {
  indigo,
  teal,
  rose,
  amber,
  emerald,
  purple;

  /// Couleur en thème clair.
  Color get light => switch (this) {
        AccentColor.indigo => const Color(0xFF4F5DFF),
        AccentColor.teal => const Color(0xFF0F766E),
        AccentColor.rose => const Color(0xFFE11D48),
        AccentColor.amber => const Color(0xFF92400E),
        AccentColor.emerald => const Color(0xFF047857),
        AccentColor.purple => const Color(0xFF9333EA),
      };

  /// Couleur en thème sombre — plus claire pour préserver le contraste.
  Color get dark => switch (this) {
        AccentColor.indigo => const Color(0xFF9AA5FF),
        AccentColor.teal => const Color(0xFF2DD4BF),
        AccentColor.rose => const Color(0xFFFB7185),
        AccentColor.amber => const Color(0xFFFBBF24),
        AccentColor.emerald => const Color(0xFF34D399),
        AccentColor.purple => const Color(0xFFC084FC),
      };

  /// Couleur effective selon la luminosité.
  Color forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
