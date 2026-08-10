import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/activity.dart';
import '../providers/providers.dart';
import '../services/stats_service.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/habit_chart.dart';
import '../widgets/section_header.dart';

/// Vue « Stats » : série, record, taux de réussite, résumé de la semaine,
/// progression hebdomadaire, historique et vue mensuelle.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(habitStatsProvider);
    final locale = ref.watch(localeProvider);
    final s = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(s.stats)),
      body: !stats.hasRoutine
          ? AppEmptyState(
              icon: Icons.insights_outlined,
              title: s.statsEmptyTitle,
              hint: s.statsEmptyHint,
              centered: true,
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.local_fire_department,
                          label: s.currentStreak,
                          value: '${stats.currentStreak}',
                          unit: s.daysUnit,
                          scheme: scheme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.emoji_events_outlined,
                          label: s.bestRecord,
                          value: '${stats.bestStreak}',
                          unit: s.consecutiveDaysUnit,
                          scheme: scheme,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _WeekSummaryCard(stats: stats, s: s, scheme: scheme),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: SectionHeader.subtitle(s.weeklyProgress),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child:
                        HabitBarChart(days: stats.last7Days, locale: locale),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: SectionHeader.subtitle(s.history),
                ),
                _HistoryList(
                  days: stats.history,
                  scheme: scheme,
                  s: s,
                  locale: locale,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: SectionHeader.subtitle(s.monthlyView),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: _MonthGrid(
                      days: stats.monthDays,
                      today: DateTime.now(),
                      s: s,
                      scheme: scheme,
                      locale: locale,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.scheme,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: TextStyle(fontSize: 13, color: scheme.outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekSummaryCard extends StatelessWidget {
  const _WeekSummaryCard({
    required this.stats,
    required this.s,
    required this.scheme,
  });

  final HabitStats stats;
  final AppStrings s;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final rate = stats.weekRate;
    final percent = rate == null ? null : (rate * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  s.thisWeek,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _RateValue(
                    percent: percent,
                    label: s.routineRespected,
                    scheme: scheme,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CountPill(
                          icon: Icons.check,
                          count: stats.weekDone,
                          label: s.activitiesDone,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 14),
                        _CountPill(
                          icon: Icons.close,
                          count: stats.weekMissed,
                          label: s.activitiesMissed,
                          color: scheme.error,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RateValue extends StatelessWidget {
  const _RateValue({
    required this.percent,
    required this.label,
    required this.scheme,
  });

  final int? percent;
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          percent == null ? '—' : '$percent %',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: scheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: scheme.outline),
        ),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 3),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.days,
    required this.scheme,
    required this.s,
    required this.locale,
  });

  final List<DayStat> days;
  final ColorScheme scheme;
  final AppStrings s;
  final String locale;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          s.noHistory,
          style: TextStyle(fontSize: 13, color: scheme.outline),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            _HistoryRow(stat: days[i], locale: locale, scheme: scheme),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.stat,
    required this.locale,
    required this.scheme,
  });

  final DayStat stat;
  final String locale;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('EEEE d MMMM', locale).format(stat.day);
    final capitalized =
        label.isEmpty ? label : label[0].toUpperCase() + label.substring(1);
    final (icon, color) = switch (stat.status) {
      DayStatus.respected => (Icons.check_circle, scheme.primary),
      DayStatus.partial => (Icons.radio_button_unchecked, Colors.amber.shade700),
      DayStatus.missed => (Icons.cancel, scheme.error),
      DayStatus.neutral => (Icons.remove_circle_outline, scheme.outlineVariant),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              capitalized,
              style: TextStyle(fontSize: 13, color: scheme.onSurface),
            ),
          ),
          Text(
            stat.due == 0 ? '—' : '${stat.done}/${stat.due}',
            style: TextStyle(fontSize: 12, color: scheme.outline),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.days,
    required this.today,
    required this.s,
    required this.scheme,
    required this.locale,
  });

  final List<DayStat> days;
  final DateTime today;
  final AppStrings s;
  final ColorScheme scheme;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final byKey = {for (final d in days) d.dayKey: d};
    final year = today.year;
    final month = today.month;
    final offset = DateTime(year, month, 1).weekday - 1;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final todayKey = Activity.dateKey(today);

    final weekHeaders = [s.mon, s.tue, s.wed, s.thu, s.fri, s.sat, s.sun];

    final totalCells = offset + daysInMonth;
    final rowCount = (totalCells / 7).ceil();
    final grid = <Widget>[];
    for (var i = 0; i < rowCount * 7; i++) {
      final day = i - offset + 1;
      grid.add(
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: (day < 1 || day > daysInMonth)
                ? const SizedBox.shrink()
                : _DayCell(
                    day: day,
                    dayKey: Activity.dateKey(DateTime(year, month, day)),
                    byKey: byKey,
                    isFuture: DateTime(year, month, day).isAfter(today),
                    isToday:
                        Activity.dateKey(DateTime(year, month, day)) == todayKey,
                    scheme: scheme,
                  ),
          ),
        ),
      );
    }

    final monthDone = days.fold(0, (sum, d) => sum + d.done);
    final monthDue = days.fold(0, (sum, d) => sum + d.due);
    final monthRate = monthDue == 0 ? null : monthDone / monthDue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final h in weekHeaders)
              Expanded(
                child: Center(
                  child: Text(
                    h,
                    style: TextStyle(fontSize: 11, color: scheme.outline),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < rowCount; r++)
          Row(children: grid.sublist(r * 7, r * 7 + 7)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _LegendDot(color: scheme.primary, label: s.statusRespected, scheme: scheme),
            _LegendDot(
              color: Colors.amber.shade700,
              label: s.statusPartial,
              scheme: scheme,
            ),
            _LegendDot(color: scheme.error, label: s.statusMissed, scheme: scheme),
            _LegendDot(
              color: scheme.surfaceContainerHighest,
              label: s.statusNeutral,
              scheme: scheme,
            ),
          ],
        ),
        if (monthRate != null) ...[
          const SizedBox(height: 10),
          Text(
            '$monthDone ${s.activitiesDone} · '
            '${monthDue - monthDone} ${s.activitiesMissed} · '
            '${(monthRate * 100).round()} %',
            style: TextStyle(fontSize: 12, color: scheme.outline),
          ),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.dayKey,
    required this.byKey,
    required this.isFuture,
    required this.isToday,
    required this.scheme,
  });

  final int day;
  final String dayKey;
  final Map<String, DayStat> byKey;
  final bool isFuture;
  final bool isToday;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final status = isFuture ? null : (byKey[dayKey]?.status ?? DayStatus.neutral);
    final color = _cellColor(status);
    final textColor = _cellTextColor(status);

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: isToday ? Border.all(color: scheme.primary, width: 1.5) : null,
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Color? _cellColor(DayStatus? status) => switch (status) {
        DayStatus.respected => scheme.primary.withValues(alpha: 0.85),
        DayStatus.partial => Colors.amber.shade700.withValues(alpha: 0.6),
        DayStatus.missed => scheme.error.withValues(alpha: 0.12),
        DayStatus.neutral => scheme.surfaceContainerHighest,
        null => Colors.transparent,
      };

  Color _cellTextColor(DayStatus? status) {
    if (isFuture) return scheme.outline.withValues(alpha: 0.4);
    return switch (status) {
      DayStatus.respected => scheme.onPrimary,
      DayStatus.partial => Colors.white,
      _ => scheme.outline,
    };
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    required this.scheme,
  });

  final Color color;
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
