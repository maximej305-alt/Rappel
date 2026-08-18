import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_sizes.dart';
import 'app_typography.dart';
import 'dimens.dart';
import 'theme_palette.dart';

/// Système de design « Rappel + ».
///
/// Construit les thèmes clair/sombre à partir d'une palette (`ThemePalette`)
/// et des tokens de design (`AppColors`, `AppSizes`, `AppTypography`).
class AppTheme {
  AppTheme._();

  /// Seed historique du thème clair (rétrocompatibilité).
  static const Color seed = AppColors.primary;

  /// Seed historique du thème sombre (rétrocompatibilité).
  static const Color seedDark = AppColors.primaryDark;

  /// Palette des catégories (indice via `Category.colorIndex`).
  static const List<Color> categoryPalette = AppColors.categoryPalette;

  /// Couleur d'une catégorie selon son [Category.colorIndex], cyclique.
  /// La première couleur suit l'accent de la [palette] active ; les autres
  /// restent identiques pour préserver la reconnaissance.
  static Color categoryColor(
    int index, {
    ThemePalette palette = ThemePalette.classic,
  }) {
    final colors = palette.categoryColors;
    return colors[index % colors.length];
  }

  /// Dégradé d'en-tête (clair).
  static const LinearGradient headerGradient = AppColors.headerGradient;

  /// Dégradé d'en-tête (sombre).
  static const LinearGradient headerGradientDark =
      AppColors.headerGradientDark;

  /// Dégradé d'en-tête d'une [palette] selon le thème clair/sombre.
  static LinearGradient headerGradientFor(ThemePalette palette, bool isDark) =>
      palette.headerGradientFor(isDark ? Brightness.dark : Brightness.light);

  /// Couleur d'accent d'une [palette] selon le thème clair/sombre.
  static Color seedFor(ThemePalette palette, bool isDark) =>
      palette.seedFor(isDark ? Brightness.dark : Brightness.light);

  /// Thème clair historique (palette « Classic »).
  static ThemeData get light => lightFor(ThemePalette.classic);

  /// Thème sombre historique (palette « Classic »).
  static ThemeData get dark => darkFor(ThemePalette.classic);

  /// Thème clair d'une palette donnée.
  static ThemeData lightFor(
    ThemePalette palette, {
    String fontFamily = 'System',
  }) =>
      _base(palette, Brightness.light, fontFamily: fontFamily);

  /// Thème sombre d'une palette donnée.
  static ThemeData darkFor(
    ThemePalette palette, {
    bool amoled = false,
    String fontFamily = 'System',
  }) =>
      _base(palette, Brightness.dark, amoled: amoled, fontFamily: fontFamily);

  /// Polices de l'interface. « System » utilise la police par défaut du
  /// système ; les autres sont embarquées. Une seule source de vérité :
  /// chaque famille ajoutée ici doit être déclarée dans `pubspec.yaml` sous
  /// le même nom (le test `font_typography_test.dart` le vérifie).
  static const List<String> fontFamilies = [
    'System',
    'Inter',
    'Nunito',
    'Lora',
    'Montserrat',
    'Poppins',
    'PlayfairDisplay',
    'WorkSans',
    'Quicksand',
    'JetBrainsMono',
    'Caveat',
    'BebasNeue',
    'SourceSans3',
    'SpaceGrotesk',
  ];

  /// Libellé lisible d'une famille (ex. `PlayfairDisplay` → « Playfair
  /// Display », `JetBrainsMono` → « JetBrains Mono »). Mappage explicite pour
  /// un affichage fidèle au nom commercial de chaque police. « System » reste
  /// tel quel : l'écran de réglages affiche le nom localisé à la place.
  static const Map<String, String> fontDisplayNames = {
    'System': 'System',
    'Inter': 'Inter',
    'Nunito': 'Nunito',
    'Lora': 'Lora',
    'Montserrat': 'Montserrat',
    'Poppins': 'Poppins',
    'PlayfairDisplay': 'Playfair Display',
    'WorkSans': 'Work Sans',
    'Quicksand': 'Quicksand',
    'JetBrainsMono': 'JetBrains Mono',
    'Caveat': 'Caveat',
    'BebasNeue': 'Bebas Neue',
    'SourceSans3': 'Source Sans 3',
    'SpaceGrotesk': 'Space Grotesk',
  };

  /// Affichage d'une [family] ; repli sur la clé si le nom n'est pas connu.
  static String fontDisplayName(String family) =>
      fontDisplayNames[family] ?? family;

  static ThemeData _base(
    ThemePalette palette,
    Brightness brightness, {
    bool amoled = false,
    String fontFamily = 'Inter',
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.seedFor(brightness),
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    // AMOLED : noirs profonds (économie d'énergie OLED) en thème sombre.
    final surface = isDark
        ? (amoled ? const Color(0xFF000000) : const Color(0xFF13151E))
        : Colors.white;
    // Garde un « noir très proche » pour les cartes en AMOLED, le vrai noir
    // pur reste réservé au fond pour maximiser l'économie d'écran.
    final cardColor = isDark
        ? (amoled ? const Color(0xFF0D0D0D) : const Color(0xFF1D202C))
        : const Color(0xFFF6F7FB);
    final inputFill = isDark
        ? (amoled ? const Color(0xFF111111) : const Color(0xFF1D202C))
        : const Color(0xFFF0F1F6);

    final textTheme = AppTypography.buildTextTheme(
      scheme,
      fontFamily: fontFamily == 'System' ? null : fontFamily,
    );

    // Typographie par défaut sans famille : `ThemeData` fusionne toujours
    // `defaultTextTheme.merge(textTheme)`, or les styles en `fontFamily: null`
    // (choix « Police système ») deviendraient « Roboto » sans cela, ce qui
    // figerait la police même sur iOS.
    final baseTypography = Typography.material2021(
      platform: defaultTargetPlatform,
      colorScheme: scheme,
    );
    final typography = baseTypography.copyWith(
      black: AppTypography.stripFontFamily(baseTypography.black),
      white: AppTypography.stripFontFamily(baseTypography.white),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      typography: typography,
      scaffoldBackgroundColor: surface,
      fontFamily: fontFamily == 'System' ? null : fontFamily,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle:
            AppTypography.appBar.copyWith(color: scheme.onSurface),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeightPrimary),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg)),
          textStyle: AppTypography.buttonPrimary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.buttonHeightSecondary),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: AppTypography.buttonSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        hintStyle: TextStyle(color: scheme.outline, fontSize: AppTypography.sizeBase),
        labelStyle: TextStyle(color: scheme.outline, fontSize: AppTypography.sizeBase),
        prefixIconColor: scheme.outline,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 17),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const CircleBorder(),
        side: BorderSide(color: scheme.outline, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xxl)),
        titleTextStyle:
            AppTypography.dialogTitle.copyWith(color: scheme.onSurface),
        contentTextStyle:
            TextStyle(fontSize: AppTypography.sizeBase, color: scheme.onSurfaceVariant),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF2A2D3A) : const Color(0xFF23242F),
        contentTextStyle: const TextStyle(
            color: Colors.white, fontSize: AppTypography.sizeBase),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.4),
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF232631) : const Color(0xFFECEDF4),
        selectedColor: scheme.primary,
        labelStyle: AppTypography.chip.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: AppTypography.chip.copyWith(color: scheme.onPrimary),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
    );
  }
}
