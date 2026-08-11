import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../models/activity.dart';
import '../models/routine.dart';
import '../providers/providers.dart';
import '../theme/app_typography.dart';
import '../widgets/activity_tile.dart';
import 'add_activity_screen.dart';
import 'routine_edit_screen.dart';

/// Détail d'une routine : activités concrètes, modification, suppression.
///
/// Chaque activité reste indépendante : la cocher, la modifier ou la
/// supprimer n'affecte jamais les autres activités de la routine.
class RoutineDetailScreen extends ConsumerStatefulWidget {
  const RoutineDetailScreen({super.key, required this.routine});

  final Routine routine;

  @override
  ConsumerState<RoutineDetailScreen> createState() =>
      _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends ConsumerState<RoutineDetailScreen> {
  Routine? get _currentRoutine {
    return ref
        .read(routinesProvider)
        .where((r) => r.id == widget.routine.id)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final routine = _currentRoutine;
    if (routine == null) {
      return Scaffold(appBar: AppBar(title: Text(s.routines)));
    }

    final activities = ref.watch(routineActivitiesProvider)[routine.id] ?? [];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${routine.icon}  ${routine.name}'),
        actions: [
          IconButton(
            tooltip: s.editRoutine,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editRoutine(routine),
          ),
          IconButton(
            tooltip: s.deleteRoutineTitle,
            icon: Icon(Icons.delete_outline, color: scheme.error),
            onPressed: () => _deleteRoutine(routine, activities),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(routine.icon,
                            style: const TextStyle(fontSize: 30)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                routine.name,
                                style: AppTypography.sectionTitle.copyWith(
                                  letterSpacing: -0.3,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                s.activitiesLabel(activities.length),
                                style: AppTypography.caption.copyWith(
                                  color: scheme.outline,
                                ),
                              ),
                              if (routine.description != null &&
                                  routine.description!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  routine.description!,
                                  style: AppTypography.captionMd.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: routine.active,
                      onChanged: (v) => _setActive(routine, v),
                      title: Text(
                        routine.active ? s.routineActive : s.routineInactive,
                        style: AppTypography.captionMd.copyWith(
                          fontWeight: AppTypography.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        routine.active ? s.pauseRoutine : s.resumeRoutine,
                        style: AppTypography.caption.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                      secondary: Icon(
                        routine.active
                            ? Icons.play_circle_outline
                            : Icons.pause_circle_outline,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
            child: Text(
              s.routineActivities,
              style: AppTypography.captionMd.copyWith(
                fontWeight: AppTypography.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  s.routineActivityRequired,
                  style: AppTypography.bodyMedium.copyWith(
                    color: scheme.outline,
                  ),
                ),
              ),
            )
          else
            for (final activity in activities)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: ActivityTile(
                  activity: activity,
                  day: DateTime.now(),
                  onTap: () => _editActivity(activity),
                  onToggle: () => ref
                      .read(activitiesProvider.notifier)
                      .toggleCompleted(activity.id, DateTime.now()),
                  onDelete: () => _deleteActivity(activity),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _editRoutine(Routine routine) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RoutineEditScreen(routine: routine)),
    );
  }

  Future<void> _editActivity(Activity activity) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddActivityScreen(editingActivity: activity),
      ),
    );
  }

  Future<void> _deleteActivity(Activity activity) async {
    final s = context.l10n;
    final routine = _currentRoutine;
    if (routine == null) return;
    final confirmed = await _confirm(
      title: s.removeActivityTitle,
      content: s.deleteConfirmBody(activity.name),
    );
    if (confirmed != true) return;

    final notifications = ref.read(notificationServiceProvider);
    await notifications.cancelActivity(activity);
    await ref.read(activitiesProvider.notifier).remove(activity.id);
    final pruned = routine.copyWith(
      activityIds:
          routine.activityIds.where((id) => id != activity.id).toList(),
    );
    await ref.read(routinesProvider.notifier).update(pruned);
  }

  Future<void> _deleteRoutine(
    Routine routine,
    List<Activity> activities,
  ) async {
    final s = context.l10n;
    final confirmed = await _confirm(
      title: s.deleteRoutineTitle,
      content: s.deleteRoutineBody(routine.name, activities.length),
    );
    if (confirmed != true) return;

    final notifications = ref.read(notificationServiceProvider);
    final activitiesNotifier = ref.read(activitiesProvider.notifier);
    for (final a in activities) {
      await notifications.cancelActivity(a);
      await activitiesNotifier.remove(a.id);
    }
    await ref.read(routinesProvider.notifier).remove(routine.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _setActive(Routine routine, bool active) async {
    final s = context.l10n;
    final offset = ref.read(settingsProvider).reminderOffsetMinutes;
    final notifications = ref.read(notificationServiceProvider);
    final notifier = ref.read(activitiesProvider.notifier);
    final activities = ref.read(routineActivitiesProvider)[routine.id] ?? [];
    for (final a in activities) {
      final updated = a.copyWith(enabled: active);
      if (active) {
        await notifications.scheduleActivity(updated,
            reminderOffsetMinutes: offset, s: s);
      } else {
        await notifications.cancelActivity(a);
      }
      await notifier.update(updated);
    }
    await ref
        .read(routinesProvider.notifier)
        .update(routine.copyWith(active: active));
  }

  Future<bool?> _confirm({required String title, required String content}) {
    final s = context.l10n;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
  }
}
