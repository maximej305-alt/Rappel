import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../l10n/l10n.dart';
import '../models/activity.dart';
import '../providers/providers.dart';
import '../utils/dates.dart';
import '../widgets/activity_tile.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_empty_state.dart';
import 'add_activity_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final activities = ref.watch(activitiesProvider);
    final locale = ref.watch(localeProvider);
    final s = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;

    final selectedActivities =
        activities.where((a) => a.isDueOn(_selectedDay)).toList()
      ..sort(
          (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));

    final events = <DateTime, List<Activity>>{};
    final monthStart = DateTime(_focusedDay.year, _focusedDay.month, 1)
        .subtract(const Duration(days: 7));
    final monthEnd = DateTime(_focusedDay.year, _focusedDay.month + 1, 1)
        .add(const Duration(days: 14));
    for (final a in activities) {
      var cursor = monthStart;
      while (!cursor.isAfter(monthEnd)) {
        if (a.isDueOn(cursor)) {
          events.putIfAbsent(cursor, () => []).add(a);
        }
        cursor = cursor.add(const Duration(days: 1));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.calendar)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TableCalendar<Activity>(
                  firstDay: DateTime(DateTime.now().year - 1),
                  lastDay: DateTime(DateTime.now().year + 5),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selectedDay = selected;
                      _focusedDay = focused;
                    });
                  },
                  onPageChanged: (focused) =>
                      setState(() => _focusedDay = focused),
                  locale: locale.startsWith('fr') ? 'fr_FR' : 'en_US',
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  calendarFormat: CalendarFormat.month,
                  eventLoader: (day) => events[day] ?? const [],
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      color: scheme.outline,
                      fontWeight: FontWeight.w700,
                    ),
                    weekendStyle: TextStyle(
                      color: scheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                    markerSize: 6,
                    outsideDaysVisible: false,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: Text(
              _capitalize(formatFullDate(_selectedDay, locale)),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ),
          if (selectedActivities.isEmpty)
            AppEmptyState(
              icon: Icons.event_busy,
              title: s.weeklyEmpty,
            )
          else
            for (final activity in selectedActivities)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: ActivityTile(
                  activity: activity,
                  day: _selectedDay,
                  onTap: () => _openEdit(activity),
                  onToggle: () => ref
                      .read(activitiesProvider.notifier)
                      .toggleCompleted(activity.id, _selectedDay),
                  onDelete: () => _deleteActivity(activity, s),
                ),
              ),
        ],
      ),
    );
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
