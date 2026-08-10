import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/stats_service.dart';

/// Graphique des 7 derniers jours : une barre par jour, colorée selon le
/// statut de la journée (respectée, partielle, manquée, neutre).
/// Source unique de vérité : [StatsCalculator].
class HabitBarChart extends StatelessWidget {
  const HabitBarChart({super.key, required this.days, required this.locale});

  final List<DayStat> days;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 140,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= days.length) {
                    return const SizedBox.shrink();
                  }
                  final day = days[index].day;
                  final labels = locale.startsWith('fr')
                      ? const ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                      : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[day.weekday - 1],
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: _barHeight(days[i]),
                    width: 16,
                    color: _colorFor(days[i].status, scheme),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(DayStatus status, ColorScheme scheme) => switch (status) {
        DayStatus.respected => scheme.primary,
        DayStatus.partial => Colors.amber.shade700,
        DayStatus.missed => scheme.error,
        DayStatus.neutral => scheme.outlineVariant.withValues(alpha: 0.35),
      };

  double _barHeight(DayStat stat) {
    if (stat.status == DayStatus.neutral) return 0;
    // Les jours manqués gardent une amorce visible.
    return stat.rate == 0 ? 5 : stat.rate * 100;
  }
}

/// Carte « Suivi des habitudes » de l'accueil : série + barres 7 jours.
class HabitChart extends StatelessWidget {
  const HabitChart({
    super.key,
    required this.stats,
    required this.locale,
  });

  final HabitStats stats;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = context.l10n;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  s.habitTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              stats.currentStreak > 0
                  ? '${s.habitStreak} : ${stats.currentStreak}'
                  : s.habitEmpty,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            HabitBarChart(days: stats.last7Days, locale: locale),
            const SizedBox(height: 8),
            Text(
              s.habitLast7,
              style: TextStyle(fontSize: 12, color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
