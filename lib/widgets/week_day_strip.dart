import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/activity.dart';

class WeekDayStrip extends StatelessWidget {
  const WeekDayStrip({
    super.key,
    required this.weekStart,
    required this.selectedDay,
    required this.activities,
    required this.onDaySelected,
  });

  /// Lundi de la semaine affichée.
  final DateTime weekStart;
  final DateTime selectedDay;
  final List<Activity> activities;
  final ValueChanged<DateTime> onDaySelected;

  static DateTime startOfWeek(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  static DateTime nextWeek(DateTime weekStart) =>
      weekStart.add(const Duration(days: 7));

  static DateTime previousWeek(DateTime weekStart) =>
      weekStart.subtract(const Duration(days: 7));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = context.l10n;
    final letters = [s.mon, s.tue, s.wed, s.thu, s.fri, s.sat, s.sun]
        .map((label) => label.substring(0, 1))
        .toList();

    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: _DayCell(
              day: weekStart.add(Duration(days: i)),
              label: letters[i],
              selected: selectedDay.weekday == i + 1 &&
                  _sameDate(selectedDay, weekStart.add(Duration(days: i))),
              doneCount: _doneCount(weekStart.add(Duration(days: i))),
              dueCount: _dueCount(weekStart.add(Duration(days: i))),
              scheme: scheme,
              onTap: () =>
                  onDaySelected(weekStart.add(Duration(days: i))),
            ),
          ),
      ],
    );
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _dueCount(DateTime day) =>
      activities.where((a) => a.isDueOn(day)).length;

  int _doneCount(DateTime day) => activities
      .where((a) => a.isDueOn(day) && a.isCompletedOn(day))
      .length;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.label,
    required this.selected,
    required this.doneCount,
    required this.dueCount,
    required this.scheme,
    required this.onTap,
  });

  final DateTime day;
  final String label;
  final bool selected;
  final int doneCount;
  final int dueCount;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = day.year == DateTime.now().year &&
        day.month == DateTime.now().month &&
        day.day == DateTime.now().day;
    final complete = dueCount > 0 && doneCount >= dueCount;
    final fraction = dueCount == 0 ? 0.0 : doneCount / dueCount;

    final bg = selected
        ? scheme.primary
        : scheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final fg = selected ? scheme.onPrimary : scheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: 86,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? scheme.onPrimary.withValues(alpha: 0.8)
                      : scheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
              const SizedBox(height: 6),
              if (isToday)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: complete ? Colors.greenAccent : Colors.amberAccent,
                    shape: BoxShape.circle,
                  ),
                )
              else if (dueCount > 0)
                SizedBox(
                  width: 26,
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                    backgroundColor:
                        selected ? Colors.white24 : scheme.outlineVariant,
                    color: complete ? Colors.greenAccent : Colors.amberAccent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
