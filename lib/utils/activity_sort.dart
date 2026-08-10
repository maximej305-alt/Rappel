import '../models/activity.dart';

/// Comparateur d'ordre d'affichage des activités.
///
/// Ordre appliqué :
///  1. date de l'activité (croissante) ;
///  2. heure (croissante) ;
///  3. priorité (décroissante : urgent > important > normal) ;
///  4. nom (croissant, ordre déterministe).
int compareActivities(Activity a, Activity b) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) return byDate;

  final byTime = (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute);
  if (byTime != 0) return byTime;

  final byPriority = b.priority.index.compareTo(a.priority.index);
  if (byPriority != 0) return byPriority;

  return a.name.compareTo(b.name);
}
