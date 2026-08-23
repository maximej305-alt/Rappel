import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/activity.dart';
import '../services/stats_service.dart';
import '../utils/activity_sort.dart';

/// Modèle pur d'une ligne du widget « Aujourd'hui » (testable sans plugin).
class WidgetRow {
  const WidgetRow({
    required this.id,
    required this.title,
    required this.timeLabel,
    required this.done,
  });

  final String id;
  final String title;
  final String timeLabel;
  final bool done;
}

/// Construit les lignes du widget « Aujourd'hui » : en attente d'abord,
/// puis terminées. Fonction pure, testable sans plateforme.
List<WidgetRow> buildWidgetRows(
  List<Activity> activities,
  DateTime today, {
  int max = 5,
}) {
  final due =
      activities.where((a) => a.isDueOn(today)).toList()..sort(compareActivities);
  String label(Activity a) =>
      '${a.hour.toString().padLeft(2, '0')}:${a.minute.toString().padLeft(2, '0')}';
  final pending = [
    for (final a in due.where((a) => !a.isCompletedOn(today)))
      WidgetRow(id: a.id, title: a.name, timeLabel: label(a), done: false),
  ];
  final finished = [
    for (final a in due.where((a) => a.isCompletedOn(today)))
      WidgetRow(
          id: a.id, title: a.name, timeLabel: '${label(a)} ✓', done: true),
  ];
  return [...pending, ...finished].take(max).toList();
}

/// Prochaine activité non terminée du jour (`null` si aucune).
WidgetRow? buildNextRow(List<Activity> activities, DateTime today) {
  final pending =
      buildWidgetRows(activities, today).where((r) => !r.done).toList();
  return pending.isEmpty ? null : pending.first;
}

/// Données de la semaine pour le widget hebdo (7 jours lun → dim).
class WeekDayModel {
  const WeekDayModel({
    required this.letter,
    required this.dayNumber,
    required this.due,
    required this.done,
  });

  final String letter;
  final int dayNumber;
  final int due;
  final int done;

  double get fraction => due == 0 ? 0 : done / due;
}

List<WeekDayModel> buildWeekModel({
  required List<Activity> activities,
  required DateTime today,
  required List<String> letters,
}) {
  final start = today.subtract(Duration(days: today.weekday - 1));
  return [
    for (var i = 0; i < 7; i++)
      () {
        final d = start.add(Duration(days: i));
        final due = activities.where((a) => a.isDueOn(d)).length;
        final done =
            activities.where((a) => a.isDueOn(d) && a.isCompletedOn(d)).length;
        return WeekDayModel(
          letter: i < letters.length ? letters[i] : '?',
          dayNumber: d.day,
          due: due,
          done: done,
        );
      }(),
  ];
}

/// Synchronisation de TOUS les widgets d'écran d'accueil.
///
/// Les activités vivent dans un Hive CHIFFRÉ illisible côté natif : chaque
/// widget reçoit sa copie en clair dans les SharedPreferences via
/// home_widget, et les providers Kotlin se contentent d'afficher.
abstract final class HomeWidgetSync {
  /// Noms des providers Android (classes Kotlin), mis à jour en bloc.
  static const _providers = [
    'TodayWidgetProvider',
    'NextActivityWidgetProvider',
    'ProgressWidgetProvider',
    'StreakWidgetProvider',
    'WeekWidgetProvider',
    'AddButtonWidgetProvider',
  ];

  static Timer? _debounce;
  static List<Activity> _latest = const [];
  static HabitStats? _latestStats;
  static List<String> _latestLetters = const [];

  /// Met à jour la source et planifie une écriture débouncée.
  static void updateSource(
    List<Activity> activities, {
    HabitStats? stats,
    List<String> letters = const [],
  }) {
    _latest = activities;
    if (stats != null) _latestStats = stats;
    if (letters.isNotEmpty) _latestLetters = letters;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _debounce = null;
      syncAll();
    });
  }

  /// Écrit toutes les données et rafraîchit tous les widgets.
  static Future<void> syncAll({DateTime? now}) async {
    try {
      final today = now ?? DateTime.now();
      final activities = _latest;
      final due = activities.where((a) => a.isDueOn(today)).toList();
      final doneCount = due.where((a) => a.isCompletedOn(today)).length;
      final rows = buildWidgetRows(activities, today);
      final next = buildNextRow(activities, today);
      final stats = _latestStats;
      final week = buildWeekModel(
        activities: activities,
        today: today,
        letters: _latestLetters,
      );

      // — Widget Aujourd'hui —
      await HomeWidget.saveWidgetData<int>('w_total', due.length);
      await HomeWidget.saveWidgetData<int>('w_done', doneCount);
      await HomeWidget.saveWidgetData<int>('w_rows', rows.length);
      for (var i = 0; i < 5; i++) {
        if (i < rows.length) {
          await HomeWidget.saveWidgetData<String>('w_title_$i', rows[i].title);
          await HomeWidget.saveWidgetData<String>(
              'w_time_$i', rows[i].timeLabel);
          await HomeWidget.saveWidgetData<bool>('w_done_$i', rows[i].done);
        } else {
          await HomeWidget.saveWidgetData<String>('w_title_$i', null);
          await HomeWidget.saveWidgetData<String>('w_time_$i', null);
          await HomeWidget.saveWidgetData<bool>('w_done_$i', null);
        }
      }

      // — Prochaine activité —
      await HomeWidget.saveWidgetData<bool>('n_has', next != null);
      await HomeWidget.saveWidgetData<String>('n_title', next?.title);
      await HomeWidget.saveWidgetData<String>('n_time', next?.timeLabel);

      // — Série (stats) —
      await HomeWidget.saveWidgetData<bool>('s_has', stats?.hasRoutine ?? false);
      await HomeWidget.saveWidgetData<int>(
          's_current', stats?.currentStreak ?? 0);
      await HomeWidget.saveWidgetData<int>('s_best', stats?.bestStreak ?? 0);

      // — Semaine —
      for (var i = 0; i < 7; i++) {
        await HomeWidget.saveWidgetData<String>(
            'd_letter_$i', week[i].letter);
        await HomeWidget.saveWidgetData<int>('d_day_$i', week[i].dayNumber);
        await HomeWidget.saveWidgetData<int>('d_due_$i', week[i].due);
        await HomeWidget.saveWidgetData<int>('d_done_$i', week[i].done);
      }

      for (final p in _providers) {
        await HomeWidget.updateWidget(name: p);
      }
    } catch (e) {
      debugPrint('[Widget] synchronisation impossible : $e');
    }
  }
}
