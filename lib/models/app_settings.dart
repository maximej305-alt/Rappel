import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale = 'fr',
    this.reminderOffsetMinutes = 0,
    this.defaultSound = 'default',
  });

  final ThemeMode themeMode;
  final String locale;
  final int reminderOffsetMinutes;
  final String defaultSound;

  static const List<int> reminderOptions = [0, 5, 10, 15, 30, 60];

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? locale,
    int? reminderOffsetMinutes,
    String? defaultSound,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      reminderOffsetMinutes:
          reminderOffsetMinutes ?? this.reminderOffsetMinutes,
      defaultSound: defaultSound ?? this.defaultSound,
    );
  }

  Map<String, dynamic> toMap() => {
        'themeMode': themeMode.name,
        'locale': locale,
        'reminderOffsetMinutes': reminderOffsetMinutes,
        'defaultSound': defaultSound,
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
    );
  }
}
