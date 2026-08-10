import 'package:uuid/uuid.dart';

import 'activity.dart';

/// Groupe logique d'activités.
///
/// Une routine ne stocke que des références ([activityIds]) vers la liste
/// globale des activités : celle-ci reste la seule source de vérité. Chaque
/// activité issue d'une routine garde ainsi son identité propre (id,
/// `notificationId`, horaire, répétition, état terminé), et la modifier ne
/// touche jamais aux autres activités de la routine.
class Routine {
  Routine({
    required this.id,
    required this.name,
    required this.icon,
    this.description,
    required this.activityIds,
    required this.createdAt,
    this.active = true,
  });

  final String id;
  final String name;

  /// Emoji court qui identifie visuellement la routine.
  final String icon;
  final String? description;

  /// Identifiants des activités de la liste globale regroupées ici.
  final List<String> activityIds;
  final DateTime createdAt;

  /// `false` met la routine en pause (ses rappels sont désactivés).
  final bool active;

  static const _uuid = Uuid();

  factory Routine.create({
    required String name,
    String icon = '📋',
    String? description,
    List<String> activityIds = const [],
  }) {
    return Routine(
      id: _uuid.v4(),
      name: name,
      icon: icon,
      description: description,
      activityIds: activityIds,
      createdAt: DateTime.now(),
    );
  }

  Routine copyWith({
    String? name,
    String? icon,
    String? description,
    List<String>? activityIds,
    bool? active,
  }) {
    return Routine(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      activityIds: activityIds ?? this.activityIds,
      createdAt: createdAt,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'icon': icon,
        'description': description,
        'activityIds': activityIds,
        'createdAt': createdAt.toIso8601String(),
        'active': active,
      };

  factory Routine.fromMap(Map<String, dynamic> map) => Routine(
        id: map['id'] as String,
        name: map['name'] as String,
        icon: (map['icon'] as String?) ?? '📋',
        description: map['description'] as String?,
        activityIds: (map['activityIds'] as List?)?.cast<String>() ?? const [],
        createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        active: (map['active'] as bool?) ?? true,
      );
}

/// Brouillon d'activité d'une routine, utilisé par l'éditeur avant la
/// création effective de l'activité dans la liste globale.
class RoutineActivityDraft {
  const RoutineActivityDraft({
    required this.name,
    required this.hour,
    required this.minute,
    this.repeat = RepeatRule.daily,
    this.weekdays = const [],
    this.sound = 'default',
    this.date,
  });

  final String name;
  final int hour;
  final int minute;
  final RepeatRule repeat;
  final List<int> weekdays;
  final String sound;

  /// Date de départ (une seule fois). `null` → aujourd'hui.
  final DateTime? date;
}
