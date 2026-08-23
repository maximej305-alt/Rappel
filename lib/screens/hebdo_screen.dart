import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/activity.dart';
import '../providers/providers.dart';
import '../theme/app_typography.dart';
import '../utils/activity_sort.dart';
import '../utils/dates.dart';
import '../widgets/activity_tile.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/week_day_strip.dart';
import 'add_activity_screen.dart';

class HebdoScreen extends ConsumerStatefulWidget {
  const HebdoScreen({super.key});

  @override
  ConsumerState<HebdoScreen> createState() => _HebdoScreenState();
}

class _HebdoScreenState extends ConsumerState<HebdoScreen> {
  late DateTime _weekStart;
  late DateTime _selectedDay;
  late String _lastTodayKey;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = WeekDayStrip.startOfWeek(now);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _lastTodayKey = Activity.dateKey(now);
  }

  void _goTo(int direction) {
    setState(() {
      // Conserve le jour de semaine choisi par l'utilisateur au lieu de
      // retomber systématiquement sur le lundi.
      final weekday = _selectedDay.weekday.clamp(1, 7);
      _weekStart = direction < 0
          ? WeekDayStrip.previousWeek(_weekStart)
          : WeekDayStrip.nextWeek(_weekStart);
      _selectedDay = _weekStart.add(Duration(days: weekday - 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    // Rollover minuit : l'onglet reste monté en permanence (IndexedStack
    // paresseux) — sans cette resynchronisation, « aujourd'hui » resterait
    // figé sur la veille après un passage de minuit, app ouverte ou non.
    final todayKey = ref.watch(todayProvider);
    if (todayKey != _lastTodayKey) {
      _lastTodayKey = todayKey;
      final today = Activity.parseDateKey(todayKey) ?? DateTime.now();
      _weekStart = WeekDayStrip.startOfWeek(today);
      _selectedDay = today;
    }
    final activities = ref.watch(activitiesProvider);
    final locale = ref.watch(localeProvider);
    final s = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;

    final dayActivities =
        activities.where((a) => a.isDueOn(_selectedDay)).toList()
          ..sort(compareActivities);

    final weekDays = [
      for (var i = 0; i < 7; i++) _weekStart.add(Duration(days: i)),
    ];
    final dayDueCounts = <DateTime, int>{};
    final dayDoneCounts = <DateTime, int>{};
    for (final d in weekDays) {
      var due = 0;
      var done = 0;
      for (final a in activities) {
        if (a.isDueOn(d)) {
          due++;
          if (a.isCompletedOn(d)) done++;
        }
      }
      dayDueCounts[d] = due;
      dayDoneCounts[d] = done;
    }
    final fullDays = weekDays
        .where(
          (d) =>
              (dayDueCounts[d] ?? 0) > 0 &&
              (dayDoneCounts[d] ?? 0) >= (dayDueCounts[d] ?? 0),
        )
        .length;
    final activeDays = weekDays.where((d) => (dayDueCounts[d] ?? 0) > 0).length;
    final doneThisWeek = dayDoneCounts.values.fold<int>(0, (sum, v) => sum + v);

    return Scaffold(
      appBar: AppBar(title: Text(s.myWeek)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _goTo(-1),
                          icon: const Icon(Icons.chevron_left),
                          tooltip: s.prevWeek,
                        ),
                        Expanded(
                          child: Text(
                            _weekLabel(locale),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: AppTypography.sectionTitle.copyWith(
                              fontSize: AppTypography.sizeBase,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _goTo(1),
                          icon: const Icon(Icons.chevron_right),
                          tooltip: s.nextWeek,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    WeekDayStrip(
                      weekStart: _weekStart,
                      selectedDay: _selectedDay,
                      dueCounts: dayDueCounts,
                      doneCounts: dayDoneCounts,
                      onDaySelected: (day) =>
                          setState(() => _selectedDay = day),
                    ),
                    const SizedBox(height: 16),
                    _WeeklyStats(
                      fullDays: fullDays,
                      activeDays: activeDays,
                      doneCount: doneThisWeek,
                      scheme: scheme,
                      s: s,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Text(
              _capitalize(formatDay(_selectedDay, locale)),
              style: AppTypography.calendarHeader.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ),
          if (dayActivities.isEmpty)
            AppEmptyState(icon: Icons.event_busy, title: s.weeklyEmpty)
          else
            for (final activity in dayActivities)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: ActivityTile(
                  activity: activity,
                  day: _selectedDay,
                  onTap: () => _openEdit(activity),
                  onToggle: () =>
                      toggleCompletedWithAlarm(ref, activity, _selectedDay),
                  onDelete: () => _deleteActivity(activity, s),
                ),
              ),
        ],
      ),
    );
  }

  String _weekLabel(String locale) {
    final end = _weekStart.add(const Duration(days: 6));
    final fmt = DateFormat('d');
    final fmtMonth = DateFormat('MMMM yyyy', intlLocale(locale));
    if (_weekStart.month == end.month) {
      return '${fmt.format(_weekStart)} – ${fmt.format(end)} ${fmtMonth.format(end)}';
    }
    return '${fmt.format(_weekStart)} ${DateFormat('MMM', intlLocale(locale)).format(_weekStart)} – '
        '${fmt.format(end)} ${fmtMonth.format(end)}';
  }

  String formatDay(DateTime day, String locale) {
    return DateFormat('EEEE d MMMM yyyy', intlLocale(locale)).format(day);
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

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

class _WeeklyStats extends StatelessWidget {
  const _WeeklyStats({
    required this.fullDays,
    required this.activeDays,
    required this.doneCount,
    required this.scheme,
    required this.s,
  });

  final int fullDays;
  final int activeDays;
  final int doneCount;
  final ColorScheme scheme;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: Icons.verified,
              value: activeDays == 0 ? '—' : '$fullDays/$activeDays',
              label: s.weeklyFull,
              scheme: scheme,
            ),
          ),
          Container(width: 1, height: 40, color: scheme.outlineVariant),
          Expanded(
            child: _StatItem(
              icon: Icons.local_fire_department,
              value: '$doneCount',
              label: s.weeklyDone,
              scheme: scheme,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.scheme,
  });

  final IconData icon;
  final String value;
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: scheme.primary, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.sectionTitle.copyWith(color: scheme.onSurface),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelXs.copyWith(color: scheme.outline),
        ),
      ],
    );
  }
}
