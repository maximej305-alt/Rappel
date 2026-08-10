import '../l10n/app_strings.dart';
import '../models/activity.dart';
import '../models/activity_priority.dart';
import '../models/category.dart';
import 'activity_sort.dart';

/// Normalise une chaîne pour la recherche : minuscules + suppression des
/// accents et ligatures courants du français et des langues latines.
/// Exemples : « Ménage » → « menage », « Été » → « ete ».
String normalizeForSearch(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_accentMap[ch] ?? ch);
  }
  return buffer.toString();
}

const _accentMap = <String, String>{
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
  'ă': 'a', 'ą': 'a',
  'æ': 'ae',
  'ç': 'c', 'ć': 'c', 'ĉ': 'c', 'ċ': 'c', 'č': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e', 'ė': 'e',
  'ę': 'e', 'ě': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ĭ': 'i', 'į': 'i',
  'ı': 'i',
  'ñ': 'n', 'ń': 'n', 'ň': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o',
  'ŏ': 'o', 'ő': 'o',
  'œ': 'oe',
  'ß': 'ss',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ŭ': 'u', 'ů': 'u',
  'ű': 'u',
  'ý': 'y', 'ÿ': 'y', 'ŷ': 'y',
  'ž': 'z', 'ź': 'z', 'ż': 'z',
  'š': 's', 'ś': 's', 'ş': 's', 'ș': 's',
};

/// Portée de date d'un filtre de recherche.
enum DateScope { all, today, tomorrow, thisWeek }

/// Filtre de statut d'un filtre de recherche.
///
/// Les deux états actifs sont limités aux activités dues aujourd'hui :
/// « À faire » = due aujourd'hui ET non terminée ; « Terminées » = due
/// aujourd'hui ET terminée. Une activité future n'apparaît jamais dedans.
enum StatusFilter { all, todo, done }

/// Filtres combinables de la recherche (aucune persistance).
class ActivityFilter {
  const ActivityFilter({
    this.date = DateScope.all,
    this.status = StatusFilter.all,
    this.priority,
    this.categoryId,
  });

  final DateScope date;
  final StatusFilter status;

  /// `null` = toutes les priorités.
  final Priority? priority;

  /// Identifiant de catégorie ; `null` = toutes les catégories.
  final String? categoryId;

  bool get isActive =>
      date != DateScope.all ||
      status != StatusFilter.all ||
      priority != null ||
      categoryId != null;

  int get activeCount =>
      (date != DateScope.all ? 1 : 0) +
      (status != StatusFilter.all ? 1 : 0) +
      (priority != null ? 1 : 0) +
      (categoryId != null ? 1 : 0);

  ActivityFilter copyWith({
    DateScope? date,
    StatusFilter? status,
    Priority? priority,
    String? categoryId,
    bool clearPriority = false,
    bool clearCategory = false,
  }) {
    return ActivityFilter(
      date: date ?? this.date,
      status: status ?? this.status,
      priority: clearPriority ? null : (priority ?? this.priority),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    );
  }
}

/// Filtre puis trie les activités pour la recherche.
///
/// La recherche texte porte sur le nom de l'activité ET le nom affiché de sa
/// catégorie, sans tenir compte de la casse ni des accents. Les filtres sont
/// évalués en premier (les moins coûteux d'abord) pour écarter au plus vite
/// les activités non pertinentes, puis la recherche texte normalisée.
List<Activity> filterActivities({
  required List<Activity> activities,
  required List<Category> categories,
  required String query,
  required ActivityFilter filter,
  required DateTime now,
  required AppStrings s,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final weekStart = _startOfWeek(today);
  final weekEnd = weekStart.add(const Duration(days: 7));
  final normalizedQuery = normalizeForSearch(query.trim());
  final categoryNames = {for (final c in categories) c.id: c.displayName(s)};

  final result = <Activity>[];
  for (final activity in activities) {
    if (!_matchesFilters(activity, filter, today, tomorrow, weekStart, weekEnd)) {
      continue;
    }
    if (!_matchesQuery(activity, normalizedQuery, categoryNames)) {
      continue;
    }
    result.add(activity);
  }

  result.sort(compareActivities);
  return result;
}

bool _matchesFilters(
  Activity activity,
  ActivityFilter filter,
  DateTime today,
  DateTime tomorrow,
  DateTime weekStart,
  DateTime weekEnd,
) {
  switch (filter.date) {
    case DateScope.all:
      break;
    case DateScope.today:
      if (!activity.isDueOn(today)) return false;
    case DateScope.tomorrow:
      if (!activity.isDueOn(tomorrow)) return false;
    case DateScope.thisWeek:
      if (!_isDueInRange(activity, weekStart, weekEnd)) return false;
  }

  switch (filter.status) {
    case StatusFilter.all:
      break;
    case StatusFilter.todo:
      if (!activity.isDueOn(today) || activity.isCompletedOn(today)) {
        return false;
      }
    case StatusFilter.done:
      if (!activity.isDueOn(today) || !activity.isCompletedOn(today)) {
        return false;
      }
  }

  if (filter.priority != null && activity.priority != filter.priority) {
    return false;
  }

  if (filter.categoryId != null && activity.categoryId != filter.categoryId) {
    return false;
  }

  return true;
}

bool _matchesQuery(
  Activity activity,
  String normalizedQuery,
  Map<String, String> categoryNames,
) {
  if (normalizedQuery.isEmpty) return true;
  final name = normalizeForSearch(activity.name);
  if (name.contains(normalizedQuery)) return true;
  final categoryName = categoryNames[activity.categoryId];
  return categoryName != null &&
      normalizeForSearch(categoryName).contains(normalizedQuery);
}

/// Lundi de la semaine de [day] (semaine commençant le lundi).
DateTime _startOfWeek(DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

bool _isDueInRange(Activity activity, DateTime start, DateTime end) {
  for (var day = start; day.isBefore(end); day = day.add(const Duration(days: 1))) {
    if (activity.isDueOn(day)) return true;
  }
  return false;
}
