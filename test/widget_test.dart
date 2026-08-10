import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/models/activity.dart';

void main() {
  group('Activity', () {
    final monday = DateTime(2026, 8, 10); // un lundi

    test('activité quotidienne due tous les jours', () {
      final a = Activity.create(
        name: 'Réveil',
        hour: 5,
        minute: 0,
        date: DateTime(2026, 8, 10),
        repeat: RepeatRule.daily,
      );
      expect(a.isDueOn(DateTime(2026, 8, 10)), isTrue);
      expect(a.isDueOn(DateTime(2026, 8, 25)), isTrue);
      expect(a.isDueOn(DateTime(2026, 8, 9)), isFalse);
    });

    test('activité hebdomadaire due les jours choisis (lundi)', () {
      final a = Activity.create(
        name: 'Sport',
        hour: 18,
        minute: 0,
        date: monday,
        repeat: RepeatRule.weekly,
        weekdays: [DateTime.monday],
      );
      expect(a.isDueOn(DateTime(2026, 8, 17)), isTrue); // lundi suivant
      expect(a.isDueOn(DateTime(2026, 8, 18)), isFalse); // mardi
    });

    test('activité hebdomadaire avec plusieurs jours choisis', () {
      final a = Activity.create(
        name: 'Ménage',
        hour: 6,
        minute: 0,
        date: monday,
        repeat: RepeatRule.weekly,
        weekdays: [DateTime.monday, DateTime.thursday],
      );
      expect(a.isDueOn(DateTime(2026, 8, 13)), isTrue); // jeudi
      expect(a.isDueOn(DateTime(2026, 8, 16)), isFalse); // dimanche
    });

    test('activité mensuelle due le même jour du mois', () {
      final a = Activity.create(
        name: 'Loyer',
        hour: 9,
        minute: 0,
        date: DateTime(2026, 8, 15),
        repeat: RepeatRule.monthly,
      );
      expect(a.isDueOn(DateTime(2026, 9, 15)), isTrue);
      expect(a.isDueOn(DateTime(2026, 9, 16)), isFalse);
    });

    test('activité unique due à sa date uniquement', () {
      final a = Activity.create(
        name: 'Rendez-vous',
        hour: 10,
        minute: 30,
        date: DateTime(2026, 8, 20),
      );
      expect(a.isDueOn(DateTime(2026, 8, 20)), isTrue);
      expect(a.isDueOn(DateTime(2026, 8, 21)), isFalse);
    });

    test('cocher une activité comme terminée', () {
      final a = Activity.create(name: 'Ménage', hour: 6, minute: 0, date: monday);
      expect(a.isCompletedOn(monday), isFalse);
      final done = a.withCompletedDay(monday, true);
      expect(done.isCompletedOn(monday), isTrue);
      final undone = done.withCompletedDay(monday, false);
      expect(undone.isCompletedOn(monday), isFalse);
    });

    test('sérialisation / désérialisation', () {
      final a = Activity.create(
        name: 'Travailler',
        hour: 18,
        minute: 0,
        date: DateTime(2026, 8, 10),
        repeat: RepeatRule.daily,
      );
      final restored = Activity.fromMap(a.toMap());
      expect(restored.name, a.name);
      expect(restored.hour, a.hour);
      expect(restored.minute, a.minute);
      expect(restored.repeat, RepeatRule.daily);
      expect(restored.id, a.id);
      expect(restored.notificationId, a.notificationId);
    });
  });
}
