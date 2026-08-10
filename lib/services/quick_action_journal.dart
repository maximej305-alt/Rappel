import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/activity.dart';
import '../models/snooze_action.dart';

/// Ticket « Terminé » écrit par l'isolate d'arrière-plan.
///
/// L'application ne tournant pas quand l'action est touchée, le marquage est
/// différé puis appliqué au prochain démarrage (voir
/// [NotificationService.applyQueuedCompletion]).
class PendingAction {
  const PendingAction({
    required this.activityId,
    required this.occurrence,
    required this.action,
  });

  final String activityId;

  /// Jour calendaire de l'occurrence (format `yyyy-MM-dd`).
  final String occurrence;
  final QuickAction action;

  Map<String, dynamic> toJson() => {
        'activityId': activityId,
        'occurrence': occurrence,
        'action': action.id,
      };

  static PendingAction? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final action = QuickAction.fromId(raw['action'] as String?);
    final activityId = raw['activityId'] as String?;
    final occurrence = raw['occurrence'] as String?;
    if (action == null || activityId == null || occurrence == null) {
      return null;
    }
    return PendingAction(
      activityId: activityId,
      occurrence: occurrence,
      action: action,
    );
  }
}

/// Notification ponctuelle « report » en vol (snooze / demain).
class SnoozeEntry {
  const SnoozeEntry({
    required this.activityId,
    required this.occurrence,
    required this.fireAt,
  });

  final String activityId;
  final String occurrence;
  final DateTime fireAt;

  Map<String, dynamic> toJson() => {
        'activityId': activityId,
        'occurrence': occurrence,
        'fireAt': fireAt.toIso8601String(),
      };

  static SnoozeEntry? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final activityId = raw['activityId'] as String?;
    final occurrence = raw['occurrence'] as String?;
    final fireAt = DateTime.tryParse((raw['fireAt'] as String?) ?? '');
    if (activityId == null || occurrence == null || fireAt == null) {
      return null;
    }
    return SnoozeEntry(
      activityId: activityId,
      occurrence: occurrence,
      fireAt: fireAt,
    );
  }
}

/// Journal persistant des actions rapides.
///
/// Modèle immuable : chaque opération retourne une nouvelle instance.
/// Stocké en JSON simple (pas de Hive) pour rester lisible par l'isolate
/// d'arrière-plan Android.
class QuickActionJournal {
  const QuickActionJournal({
    this.pending = const [],
    this.snoozes = const [],
  });

  final List<PendingAction> pending;
  final List<SnoozeEntry> snoozes;

  bool get isEmpty => pending.isEmpty && snoozes.isEmpty;

  /// Identifiant de notification déterministe d'un report
  /// (`(activité, occurrence)`), stable entre appels et isolates.
  /// Permet de remplacer ou d'annuler un report sans le stocker.
  static int deferIdFor(String activityId, String occurrence) {
    final digest = sha1.convert(utf8.encode('defer:$activityId:$occurrence'));
    final bytes = digest.bytes;
    var value = 0;
    for (var i = 0; i < 4; i++) {
      value = (value << 8) | bytes[i];
    }
    return value & 0x7FFFFFFF;
  }

  bool containsPending(String activityId, String occurrence, QuickAction action) {
    return pending.any((p) =>
        p.activityId == activityId &&
        p.occurrence == occurrence &&
        p.action == action);
  }

  QuickActionJournal addPending(PendingAction entry) {
    if (containsPending(entry.activityId, entry.occurrence, entry.action)) {
      return this;
    }
    return QuickActionJournal(
      pending: [...pending, entry],
      snoozes: snoozes,
    );
  }

  QuickActionJournal addSnooze(SnoozeEntry entry) {
    if (snoozes.any((s) =>
        s.activityId == entry.activityId && s.occurrence == entry.occurrence)) {
      return removeSnooze(entry.activityId, entry.occurrence).addSnooze(entry);
    }
    return QuickActionJournal(
      pending: pending,
      snoozes: [...snoozes, entry],
    );
  }

  /// Retire tous les tickets « Terminé » d'une occurrence.
  QuickActionJournal removePending(String activityId, String occurrence) {
    return QuickActionJournal(
      pending: pending
          .where((p) => p.activityId != activityId || p.occurrence != occurrence)
          .toList(),
      snoozes: snoozes,
    );
  }

  /// Retire le report d'une occurrence, s'il existe.
  QuickActionJournal removeSnooze(String activityId, String occurrence) {
    return QuickActionJournal(
      pending: pending,
      snoozes: snoozes
          .where((s) => s.activityId != activityId || s.occurrence != occurrence)
          .toList(),
    );
  }

  /// Purge les reports déjà échus (le journal ne garde que du futur).
  QuickActionJournal prune(DateTime now) {
    return QuickActionJournal(
      pending: pending,
      snoozes: snoozes.where((s) => s.fireAt.isAfter(now)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'pending': pending.map((p) => p.toJson()).toList(),
        'snoozes': snoozes.map((s) => s.toJson()).toList(),
      };

  static QuickActionJournal fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return const QuickActionJournal();
    return QuickActionJournal(
      pending: (raw['pending'] as List? ?? const [])
          .map(PendingAction.fromJson)
          .whereType<PendingAction>()
          .toList(),
      snoozes: (raw['snoozes'] as List? ?? const [])
          .map(SnoozeEntry.fromJson)
          .whereType<SnoozeEntry>()
          .toList(),
    );
  }
}

/// Lecture / écriture du journal sur disque.
abstract final class QuickActionJournalStore {
  static const _fileName = 'quick_action_journal.json';

  static Future<QuickActionJournal> load(String journalDir) async {
    if (journalDir.isEmpty) return const QuickActionJournal();
    final file = File('$journalDir/$_fileName');
    try {
      if (!await file.exists()) return const QuickActionJournal();
      return QuickActionJournal.fromJson(jsonDecode(await file.readAsString()));
    } catch (_) {
      return const QuickActionJournal();
    }
  }

  static Future<void> save(String journalDir, QuickActionJournal journal) async {
    if (journalDir.isEmpty) return;
    final file = File('$journalDir/$_fileName');
    await file.writeAsString(jsonEncode(journal.toJson()));
  }
}

/// Résultat du calcul d'un plan d'action.
sealed class QuickActionPlan {
  const QuickActionPlan();
}

/// Marquer l'occurrence comme terminée.
class DonePlan extends QuickActionPlan {
  const DonePlan();
}

/// Reporter l'occurrence à [fireAt] par une notification ponctuelle.
class DeferPlan extends QuickActionPlan {
  const DeferPlan(this.fireAt, {this.coveredByRule = false});

  final DateTime fireAt;

  /// `true` quand la règle de répétition produira déjà une notification à
  /// [fireAt] : inutile (et même dupliqué) d'en planifier une supplémentaire.
  final bool coveredByRule;
}

/// Calcul pur des plans d'action — cœur testable, partagé entre l'application
/// et l'isolate d'arrière-plan.
abstract final class QuickActionPlanner {
  static QuickActionPlan plan({
    required Activity activity,
    required QuickAction action,
    required DateTime now,
  }) {
    switch (action) {
      case QuickAction.done:
        return const DonePlan();
      case QuickAction.snooze5:
      case QuickAction.snooze10:
      case QuickAction.snooze30:
        return DeferPlan(
          now.add(Duration(minutes: action.snoozeMinutes!)),
        );
      case QuickAction.tomorrow:
        final tomorrow = DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 1));
        final fireAt = DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          activity.hour,
          activity.minute,
        );
        return DeferPlan(
          fireAt,
          coveredByRule: ruleCovers(activity, tomorrow),
        );
    }
  }

  /// `true` si la règle de répétition de [activity] produira un rappel le
  /// jour [day] (utile pour décider si « Demain » doit planifier une
  /// notification ponctuelle ou compter sur la récurrence).
  static bool ruleCovers(Activity activity, DateTime day) {
    switch (activity.repeat) {
      case RepeatRule.none:
        return false;
      case RepeatRule.daily:
        return true;
      case RepeatRule.weekly:
        return activity.weekdays.contains(day.weekday);
      case RepeatRule.monthly:
        return day.day == activity.date.day;
    }
  }
}
