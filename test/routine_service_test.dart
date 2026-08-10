import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/models/activity.dart';
import 'package:rappel_plus/models/routine.dart';
import 'package:rappel_plus/services/notification_service.dart';
import 'package:rappel_plus/services/routine_service.dart';
import 'package:rappel_plus/services/stats_service.dart';

void main() {
  final today = DateTime(2026, 8, 12);

  RoutineActivityDraft draft(
    String name, {
    int hour = 8,
    int minute = 0,
    RepeatRule repeat = RepeatRule.daily,
    List<int> weekdays = const [],
    String sound = 'default',
  }) =>
      RoutineActivityDraft(
        name: name,
        hour: hour,
        minute: minute,
        repeat: repeat,
        weekdays: weekdays,
        sound: sound,
        date: today,
      );

  group('RoutineService.buildActivities', () {
    test('un seul brouillon produit une activité complète', () {
      final activities = RoutineService.buildActivities(
        [draft('Réveil', hour: 7, minute: 30)],
        usedIds: const {},
        now: today,
      );
      expect(activities, hasLength(1));
      final a = activities.first;
      expect(a.name, 'Réveil');
      expect(a.hour, 7);
      expect(a.minute, 30);
      expect(a.repeat, RepeatRule.daily);
      expect(a.enabled, isTrue);
      expect(a.notificationId, isA<int>());
    });

    test('plusieurs brouillons : identifiants d\'activités et de '
        'notifications distincts', () {
      final activities = RoutineService.buildActivities(
        [
          draft('A'),
          draft('B'),
          draft('C'),
        ],
        usedIds: const {},
        now: today,
      );
      expect(activities, hasLength(3));
      final ids = activities.map((a) => a.id).toSet();
      expect(ids.length, 3, reason: 'chaque activité a un identifiant unique');
      final notifIds = activities.map((a) => a.notificationId).toSet();
      expect(notifIds.length, 3,
          reason: 'chaque activité a un notificationId unique');
    });

    test('les brouillons hebdomadaires ne partagent pas leurs dérivés',
        () {
      final activities = RoutineService.buildActivities(
        [
          draft('Lun', repeat: RepeatRule.weekly, weekdays: [DateTime.monday]),
          draft('Mar', repeat: RepeatRule.weekly, weekdays: [DateTime.tuesday]),
        ],
        usedIds: const {},
        now: today,
      );
      expect(activities.map((a) => a.notificationId).toSet().length, 2);
    });

    test('les identifiants alloués évitent ceux déjà utilisés', () {
      final existing = RoutineService.buildActivities(
        [draft('Existant')],
        usedIds: const {},
        now: today,
      );
      final used = NotificationService.usedNotificationIds(existing);
      final fresh = RoutineService.buildActivities(
        [draft('Nouveau')],
        usedIds: used,
        now: today,
      );
      expect(fresh.single.notificationId, isNot(existing.single.notificationId));
      expect(used.contains(fresh.single.notificationId), isFalse);
    });

    test('enabled=false produit des activités désactivées', () {
      final activities = RoutineService.buildActivities(
        [draft('A')],
        usedIds: const {},
        enabled: false,
        now: today,
      );
      expect(activities.single.enabled, isFalse);
    });

    test('un brouillon sans date part d\'aujourd\'hui', () {
      final activities = RoutineService.buildActivities(
        [
          RoutineActivityDraft(
            name: 'Sans date',
            hour: 9,
            minute: 0,
            sound: 'default',
          ),
        ],
        usedIds: const {},
        now: today,
      );
      expect(activities.single.date, today);
    });
  });

  group('RoutineService + StatsCalculator', () {
    test('les activités d\'une routine comptent dans les statistiques', () {
      final activities = RoutineService.buildActivities(
        [draft('Routine', hour: 7, minute: 0)],
        usedIds: const {},
        now: today.subtract(const Duration(days: 2)),
      );
      final done = activities.first.withCompletedDay(today, true);
      final stats = StatsCalculator.compute([done], today);
      expect(stats.hasRoutine, isTrue);
      expect(stats.weekDone, 1);
      expect(stats.last7Days.last.status, DayStatus.respected);
    });
  });
}
