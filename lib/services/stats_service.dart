import '../models/activity.dart';

/// Statut d'une journée pour l'ensemble de la routine.
enum DayStatus {
  /// Aucune activité prévue ce jour-là : journée hors routine.
  neutral,

  /// Toutes les activités prévues ont été terminées.
  respected,

  /// Une partie seulement des activités prévues a été terminée.
  partial,

  /// Aucune des activités prévues n'a été terminée.
  missed,
}

/// Résultat d'une journée : statut + compteurs d'occurrences.
class DayStat {
  const DayStat({
    required this.day,
    required this.status,
    required this.due,
    required this.done,
  });

  final DateTime day;
  final DayStatus status;

  /// Occurrences prévues (activités dues ce jour-là).
  final int due;

  /// Occurrences terminées.
  final int done;

  /// Taux de réussite du jour (0 si aucune occurrence prévue).
  double get rate => due == 0 ? 0 : done / due;

  /// Clé de journée (même format que [Activity.dateKey]).
  String get dayKey => Activity.dateKey(day);
}

/// Statistiques de la routine, calculées à partir des seules données
/// réellement enregistrées (les `completedDays` de chaque activité).
class HabitStats {
  const HabitStats({
    required this.hasRoutine,
    required this.currentStreak,
    required this.bestStreak,
    required this.weekDone,
    required this.weekDue,
    required this.monthDone,
    required this.monthDue,
    required this.last7Days,
    required this.monthDays,
    required this.history,
  });

  /// `true` dès qu'au moins une activité existe.
  final bool hasRoutine;

  /// Série actuelle : jours consécutifs entièrement respectés, en ne
  /// cassant pas sur une journée « en cours » (aujourd'hui non terminée).
  final int currentStreak;

  /// Record : plus longue série de jours entièrement respectés.
  final int bestStreak;

  /// Occurrences terminées / prévues sur la semaine ISO courante.
  final int weekDone;
  final int weekDue;

  /// Occurrences terminées / prévues sur le mois courant.
  final int monthDone;
  final int monthDue;

  /// Les 7 derniers jours (du plus ancien au plus récent, aujourd'hui inclus).
  final List<DayStat> last7Days;

  /// Jours du mois courant jusqu'à aujourd'hui (pour la grille mensuelle).
  final List<DayStat> monthDays;

  /// Journées récentes pour l'historique (du plus récent au plus ancien).
  final List<DayStat> history;

  int get weekMissed => weekDue - weekDone;
  int get monthMissed => monthDue - monthDone;

  /// Taux de réussite de la semaine, ou `null` sans occurrence prévue.
  double? get weekRate => weekDue == 0 ? null : weekDone / weekDue;

  /// Taux de réussite du mois, ou `null` sans occurrence prévue.
  double? get monthRate => monthDue == 0 ? null : monthDone / monthDue;
}

/// Calcule les statistiques de la routine.
///
/// Formule du taux de réussite :
/// `occurrences terminées / occurrences prévues`, où une occurrence est une
/// activité prévue un jour donné. La formule est identique au jour, à la
/// semaine (lundi → dimanche) et au mois : les chiffres restent cohérents.
/// Les journées sans activité prévue sont « neutres » : exclues du taux et
/// ignorées dans les séries (elles ne cassent pas une série). Une série ne
/// se casse pas sur une journée en cours (aujourd'hui pas encore terminée).
///
/// Fonction pure et isolée : appelée par un provider Riverpod mémorisé, elle
/// ne refait jamais de calcul lourd dans `build()`.
abstract final class StatsCalculator {
  static HabitStats compute(List<Activity> activities, DateTime today) {
    final t = DateTime(today.year, today.month, today.day);

    if (activities.isEmpty) {
      return const HabitStats(
        hasRoutine: false,
        currentStreak: 0,
        bestStreak: 0,
        weekDone: 0,
        weekDue: 0,
        monthDone: 0,
        monthDue: 0,
        last7Days: [],
        monthDays: [],
        history: [],
      );
    }

    final completedSets = [for (final a in activities) a.completedDays.toSet()];
    var minDate = activities
        .map((a) => DateTime(a.date.year, a.date.month, a.date.day))
        .reduce((x, y) => x.isBefore(y) ? x : y);
    // Garde-fou : une date aberrante (corruption, import) genre 1970 ferait
    // boucler ~20 000 jours sur le thread UI. L'historique exploitable est
    // borné à 2 ans — au-delà, les stats sont identiques.
    final minAllowed = DateTime(t.year, t.month, t.day - 730);
    if (minDate.isBefore(minAllowed)) minDate = minAllowed;

    final weekStart = _isoWeekStart(t);
    final monthStart = DateTime(t.year, t.month, 1);

    final days = <DayStat>[];
    var weekDue = 0, weekDone = 0, monthDue = 0, monthDone = 0;
    var cursor = minDate;

    while (!cursor.isAfter(t)) {
      final key = Activity.dateKey(cursor);
      var due = 0;
      var done = 0;
      for (var i = 0; i < activities.length; i++) {
        final a = activities[i];
        if (!a.isDueOn(cursor)) continue;
        due++;
        if (completedSets[i].contains(key)) done++;
      }

      days.add(DayStat(
        day: cursor,
        status: _status(due, done),
        due: due,
        done: done,
      ));

      if (!cursor.isBefore(weekStart)) {
        weekDue += due;
        weekDone += done;
      }
      if (!cursor.isBefore(monthStart)) {
        monthDue += due;
        monthDone += done;
      }
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }

    final byKey = {for (final d in days) Activity.dateKey(d.day): d};
    DayStat dayAt(DateTime date) =>
        byKey[Activity.dateKey(date)] ??
        DayStat(day: date, status: DayStatus.neutral, due: 0, done: 0);

    return HabitStats(
      hasRoutine: true,
      currentStreak: _currentStreak(days),
      bestStreak: _bestStreak(days),
      weekDone: weekDone,
      weekDue: weekDue,
      monthDone: monthDone,
      monthDue: monthDue,
      last7Days: [
        for (var i = 6, d = DateTime(t.year, t.month, t.day - 6);
            i >= 0;
            i--, d = DateTime(d.year, d.month, d.day + 1))
          dayAt(d),
      ],
      monthDays: [
        for (var d = monthStart; !d.isAfter(t);
            d = DateTime(d.year, d.month, d.day + 1))
          dayAt(d),
      ],
      history: days.reversed.take(14).toList(),
    );
  }

  static DayStatus _status(int due, int done) {
    if (due == 0) return DayStatus.neutral;
    if (done == 0) return DayStatus.missed;
    if (done == due) return DayStatus.respected;
    return DayStatus.partial;
  }

  /// Lundi de la semaine ISO contenant [t] (lundi = premier jour).
  static DateTime _isoWeekStart(DateTime t) =>
      DateTime(t.year, t.month, t.day - (t.weekday - 1));

  static int _currentStreak(List<DayStat> days) {
    if (days.isEmpty) return 0;
    var i = days.length - 1; // aujourd'hui (dernier jour du calcul)
    if (days[i].status != DayStatus.respected) {
      i--; // aujourd'hui pas encore terminée → on s'appuie sur hier
      if (i < 0) return 0;
    }
    var streak = 0;
    while (i >= 0) {
      switch (days[i].status) {
        case DayStatus.respected:
          streak++;
          i--;
        case DayStatus.neutral:
          i--; // les journées sans routine ne cassent pas la série
        case DayStatus.partial:
        case DayStatus.missed:
          return streak;
      }
    }
    return streak;
  }

  static int _bestStreak(List<DayStat> days) {
    var best = 0;
    var run = 0;
    for (final d in days) {
      switch (d.status) {
        case DayStatus.respected:
          run++;
          if (run > best) best = run;
        case DayStatus.neutral:
          break; // ne casse pas la série
        case DayStatus.partial:
        case DayStatus.missed:
          run = 0;
      }
    }
    return best;
  }
}
