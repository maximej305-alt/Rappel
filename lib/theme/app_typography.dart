import 'package:flutter/material.dart';

/// Échelle typographique du système de design « Rappel + ».
///
/// Centralise les tailles et graisses utilisées par l'application. Les
/// styles nommés sont **sans couleur** : la couleur est appliquée au moment
/// de la construction du `TextTheme` (via [buildTextTheme]) pour respecter
/// le `ColorScheme` du thème actif.
abstract final class AppTypography {
  // ————— Tailles —————
  /// 11 px — libellés de navigation.
  static const double sizeXs = 11;

  /// 12 px — libellés secondaires / captures.
  static const double sizeSm = 12;

  /// 13 px — sous-titres de puces.
  static const double sizeMd = 13;

  /// 14 px — texte de base.
  static const double sizeBase = 14;

  /// 15 px — boutons principaux.
  static const double sizeLg = 15;

  /// 16 px — titres moyens.
  static const double sizeXl = 16;

  /// 17 px — titres d'en-tête du calendrier.
  static const double sizeXxl = 17;

  /// 18 px — titres de section / boîtes de dialogue.
  static const double size2xl = 18;

  /// 20 px — titres d'écran (AppBar) / date du jour.
  static const double size3xl = 20;

  /// 24 px — titres majeurs.
  static const double size4xl = 24;

  // ————— Graisses —————
  static const FontWeight w400 = FontWeight.w400;
  static const FontWeight w500 = FontWeight.w500;
  static const FontWeight w600 = FontWeight.w600;
  static const FontWeight w700 = FontWeight.w700;
  static const FontWeight w800 = FontWeight.w800;

  // ————— Styles nommés (sans couleur) —————
  /// 24 px, w800, -0.5 — titre principal d'écran (accueil, statistiques).
  static const TextStyle headlineSmall = TextStyle(
    fontSize: size4xl,
    fontWeight: w800,
    letterSpacing: -0.5,
  );

  /// 18 px, w700, -0.3 — titres de section / dialogues.
  static const TextStyle titleLarge = TextStyle(
    fontSize: size2xl,
    fontWeight: w700,
    letterSpacing: -0.3,
  );

  /// 16 px, w600 — titres moyens (cartes).
  static const TextStyle titleMedium =
      TextStyle(fontSize: sizeXl, fontWeight: w600);

  /// 14 px, w400, hauteur 1.35 — texte courant.
  static const TextStyle bodyMedium =
      TextStyle(fontSize: sizeBase, fontWeight: w400, height: 1.35);

  /// 12 px, w500 — texte secondaire / captures.
  static const TextStyle bodySmall =
      TextStyle(fontSize: sizeSm, fontWeight: w500);

  /// 14 px, w700 — boutons / actions.
  static const TextStyle labelLarge =
      TextStyle(fontSize: sizeBase, fontWeight: w700);

  /// 15 px, w700 — boutons principaux (FilledButton).
  static const TextStyle buttonPrimary =
      TextStyle(fontSize: sizeLg, fontWeight: w700);

  /// 14 px, w700 — boutons secondaires (OutlinedButton).
  static const TextStyle buttonSecondary =
      TextStyle(fontSize: sizeBase, fontWeight: w700);

  /// 20 px, w800, -0.3 — titre de l'AppBar.
  static const TextStyle appBar =
      TextStyle(fontSize: size3xl, fontWeight: w800, letterSpacing: -0.3);

  /// 18 px, w800 — titre des boîtes de dialogue.
  static const TextStyle dialogTitle =
      TextStyle(fontSize: size2xl, fontWeight: w800);

  /// 13 px, w600 — libellés de puces (Chip).
  static const TextStyle chip = TextStyle(fontSize: sizeMd, fontWeight: w600);

  /// Construit le `TextTheme` Material à partir de l'échelle « Rappel + »,
  /// coloré par [scheme] et composé dans [fontFamily] si fournie.
  static TextTheme buildTextTheme(ColorScheme scheme, {String? fontFamily}) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
    ).textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
      fontFamily: fontFamily,
    );
    return base.copyWith(
      headlineSmall: headlineSmall.copyWith(
        color: scheme.onSurface,
        fontFamily: fontFamily,
      ),
      titleLarge: titleLarge.copyWith(
        color: scheme.onSurface,
        fontFamily: fontFamily,
      ),
      titleMedium: titleMedium.copyWith(
        color: scheme.onSurface,
        fontFamily: fontFamily,
      ),
      bodyMedium: bodyMedium.copyWith(
        color: scheme.onSurface,
        fontFamily: fontFamily,
      ),
      bodySmall: bodySmall.copyWith(
        color: scheme.onSurfaceVariant,
        fontFamily: fontFamily,
      ),
      labelLarge: labelLarge.copyWith(
        color: scheme.onSurface,
        fontFamily: fontFamily,
      ),
    );
  }
}
