import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/models/activity.dart';
import 'package:rappel_plus/services/stats_service.dart';

void main() {
  // Mercredi 12 août 2026.
  final today = DateTime(2026, 8, 12);

  Activity daily(DateTime start) => Activity.create(
        name: 'Daily',
        hour: 9,
        minute: 0,
        date: start,
        repeat: RepeatRule.daily,
      );

  group('StatsCalculator : cas vide', () {
    test('sans activité, la routine n\'existe pas', () {
      final stats = StatsCalculator.compute([], today);
      expect(stats.hasRoutine, isFalse);
      expect(stats.currentStreak, 0);
      expect(stats.bestStreak, 0);
      expect(stats.weekDone, 0);
      expect(stats.weekDue, 0);
      expect(stats.monthDone, 0);
      expect(stats.monthDue, 0);
      expect(stats.last7Days, isEmpty);
      expect(stats.monthDays, isEmpty);
      expect(stats.history, isEmpty);
      expect(stats.weekRate, isNull);
    });
  });

  group('StatsCalculator : statuts des journées', () {
    test('journée entièrement cochée = respected', () {
      final a = daily(today.subtract(const Duration(days: 2)));
      final done = a.withCompletedDay(today, true);
      final stats = StatsCalculator.compute([done], today);
      expect(stats.last7Days.last.status, DayStatus.respected);
    });

    test('journée due et non cochée = missed', () {
      final a = daily(today.subtract(const Duration(days: 2)));
      final stats = StatsCalculator.compute([a], today);
      expect(stats.last7Days.last.status, DayStatus.missed);
    });

    test('journée sans activité prévue = neutral', () {
      // Activité uniquement le lundi.
      final a = Activity.create(
        name: 'Hebdo',
        hour: 9,
        minute: 0,
        date: DateTime(2026, 8, 10),
        repeat: RepeatRule.weekly,
        weekdays: [DateTime.monday],
      );
      final stats = StatsCalculator.compute([a], today); // mercredi
      final tuesday = stats.last7Days
          .firstWhere((d) => d.day.day == 11);
      expect(tuesday.status, DayStatus.neutral);
      expect(tuesday.due, 0);
    });
  });

  group('StatsCalculator : taux de réussite (occurrences)', () {
    test('semaine : terminées / prévues, jours neutres exclus', () {
      // Activité tous les jours depuis lundi ; cochée lundi et mardi.
      final a = daily(DateTime(2026, 8, 10))
          .withCompletedDay(DateTime(2026, 8, 10), true)
          .withCompletedDay(DateTime(2026, 8, 11), true);
      final stats = StatsCalculator.compute([a], today);
      expect(stats.weekDue, 3); // lundi, mardi, mercredi
      expect(stats.weekDone, 2);
      expect(stats.weekRate, closeTo(2 / 3, 0.001));
    });

    test('mois : cumul des occurrences du mois courant', () {
      final a = daily(DateTime(2026, 8, 10))
          .withCompletedDay(DateTime(2026, 8, 10), true)
          .withCompletedDay(DateTime(2026, 8, 11), true);
      final stats = StatsCalculator.compute([a], today);
      expect(stats.monthDue, 3);
      expect(stats.monthDone, 2);
      expect(stats.monthRate, closeTo(2 / 3, 0.001));
    });

    test('une journée partielle = partial', () {
      final a = daily(DateTime(2026, 8, 10));
      final b = daily(DateTime(2026, 8, 10))
          .withCompletedDay(DateTime(2026, 8, 12), true);
      final stats = StatsCalculator.compute([a, b], today);
      expect(stats.last7Days.last.status, DayStatus.partial);
      expect(stats.last7Days.last.done, 1);
      expect(stats.last7Days.last.due, 2);
    });
  });

  group('StatsCalculator : séries', () {
    test('série actuelle : 2 jours respectés (lundi, mardi)', () {
      final a = daily(DateTime(2026, 8, 10))
          .withCompletedDay(DateTime(2026, 8, 10), true)
          .withCompletedDay(DateTime(2026, 8, 11), true);
      final stats = StatsCalculator.compute([a], today);
      expect(stats.currentStreak, 2);
      expect(stats.bestStreak, 2);
    });

    test('aujourd\'hui non terminée ne casse pas la série', () {
      // Même situation que ci-dessus : la série compte jusqu'à hier.
      final a = daily(DateTime(2026, 8, 10))
          .withCompletedDay(DateTime(2026, 8, 10), true)
          .withCompletedDay(DateTime(2026, 8, 11), true);
      final stats = StatsCalculator.compute([a], today);
      expect(stats.currentStreak, 2,
          reason: 'une journée en cours ne doit pas casser la série');
    });

    test('une journée manquée casse la série', () {
      final a = daily(DateTime(2026, 8, 9))
          .withCompletedDay(DateTime(2026, 8, 9), true)
          .withCompletedDay(DateTime(2026, 8, 10), true)
          .withCompletedDay(DateTime(2026, 8, 12), true); // mardi manqué
      final stats = StatsCalculator.compute([a], today);
      expect(stats.currentStreak, 1);
    });

    test('les journées neutres ne cassent pas la série', () {
      // Activité uniquement lundi et mercredi, toutes deux cochées.
      final a = Activity.create(
        name: 'Hebdo',
        hour: 9,
        minute: 0,
        date: DateTime(2026, 8, 10),
        repeat: RepeatRule.weekly,
        weekdays: [DateTime.monday, DateTime.wednesday],
      )
          .withCompletedDay(DateTime(2026, 8, 10), true)
          .withCompletedDay(DateTime(2026, 8, 12), true);
      final stats = StatsCalculator.compute([a], today);
      expect(stats.currentStreak, 2,
          reason: 'les jours hors routine sont ignorés, pas comptés comme manqués');
    });

    test('meilleure série : le record est conservé après une coupure', () {
      final a = daily(DateTime(2026, 8, 5))
          .withCompletedDay(DateTime(2026, 8, 5), true)
          .withCompletedDay(DateTime(2026, 8, 6), true)
          .withCompletedDay(DateTime(2026, 8, 7), true)
          .withCompletedDay(DateTime(2026, 8, 8), true)
          .withCompletedDay(DateTime(2026, 8, 10), true)
          .withCompletedDay(DateTime(2026, 8, 11), true);
      final stats = StatsCalculator.compute([a], today);
      expect(stats.currentStreak, 2);
      expect(stats.bestStreak, 4);
    });
  });

  group('StatsCalculator : listes de journées', () {
    test('last7Days : 7 jours, du plus ancien au plus récent', () {
      final a = daily(DateTime(2026, 8, 10));
      final stats = StatsCalculator.compute([a], today);
      expect(stats.last7Days.length, 7);
      expect(stats.last7Days.first.day, DateTime(2026, 8, 6));
      expect(stats.last7Days.last.day, today);
    });

    test('monthDays : tous les jours du mois courant jusqu\'à aujourd\'hui',
        () {
      final a = daily(DateTime(2026, 8, 10));
      final stats = StatsCalculator.compute([a], today);
      expect(stats.monthDays.length, 12);
      expect(stats.monthDays.first.day, DateTime(2026, 8, 1));
      expect(stats.monthDays.last.day, today);
    });

    test('history : 14 journées au maximum, la plus récente en premier', () {
      final a = daily(DateTime(2026, 7, 20));
      final stats = StatsCalculator.compute([a], today);
      expect(stats.history.length, 14);
      expect(stats.history.first.day, today);
      expect(stats.history.last.day, DateTime(2026, 7, 30));
    });

    test('dayKey : stable et réutilisable par la grille mensuelle', () {
      expect(Activity.dateKey(DateTime(2026, 8, 12)), '2026-08-12');
      expect(Activity.dateKey(DateTime(2026, 12, 1)), '2026-12-01');
    });
  });
}
