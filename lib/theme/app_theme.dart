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
  static Color categoryColor(int index) =>
      AppColors.categoryPalette[index % AppColors.categoryPalette.length];

  /// Dégradé d'en-tête (clair).
  static const LinearGradient headerGradient = AppColors.headerGradient;

  /// Dégradé d'en-tête (sombre).
  static const LinearGradient headerGradientDark =
      AppColors.headerGradientDark;

  /// Thème clair historique (palette « Classic »).
  static ThemeData get light => _base(ThemePalette.classic, Brightness.light);

  /// Thème sombre historique (palette « Classic »).
  static ThemeData get dark => _base(ThemePalette.classic, Brightness.dark);

  static ThemeData _base(ThemePalette palette, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.seedFor(brightness),
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF13151E) : Colors.white;

    final textTheme = AppTypography.buildTextTheme(scheme, fontFamily: 'Inter');

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      fontFamily: 'Inter',
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
        color: isDark
            ? const Color(0xFF1D202C)
            : const Color(0xFFF6F7FB),
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
        fillColor: isDark ? const Color(0xFF1D202C) : const Color(0xFFF0F1F6),
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
