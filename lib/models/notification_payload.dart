import 'dart:convert';

import '../models/activity.dart';

/// Payload JSON embarqué dans chaque notification.
///
/// Une action rapide est traitée par un isolate d'arrière-plan (Android) qui
/// n'a accès ni au stockage Hive ni aux réglages : tout ce dont il a besoin
/// (activité, occurrence, son, répertoire du journal, fuseau horaire, langue,
/// mode alarme) est donc sérialisé dans ce payload au moment de la
/// planification. Sans `alarmMode`, les reports (snoozes) replanifiés par
/// l'isolate retomberaient toujours en mode alarme (« FLAG_INSISTENT »).
class NotificationPayload {
  const NotificationPayload({
    required this.activityId,
    required this.name,
    required this.sound,
    required this.hour,
    required this.minute,
    required this.date,
    required this.repeat,
    required this.weekdays,
    required this.occurrence,
    required this.notificationId,
    this.journalDir = '',
    this.timezone = 'UTC',
    this.locale = 'fr',
    this.alarmMode = false,
  });

  final String activityId;
  final String name;
  final String sound;
  final int hour;
  final int minute;
  final DateTime date;
  final RepeatRule repeat;
  final List<int> weekdays;

  /// Jour calendaire de l'occurrence, au format `yyyy-MM-dd`.
  final String occurrence;
  final int notificationId;

  /// Répertoire contenant le journal des actions rapides.
  final String journalDir;
  final String timezone;
  final String locale;

  /// `true` si la notification initiale était en mode alarme (son insistant).
  /// Conservé pour que les reports (+5, +10, +30 min, Demain) respectent le
  /// réglage de l'utilisateur au lieu de repartir en alarme par défaut.
  final bool alarmMode;

  /// Construit le payload d'une notification planifiée pour [occurrence]
  /// (voir [Activity.dateKey]).
  factory NotificationPayload.fromActivity(
    Activity activity, {
    required String occurrence,
    required int notificationId,
    required String journalDir,
    required String timezone,
    String locale = 'fr',
    bool alarmMode = false,
  }) {
    return NotificationPayload(
      activityId: activity.id,
      name: activity.name,
      sound: activity.sound,
      hour: activity.hour,
      minute: activity.minute,
      date: activity.date,
      repeat: activity.repeat,
      weekdays: activity.weekdays,
      occurrence: occurrence,
      notificationId: notificationId,
      journalDir: journalDir,
      timezone: timezone,
      locale: locale,
      alarmMode: alarmMode,
    );
  }

  NotificationPayload copyWith({
    String? occurrence,
    int? notificationId,
    String? journalDir,
  }) {
    return NotificationPayload(
      activityId: activityId,
      name: name,
      sound: sound,
      hour: hour,
      minute: minute,
      date: date,
      repeat: repeat,
      weekdays: weekdays,
      occurrence: occurrence ?? this.occurrence,
      notificationId: notificationId ?? this.notificationId,
      journalDir: journalDir ?? this.journalDir,
      timezone: timezone,
      locale: locale,
      alarmMode: alarmMode,
    );
  }

  String encode() => jsonEncode({
        'activityId': activityId,
        'name': name,
        'sound': sound,
        'hour': hour,
        'minute': minute,
        'date': date.toIso8601String(),
        'repeat': repeat.name,
        'weekdays': weekdays,
        'occurrence': occurrence,
        'notificationId': notificationId,
        'journalDir': journalDir,
        'timezone': timezone,
        'locale': locale,
        'alarmMode': alarmMode,
      });

  static NotificationPayload? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return NotificationPayload(
        activityId: m['activityId'] as String,
        name: (m['name'] as String?) ?? '',
        sound: (m['sound'] as String?) ?? 'default',
        hour: (m['hour'] as int?) ?? 0,
        minute: (m['minute'] as int?) ?? 0,
        date:
            DateTime.tryParse((m['date'] as String?) ?? '') ?? DateTime.now(),
        repeat: RepeatRuleX.fromName(m['repeat'] as String?),
        weekdays: ((m['weekdays'] as List?) ?? const [])
            .whereType<int>()
            .toList(),
        occurrence: (m['occurrence'] as String?) ?? '',
        notificationId: (m['notificationId'] as int?) ?? 0,
        journalDir: (m['journalDir'] as String?) ?? '',
        timezone: (m['timezone'] as String?) ?? 'UTC',
        locale: (m['locale'] as String?) ?? 'fr',
        alarmMode: (m['alarmMode'] as bool?) ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  /// Reconstruit une [Activity] fidèle pour le calcul du plan d'action dans
  /// l'isolate d'arrière-plan (sans accès au stockage).
  Activity toActivity() {
    return Activity(
      id: activityId,
      name: name,
      hour: hour,
      minute: minute,
      date: date,
      repeat: repeat,
      weekdays: weekdays,
      sound: sound,
      notificationId: notificationId,
    );
  }
}
