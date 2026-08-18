import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/activity.dart';
import '../providers/providers.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/theme_palette.dart';
import '../utils/dates.dart';
import '../widgets/activity_tile.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/habit_chart.dart';
import '../widgets/progress_ring.dart';
import 'add_activity_screen.dart';
import 'search_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final todays = ref.watch(todayActivitiesProvider);
    final locale = ref.watch(localeProvider);
    final s = ref.watch(stringsProvider);
    final palette = ref.watch(paletteProvider);
    final accent = ref
        .watch(accentProvider)
        .forBrightness(Theme.of(context).brightness);
    // Fond du FAB : toujours la teinte saturée, pour garder le contraste
    // WCAG AA du texte blanc quel que soit le thème.
    final fabAccent = ref.watch(accentProvider).light;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();

    final done = todays.where((a) => a.isCompletedOn(today)).length;
    final habitStats = ref.watch(habitStatsProvider);

    return Scaffold(
      floatingActionButton: Semantics(
        label: s.addActivity,
        button: true,
        child: FloatingActionButton.extended(
          onPressed: _openAdd,
          tooltip: s.addActivity,
          icon: const Icon(Icons.add),
          label: Text(s.addActivity),
          elevation: 4,
          backgroundColor: fabAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      body: ListView.builder(
        padding: EdgeInsets.only(
          bottom: 96,
          top: MediaQuery.of(context).padding.top + 8,
        ),
        itemCount: todays.isEmpty ? 2 : 1 + todays.length,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildHeader(
              todays: todays,
              done: done,
              habitStats: habitStats,
              locale: locale,
              isDark: isDark,
              palette: palette,
              accent: accent,
              s: s,
            );
          }
          if (todays.isEmpty) {
            return AppEmptyState(
              icon: Icons.event_available,
              title: s.emptyTodayTitle,
              hint: s.emptyTodayHint,
            );
          }
          final activity = todays[index - 1];
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: ActivityTile(
              activity: activity,
              day: today,
              onTap: () => _openEdit(activity),
              onToggle: () => toggleCompletedWithAlarm(ref, activity, today),
              onDelete: () => _deleteActivity(activity, s),
            ),
          );
        },
      ),
    );
  }

  /// En-tête de l'accueil : salutation, date du jour, résumé de routine et
  /// titre de la section « Aujourd'hui ». Un seul item de la liste pour
  /// limiter les reconstructions.
  Widget _buildHeader({
    required List<Activity> todays,
    required int done,
    required HabitStats habitStats,
    required String locale,
    required bool isDark,
    required ThemePalette palette,
    required Color accent,
    required AppStrings s,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();

    return Column(
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
                      style: AppTypography.headlineSmall.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _greeting(s),
                      style: AppTypography.captionMd.copyWith(
                        fontWeight: AppTypography.w600,
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              if (habitStats.currentStreak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        size: 15,
                        color: accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${habitStats.currentStreak} ${s.streakUnit}',
                        style: AppTypography.captionMd.copyWith(
                          fontWeight: AppTypography.w700,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              IconButton(
                onPressed: _openSearch,
                tooltip: s.search,
                icon: const Icon(Icons.search),
                color: scheme.onSurfaceVariant,
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
            gradient: AppTheme.headerGradientFor(palette, isDark),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.seedFor(palette, isDark).withValues(alpha: 0.3),
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
                              intlLocale(locale),
                            ).format(today),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.appBar.copyWith(
                            color: Colors.white,
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
                  style: AppTypography.captionMd.copyWith(
                    color: Colors.white,
                    fontWeight: AppTypography.w600,
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
              accent: accent,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            children: [
              Text(
                s.today,
                style: AppTypography.sectionTitle.copyWith(
                  letterSpacing: -0.3,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$done/${todays.length}',
                  style: AppTypography.caption.copyWith(
                    fontWeight: AppTypography.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
    final left = due - done;
    return left > 1 ? s.statusLeftPlural(left) : s.statusLeft(left);
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  void _openSearch() {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const SearchScreen()));
  }

  Future<void> _openAdd() async {
    final messenger = ScaffoldMessenger.of(context);
    final added = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddActivityScreen()));
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
