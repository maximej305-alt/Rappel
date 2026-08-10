import '../models/activity.dart';
import '../models/routine.dart';
import 'notification_service.dart';

/// Construit les activités d'une routine à partir de brouillons.
///
/// Chaque activité reçoit un `notificationId` garanti unique vis-à-vis de
/// [usedIds] et des dérivés hebdo (`n*8+w`), en réutilisant exactement le
/// système d'allocation existant. Fonction pure et isolée, testable sans
/// stockage ni notifications.
abstract final class RoutineService {
  static List<Activity> buildActivities(
    List<RoutineActivityDraft> drafts, {
    required Set<int> usedIds,
    bool enabled = true,
    DateTime? now,
  }) {
    final used = Set<int>.of(usedIds);
    final today = DateTime(now?.year ?? DateTime.now().year,
        now?.month ?? DateTime.now().month, now?.day ?? DateTime.now().day);
    final result = <Activity>[];
    for (final d in drafts) {
      final weekdays =
          d.repeat == RepeatRule.weekly ? List.of(d.weekdays) : const <int>[];
      final activity = Activity.create(
        name: d.name,
        hour: d.hour,
        minute: d.minute,
        date: d.date ?? today,
        repeat: d.repeat,
        weekdays: weekdays,
        sound: d.sound,
        enabled: enabled,
        priority: d.priority,
        categoryId: d.categoryId,
        notificationId: NotificationService.allocateFreshId(
          used,
          repeat: d.repeat,
          weekdays: weekdays,
        ),
      );
      used.addAll(NotificationService.idsSet(activity));
      result.add(activity);
    }
    return result;
  }
}
