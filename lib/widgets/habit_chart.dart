import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../services/stats_service.dart';
import '../theme/app_typography.dart';
import '../utils/dates.dart';

/// Graphique des 7 derniers jours : une barre par jour, colorée selon le
/// statut de la journée (respectée, partielle, manquée, neutre).
/// Source unique de vérité : [StatsCalculator].
class HabitBarChart extends StatelessWidget {
  const HabitBarChart({
    super.key,
    required this.days,
    required this.locale,
    this.accent,
  });

  final List<DayStat> days;
  final String locale;

  /// Couleur d'accent des journées respectées ; `null` = couleur du thème.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlight = accent ?? scheme.primary;

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
                  final label = DateFormat.E(intlLocale(locale)).format(day);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(color: scheme.outline),
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
                    color: _colorFor(days[i].status, scheme, highlight),
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

  Color _colorFor(DayStatus status, ColorScheme scheme, Color highlight) =>
      switch (status) {
        DayStatus.respected => highlight,
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
    this.accent,
  });

  final HabitStats stats;
  final String locale;

  /// Couleur d'accent des journées respectées ; `null` = couleur du thème.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlight = accent ?? scheme.primary;
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
                Icon(Icons.local_fire_department, color: highlight),
                const SizedBox(width: 8),
                Text(
                  s.habitTitle,
                  style: AppTypography.titleSmall.copyWith(
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
              style: AppTypography.bodyMedium.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            HabitBarChart(days: stats.last7Days, locale: locale, accent: accent),
            const SizedBox(height: 8),
            Text(
              s.habitLast7,
              style: AppTypography.caption.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
