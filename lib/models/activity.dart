import 'package:uuid/uuid.dart';

enum RepeatRule { none, daily, weekly, monthly }

extension RepeatRuleX on RepeatRule {
  static RepeatRule fromName(String? name) {
    return RepeatRule.values.firstWhere(
      (r) => r.name == name,
      orElse: () => RepeatRule.none,
    );
  }
}

class Activity {
  Activity({
    required this.id,
    required this.name,
    required this.hour,
    required this.minute,
    required this.date,
    this.repeat = RepeatRule.none,
    this.weekdays = const [],
    this.sound = 'default',
    this.enabled = true,
    List<String>? completedDays,
    required this.notificationId,
  }) : completedDays = completedDays ?? [];

  final String id;
  final String name;
  final int hour;
  final int minute;
  final DateTime date;
  final RepeatRule repeat;

  /// Jours de la semaine sélectionnés (1 = lundi … 7 = dimanche),
  /// utilisés quand [repeat] == [RepeatRule.weekly].
  final List<int> weekdays;

  /// Identifiant du son de notification (voir [SoundOption]).
  final String sound;

  /// `false` coupe les rappels sans supprimer l'activité.
  final bool enabled;

  final List<String> completedDays;
  final int notificationId;

  static const _uuid = Uuid();

  factory Activity.create({
    required String name,
    required int hour,
    required int minute,
    required DateTime date,
    RepeatRule repeat = RepeatRule.none,
    List<int> weekdays = const [],
    String sound = 'default',
    bool enabled = true,
    int? notificationId,
  }) {
    return Activity(
      id: _uuid.v4(),
      name: name,
      hour: hour,
      minute: minute,
      date: DateTime(date.year, date.month, date.day),
      repeat: repeat,
      weekdays: weekdays,
      sound: sound,
      enabled: enabled,
      notificationId: notificationId ?? newNotificationId(),
    );
  }

  /// Identifiant de notification aléatoire dans l'espace 27 bits.
  /// Voir [NotificationService.allocateFreshId] pour une allocation
  /// garantie sans collision entre activités.
  static int newNotificationId() => _uuid.v4().hashCode & 0x07FFFFFF;

  bool get isCompletedToday => isCompletedOn(DateTime.now());

  bool isCompletedOn(DateTime day) =>
      completedDays.contains(dateKey(day));

  bool isDueOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    switch (repeat) {
      case RepeatRule.none:
        return dateKey(d) == dateKey(date);
      case RepeatRule.daily:
        return !d.isBefore(date);
      case RepeatRule.weekly:
        return weekdays.contains(d.weekday) && !d.isBefore(date);
      case RepeatRule.monthly:
        return d.day == date.day && !d.isBefore(date);
    }
  }

  Activity copyWith({
    String? name,
    int? hour,
    int? minute,
    DateTime? date,
    RepeatRule? repeat,
    List<int>? weekdays,
    String? sound,
    bool? enabled,
    List<String>? completedDays,
    int? notificationId,
  }) {
    return Activity(
      id: id,
      name: name ?? this.name,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      date: date ?? this.date,
      repeat: repeat ?? this.repeat,
      weekdays: weekdays ?? this.weekdays,
      sound: sound ?? this.sound,
      enabled: enabled ?? this.enabled,
      completedDays: completedDays ?? this.completedDays,
      notificationId: notificationId ?? this.notificationId,
    );
  }

  Activity withCompletedDay(DateTime day, bool completed) {
    final key = dateKey(day);
    final set = {...completedDays};
    if (completed) {
      set.add(key);
    } else {
      set.remove(key);
    }
    return Activity(
      id: id,
      name: name,
      hour: hour,
      minute: minute,
      date: date,
      repeat: repeat,
      weekdays: weekdays,
      sound: sound,
      enabled: enabled,
      completedDays: set.toList()..sort(),
      notificationId: notificationId,
    );
  }

  static String dateKey(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static DateTime parseDateKey(String key) {
    final parts = key.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'hour': hour,
        'minute': minute,
        'date': dateKey(date),
        'repeat': repeat.name,
        'weekdays': weekdays,
        'sound': sound,
        'enabled': enabled,
        'completedDays': completedDays,
        'notificationId': notificationId,
      };

  factory Activity.fromMap(Map<String, dynamic> map) => Activity(
        id: map['id'] as String,
        name: map['name'] as String,
        hour: map['hour'] as int,
        minute: map['minute'] as int,
        date: parseDateKey(map['date'] as String),
        repeat: RepeatRuleX.fromName(map['repeat'] as String?),
        weekdays: (map['weekdays'] as List?)?.cast<int>() ?? const [],
        sound: (map['sound'] as String?) ?? 'default',
        enabled: (map['enabled'] as bool?) ?? true,
        completedDays: (map['completedDays'] as List?)?.cast<String>() ?? [],
        notificationId: map['notificationId'] as int,
      );
}
