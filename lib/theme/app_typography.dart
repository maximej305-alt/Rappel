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

  /// 26 px, w800, -0.5 — nom de l'application (écran de verrouillage).
  static const TextStyle displaySmall =
      TextStyle(fontSize: 26, fontWeight: w800, letterSpacing: -0.5);

  /// 32 px, w800, -0.5 — très grand chiffre (pourcentages des statistiques).
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: w800,
    letterSpacing: -0.5,
  );

  /// 30 px, w800, -0.5 — grand chiffre (valeurs des statistiques).
  static const TextStyle displayMedium = TextStyle(
    fontSize: 30,
    fontWeight: w800,
    letterSpacing: -0.5,
  );

  /// 28 px, w600 — chiffre du pavé numérique (verrouillage).
  static const TextStyle pinDigit = TextStyle(fontSize: 28, fontWeight: w600);

  /// 18 px, w800 — titre de section / de feuille modale.
  static const TextStyle sectionTitle =
      TextStyle(fontSize: size2xl, fontWeight: w800);

  /// 17 px, w800 — titre de date (calendrier, hebdo).
  static const TextStyle calendarHeader =
      TextStyle(fontSize: sizeXxl, fontWeight: w800);

  /// 19 px, w800, -0.3 — titre d'écran de verrouillage.
  static const TextStyle titleScreen =
      TextStyle(fontSize: 19, fontWeight: w800, letterSpacing: -0.3);

  /// 16 px, w800 — titre moyen accentué.
  static const TextStyle titleMediumStrong =
      TextStyle(fontSize: sizeXl, fontWeight: w800);

  /// 15 px, w700 — titre court (noms d'activité, de routine).
  static const TextStyle titleSmall =
      TextStyle(fontSize: sizeLg, fontWeight: w700);

  /// 12 px, w600 — libellé de champ de formulaire.
  static const TextStyle fieldLabel =
      TextStyle(fontSize: sizeSm, fontWeight: w600);

  /// 15 px, w800 — valeur de champ de formulaire.
  static const TextStyle fieldValue =
      TextStyle(fontSize: sizeLg, fontWeight: w800);

  /// 12 px — légende / texte secondaire. Le poids et la hauteur héritent du
  /// style par défaut (`bodyMedium`), comme un `TextStyle(fontSize: 12)`.
  static const TextStyle caption = TextStyle(fontSize: sizeSm);

  /// 13 px — sous-titre / unité. Hérite du poids par défaut.
  static const TextStyle captionMd = TextStyle(fontSize: sizeMd);

  /// 11 px — micro-libellés. Hérite du poids par défaut.
  static const TextStyle labelXs = TextStyle(fontSize: sizeXs);

  /// 11 px — libellé de navigation (graisse et couleur dynamiques).
  static const TextStyle navLabel = TextStyle(fontSize: sizeXs);

  /// 10 px, w700 — micro-badge.
  static const TextStyle labelMicro = TextStyle(fontSize: 10, fontWeight: w700);

  /// Construit le `TextTheme` Material à partir de l'échelle « Rappel + »,
  /// coloré par [scheme] et composé dans [fontFamily] si fournie.
  ///
  /// Lorsque [fontFamily] est `null` (choix « Police système »), la famille est
  /// **explicitement retirée** de chaque style : `TextStyle.apply` et
  /// `copyWith(fontFamily: null)` conservent en effet la famille héritée de la
  /// Typography Material par défaut (« Roboto » sur Android), ce qui figerait
  /// la police système alors qu'il faut laisser chaque plateforme utiliser sa
  /// police native (Roboto sur Android, SF Pro sur iOS).
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
    final theme = base.copyWith(
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
    return fontFamily == null ? _stripFontFamily(theme) : theme;
  }

  static TextTheme _stripFontFamily(TextTheme t) {
    return stripFontFamily(t);
  }

  /// Retire la famille de police de **tous** les styles d'un [TextTheme].
  /// Nécessaire car `copyWith`/`apply` avec `fontFamily: null` ne modifient
  /// pas une famille déjà posée (« Roboto » dans la Typography par défaut),
  /// et `ThemeData` fusionne toujours sa typographie par défaut dans le
  /// `textTheme` fourni (`defaultTextTheme.merge(textTheme)`).
  static TextTheme stripFontFamily(TextTheme t) {
    TextStyle? clear(TextStyle? style) {
      if (style == null) return null;
      return TextStyle(
        inherit: style.inherit,
        color: style.color,
        backgroundColor: style.backgroundColor,
        fontSize: style.fontSize,
        fontWeight: style.fontWeight,
        fontStyle: style.fontStyle,
        letterSpacing: style.letterSpacing,
        wordSpacing: style.wordSpacing,
        textBaseline: style.textBaseline,
        height: style.height,
        leadingDistribution: style.leadingDistribution,
        locale: style.locale,
        foreground: style.foreground,
        background: style.background,
        shadows: style.shadows,
        fontFeatures: style.fontFeatures,
        fontVariations: style.fontVariations,
        decoration: style.decoration,
        decorationColor: style.decorationColor,
        decorationStyle: style.decorationStyle,
        decorationThickness: style.decorationThickness,
        debugLabel: style.debugLabel,
      );
    }

    return TextTheme(
      displayLarge: clear(t.displayLarge),
      displayMedium: clear(t.displayMedium),
      displaySmall: clear(t.displaySmall),
      headlineLarge: clear(t.headlineLarge),
      headlineMedium: clear(t.headlineMedium),
      headlineSmall: clear(t.headlineSmall),
      titleLarge: clear(t.titleLarge),
      titleMedium: clear(t.titleMedium),
      titleSmall: clear(t.titleSmall),
      labelLarge: clear(t.labelLarge),
      labelMedium: clear(t.labelMedium),
      labelSmall: clear(t.labelSmall),
      bodyLarge: clear(t.bodyLarge),
      bodyMedium: clear(t.bodyMedium),
      bodySmall: clear(t.bodySmall),
    );
  }
}
