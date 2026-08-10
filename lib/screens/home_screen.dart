import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/activity.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_tile.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/habit_chart.dart';
import '../widgets/progress_ring.dart';
import 'add_activity_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final activities = ref.watch(activitiesProvider);
    final locale = ref.watch(localeProvider);
    final s = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();

    final todays = activities.where((a) => a.isDueOn(today)).toList()
      ..sort(
          (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));

    final done = todays.where((a) => a.isCompletedOn(today)).length;
    final habitStats = ref.watch(habitStatsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        tooltip: s.addActivity,
        icon: const Icon(Icons.add),
        label: Text(s.addActivity),
        elevation: 4,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: 96,
          top: MediaQuery.of(context).padding.top + 8,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.homeTitle,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _greeting(s),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                if (habitStats.currentStreak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department,
                            size: 15, color: scheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${habitStats.currentStreak} ${s.streakUnit}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // En-tête : une seule ligne.
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              gradient:
                  isDark ? AppTheme.headerGradientDark : AppTheme.headerGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.seed.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _capitalize(
                              DateFormat(
                                'EEEE d MMMM',
                                locale.startsWith('fr') ? 'fr_FR' : 'en_US',
                              ).format(today),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ProgressRing(
                      progress: todays.isEmpty ? 0 : done / todays.length,
                      valueLabel: '$done/${todays.length}',
                      unitLabel: s.done,
                      size: 74,
                      strokeWidth: 6,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _statusLine(todays.length, done, s),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (habitStats.hasRoutine)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: HabitChart(
                stats: habitStats,
                locale: locale,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(
              children: [
                Text(
                  s.today,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$done/${todays.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (todays.isEmpty)
            AppEmptyState(
              icon: Icons.event_available,
              title: s.emptyTodayTitle,
              hint: s.emptyTodayHint,
            )
          else
            for (final activity in todays)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: ActivityTile(
                  activity: activity,
                  day: today,
                  onTap: () => _openEdit(activity),
                  onToggle: () => ref
                      .read(activitiesProvider.notifier)
                      .toggleCompleted(activity.id, today),
                  onDelete: () => _deleteActivity(activity, s),
                ),
              ),
        ],
      ),
    );
  }

  String _greeting(AppStrings s) {
    final hour = DateTime.now().hour;
    if (hour < 5) return s.greetingNight;
    if (hour < 12) return s.greetingMorning;
    if (hour < 18) return s.greetingAfternoon;
    return s.greetingEvening;
  }

  String _statusLine(int due, int done, AppStrings s) {
    if (due == 0) return s.statusNothing;
    if (done == due) return s.statusAllDone;
    return s.statusLeft(due - done);
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Future<void> _openAdd() async {
    final messenger = ScaffoldMessenger.of(context);
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddActivityScreen()),
    );
    if (added == true && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(ref.read(stringsProvider).activityAdded)),
      );
    }
  }

  Future<void> _openEdit(Activity activity) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddActivityScreen(editingActivity: activity),
      ),
    );
  }

  Future<void> _deleteActivity(Activity activity, AppStrings s) async {
    final confirmed = await showConfirmDialog(
      context,
      title: s.deleteConfirmTitle,
      body: s.deleteConfirmBody(activity.name),
      confirmLabel: s.delete,
      cancelLabel: s.cancel,
    );
    if (confirmed != true) return;
    await ref.read(notificationServiceProvider).cancelActivity(activity);
    await ref.read(activitiesProvider.notifier).remove(activity.id);
  }
}
