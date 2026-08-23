import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/models/activity.dart';
import 'package:rappel_plus/services/today_widget_service.dart';

Activity act({
  required String name,
  required int hour,
  bool done = false,
  DateTime? start,
}) {
  final a = Activity.create(
    name: name,
    hour: hour,
    minute: 0,
    date: start ?? DateTime(2026, 8, 1),
    repeat: RepeatRule.daily,
  );
  return done ? a.withCompletedDay(DateTime(2026, 8, 23), true) : a;
}

void main() {
  test('lignes du widget : en attente d\'abord, terminées ensuite', () {
    final rows = buildWidgetRows([
      act(name: 'Déjà fait', hour: 7, done: true),
      act(name: 'Sport', hour: 9),
      act(name: 'Pilule', hour: 6),
    ], DateTime(2026, 8, 23, 12));

    expect(rows.map((r) => r.title).toList(), ['Pilule', 'Sport', 'Déjà fait'],
        reason: 'tri par heure puis terminées à la fin');
    expect(rows.first.done, isFalse);
    expect(rows.last.done, isTrue);
    expect(rows.last.timeLabel.endsWith('✓'), isTrue);
  });

  test('limite à max lignes et format heure paddé', () {
    final rows = buildWidgetRows(
      [
        for (var h = 1; h <= 8; h++) act(name: 'A$h', hour: h),
      ],
      DateTime(2026, 8, 23, 12),
      max: 5,
    );
    expect(rows, hasLength(5));
    expect(rows.first.timeLabel, '01:00');
  });

  test('activité pas encore commencée : liste vide', () {
    final rows = buildWidgetRows(
      [act(name: 'Futur', hour: 8, start: DateTime(2026, 9, 1))],
      DateTime(2026, 8, 23, 12),
    );
    // La répétition quotidienne ne commence qu'au 1er septembre.
    expect(rows, isEmpty);
  });

  test('prochaine activité = première non terminée', () {
    final next = buildNextRow([
      act(name: 'Déjà fait', hour: 7, done: true),
      act(name: 'Sport', hour: 9),
      act(name: 'Pilule', hour: 6),
    ], DateTime(2026, 8, 23, 12));
    expect(next?.title, 'Pilule');
    expect(next?.timeLabel, '06:00');
  });

  test('prochaine activité : null quand tout est fait', () {
    final next = buildNextRow(
      [act(name: 'Fait', hour: 7, done: true)],
      DateTime(2026, 8, 23, 12),
    );
    expect(next, isNull);
  });

  test('modèle semaine : 7 jours lun→dim avec compteurs', () {
    final week = buildWeekModel(
      activities: [act(name: 'Quotidien', hour: 8)],
      today: DateTime(2026, 8, 23), // dimanche
      letters: const ['L', 'M', 'M', 'J', 'V', 'S', 'D'],
    );
    expect(week, hasLength(7));
    expect(week.first.letter, 'L');
    expect(week.last.letter, 'D');
    expect(week.last.dayNumber, 23);
    expect(week.every((d) => d.due == 1 && d.done == 0), isTrue,
        reason: 'quotidienne due chaque jour, rien de coché');
    expect(week.every((d) => d.fraction == 0), isTrue);
  });
}
