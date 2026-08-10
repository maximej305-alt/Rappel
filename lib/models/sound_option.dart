import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// Catalogue des sons de notification proposés (comme dans une app d'alarme).
class SoundOption {
  const SoundOption({
    required this.id,
    required this.label,
    required this.icon,
    this.isAlarm = false,
  });

  final String id;
  final String label;
  final IconData icon;

  /// `true` pour le son d'alarme du téléphone (URI système).
  final bool isAlarm;

  static const List<SoundOption> all = [
    SoundOption(
      id: 'default',
      label: 'Son par défaut',
      icon: Icons.notifications_none,
    ),
    SoundOption(id: 'chime1', label: 'Carillon', icon: Icons.music_note),
    SoundOption(
      id: 'chime2',
      label: 'Arpège',
      icon: Icons.piano,
    ),
    SoundOption(id: 'beep', label: 'Bip', icon: Icons.graphic_eq),
    SoundOption(id: 'bell', label: 'Cloche', icon: Icons.notifications_active),
    SoundOption(id: 'whistle', label: 'Sifflet', icon: Icons.waves),
    SoundOption(
      id: 'alarm',
      label: 'Alarme du téléphone',
      icon: Icons.alarm,
      isAlarm: true,
    ),
  ];

  static SoundOption fromId(String? id) {
    if (id != null && id.startsWith('custom://')) {
      final raw = id.replaceFirst('custom://', '');
      final fileName =
          raw.contains('/') ? raw.split('/').last : raw;
      final label = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;
      return SoundOption(
        id: id,
        label: label,
        icon: Icons.audiotrack,
      );
    }
    return all.firstWhere(
      (s) => s.id == id,
      orElse: () => all.first,
    );
  }
}

/// Libellé localisé d'un son selon la langue active.
String soundLabel(SoundOption option, AppStrings s) => switch (option.id) {
      'default' => s.soundDefault,
      'chime1' => s.soundChime1,
      'chime2' => s.soundChime2,
      'beep' => s.soundBeep,
      'bell' => s.soundBell,
      'whistle' => s.soundWhistle,
      'alarm' => s.soundAlarm,
      _ => option.label,
    };
