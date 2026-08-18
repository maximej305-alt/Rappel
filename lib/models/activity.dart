import 'package:uuid/uuid.dart';

import '../services/clock_service.dart';
import 'activity_priority.dart';
import 'category.dart';

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
    this.priority = Priority.normal,
    this.categoryId = CategoryPresets.otherId,
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

  /// Priorité de l'activité (tie-break de tri après l'heure).
  final Priority priority;

  /// Identifiant de la catégorie (voir [Category]). Retombe sur
  /// [CategoryPresets.otherId] si la catégorie n'existe plus.
  final String categoryId;

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
    Priority priority = Priority.normal,
    String categoryId = CategoryPresets.otherId,
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
      priority: priority,
      categoryId: categoryId,
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
        // Cohérent avec la planification : une activité au 31 sonne le
        // dernier jour des mois courts (28/29/30) puis revient au 31. Sans
        // ce clamp, les mois de 28-30 jours ne marqueraient jamais l'activité
        // comme due alors que la notification a sonné.
        final lastDay = DateTime(d.year, d.month + 1, 0).day;
        final expected = date.day > lastDay ? lastDay : date.day;
        return d.day == expected && !d.isBefore(date);
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
    Priority? priority,
    String? categoryId,
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
      priority: priority ?? this.priority,
      categoryId: categoryId ?? this.categoryId,
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
      priority: priority,
      categoryId: categoryId,
      completedDays: set.toList()..sort(),
      notificationId: notificationId,
    );
  }

  /// Clé stable `yyyy-MM-dd` du jour (source unique : `DayKey`).
  static String dateKey(DateTime day) => DayKey.key(day);

  /// Décode une clé de jour, ou `null` si elle est malformée/inexistante.
  /// Appelés sur des données du journal (potentiellement corrompues), les
  /// appelants doivent gérer `null` pour ne pas faire crasher le démarrage.
  static DateTime? parseDateKey(String key) => DayKey.tryDate(key);

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
        'priority': priority.name,
        'categoryId': categoryId,
        'completedDays': completedDays,
        'notificationId': notificationId,
      };

  /// Restaure une activité depuis une carte stockée. Parsing défensif : une
  /// valeur manquante ou mal typée retombe sur un défaut sûr plutôt que de
  /// lever (une seule entrée corrompue ne doit pas bloquer le démarrage).
  factory Activity.fromMap(Map<String, dynamic> map) {
    final id = _asString(map['id']);
    final name = _asString(map['name']);
    final date = _asDate(map['date']);
    if (id == null || name == null || date == null) {
      throw const FormatException('Activité stockée invalide');
    }
    return Activity(
      id: id,
      name: name,
      hour: _asInt(map['hour']) ?? 0,
      minute: _asInt(map['minute']) ?? 0,
      date: date,
      repeat: RepeatRuleX.fromName(_asString(map['repeat'])),
      weekdays: _asIntList(map['weekdays']) ?? const [],
      sound: _asString(map['sound']) ?? 'default',
      enabled: _asBool(map['enabled']) ?? true,
      priority: PriorityX.fromName(_asString(map['priority'])),
      categoryId: _asString(map['categoryId']) ?? CategoryPresets.otherId,
      completedDays: _asStringList(map['completedDays']) ?? const [],
      notificationId: _asInt(map['notificationId']) ?? 0,
    );
  }

  static String? _asString(Object? v) => v is String ? v : null;

  static int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

  static bool? _asBool(Object? v) => v is bool ? v : null;

  static DateTime? _asDate(Object? v) =>
      v is String ? DayKey.tryDate(v) : null;

  static List<String>? _asStringList(Object? v) =>
      v is List ? v.whereType<String>().toList() : null;

  static List<int>? _asIntList(Object? v) =>
      v is List ? v.whereType<int>().toList() : null;
}
