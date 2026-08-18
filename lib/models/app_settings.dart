import 'package:flutter/material.dart';

import '../theme/accent_color.dart';
import '../theme/app_theme.dart';
import '../theme/theme_palette.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale = 'fr',
    this.reminderOffsetMinutes = 0,
    this.defaultSound = 'default',
    this.palette = ThemePalette.classic,
    this.accent = AccentColor.indigo,
    this.textScale = 1.0,
    this.amoled = false,
    this.fontFamily = 'System',
    this.alarmMode = true,
  });

  final ThemeMode themeMode;
  final String locale;
  final int reminderOffsetMinutes;
  final String defaultSound;
  final ThemePalette palette;
  final AccentColor accent;

  /// Échelle de texte (accessibilité). 1.0 = taille normale.
  final double textScale;

  /// Mode « AMOLED » : noirs profonds en thème sombre (économie OLED).
  final bool amoled;

  /// Police d'interface : « System » (défaut) ou « Inter » (embarquée).
  final String fontFamily;

  /// Mode Alarme : la sonnerie répète de manière continue jusqu'à l'action utilisateur (Android).
  final bool alarmMode;

  static const List<int> reminderOptions = [0, 5, 10, 15, 30, 60];
  static const List<double> textScaleOptions = [0.85, 1.0, 1.15, 1.3, 1.5];

  /// Polices disponibles, source unique : `AppTheme.fontFamilies`.
  static List<String> get fontOptions => AppTheme.fontFamilies;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? locale,
    int? reminderOffsetMinutes,
    String? defaultSound,
    ThemePalette? palette,
    AccentColor? accent,
    double? textScale,
    bool? amoled,
    String? fontFamily,
    bool? alarmMode,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      reminderOffsetMinutes:
          reminderOffsetMinutes ?? this.reminderOffsetMinutes,
      defaultSound: defaultSound ?? this.defaultSound,
      palette: palette ?? this.palette,
      accent: accent ?? this.accent,
      textScale: textScale ?? this.textScale,
      amoled: amoled ?? this.amoled,
      fontFamily: fontFamily ?? this.fontFamily,
      alarmMode: alarmMode ?? this.alarmMode,
    );
  }

  Map<String, dynamic> toMap() => {
        'themeMode': themeMode.name,
        'locale': locale,
        'reminderOffsetMinutes': reminderOffsetMinutes,
        'defaultSound': defaultSound,
        'palette': palette.name,
        'accent': accent.name,
        'textScale': textScale,
        'amoled': amoled,
        'fontFamily': fontFamily,
        'alarmMode': alarmMode,
      };

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == map['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      locale: (map['locale'] as String?) ?? 'fr',
      reminderOffsetMinutes: (map['reminderOffsetMinutes'] as int?) ?? 0,
      defaultSound: (map['defaultSound'] as String?) ?? 'default',
      palette: ThemePalette.values.firstWhere(
        (p) => p.name == map['palette'],
        orElse: () => ThemePalette.classic,
      ),
      accent: AccentColor.values.firstWhere(
        (a) => a.name == map['accent'],
        orElse: () => AccentColor.indigo,
      ),
      textScale: (map['textScale'] as num?)?.toDouble() ?? 1.0,
      amoled: (map['amoled'] as bool?) ?? false,
      fontFamily: (map['fontFamily'] as String?) ?? 'System',
      alarmMode: (map['alarmMode'] as bool?) ?? true,
    );
  }
}
