import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/models/activity.dart';
import 'package:rappel_plus/models/activity_priority.dart';
import 'package:rappel_plus/utils/activity_sort.dart';

void main() {
  Activity act(
    String name, {
    int hour = 9,
    int minute = 0,
    DateTime? date,
    Priority priority = Priority.normal,
  }) =>
      Activity.create(
        name: name,
        hour: hour,
        minute: minute,
        date: date ?? DateTime(2026, 8, 10),
        priority: priority,
      );

  group('compareActivities', () {
    test('heure croissante d\'abord', () {
      final list = [act('10h', hour: 10), act('9h', hour: 9)];
      list.sort(compareActivities);
      expect(list.map((a) => a.name).toList(), ['9h', '10h']);
    });

    test('à heure égale, priorité décroissante (urgent > important > normal)',
        () {
      final list = [
        act('normal', priority: Priority.normal),
        act('urgent', priority: Priority.urgent),
        act('important', priority: Priority.important),
      ];
      list.sort(compareActivities);
      expect(
        list.map((a) => a.name).toList(),
        ['urgent', 'important', 'normal'],
      );
    });

    test('à heure et priorité égales, nom croissant (déterministe)', () {
      final list = [act('b'), act('a'), act('c')];
      list.sort(compareActivities);
      expect(list.map((a) => a.name).toList(), ['a', 'b', 'c']);
    });

    test('date antérieure avant date postérieure, même heure', () {
      final list = [
        act('post', date: DateTime(2026, 8, 11)),
        act('pre', date: DateTime(2026, 8, 10)),
      ];
      list.sort(compareActivities);
      expect(list.map((a) => a.name).toList(), ['pre', 'post']);
    });

    test('la priorité ne dépasse jamais l\'heure (chronologie d\'abord)', () {
      final list = [
        act('tard urgent', hour: 11, priority: Priority.urgent),
        act('tôt normal', hour: 8, priority: Priority.normal),
      ];
      list.sort(compareActivities);
      expect(list.map((a) => a.name).toList(), ['tôt normal', 'tard urgent']);
    });

    test('minute départage les activités de la même heure', () {
      final list = [
        act('30', hour: 8, minute: 30),
        act('00', hour: 8, minute: 0),
      ];
      list.sort(compareActivities);
      expect(list.map((a) => a.name).toList(), ['00', '30']);
    });
  });
}
