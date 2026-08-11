import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../models/activity.dart';
import '../models/activity_priority.dart';
import '../models/category.dart';
import '../models/sound_option.dart';
import '../providers/providers.dart';
import '../theme/app_typography.dart';

class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.activity,
    required this.day,
    required this.onToggle,
    required this.onDelete,
    this.onTap,
  });

  final Activity activity;
  final DateTime day;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final completed = activity.isCompletedOn(day);
    final muted = !activity.enabled;
    final time =
        '${activity.hour.toString().padLeft(2, '0')}:${activity.minute.toString().padLeft(2, '0')}';

    final subtitle = muted ? context.l10n.remindersOff : _repeatLabel(context);
    final priorityColor = switch (activity.priority) {
      Priority.normal => null,
      Priority.important => Theme.of(context).colorScheme.tertiary,
      Priority.urgent => Theme.of(context).colorScheme.error,
    };
    final urgent = activity.priority == Priority.urgent;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              // Heure : case fixe et alignée.
              SizedBox(
                width: 58,
                height: 44,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: completed
                              ? scheme.primaryContainer.withValues(alpha: 0.7)
                              : scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          time,
                          style: AppTypography.sectionTitle.copyWith(
                            fontSize: AppTypography.sizeBase,
                            letterSpacing: 0.2,
                            color: completed
                                ? scheme.onPrimaryContainer
                                : scheme.primary,
                          ),
                        ),
                      ),
                    ),
                    // Indicateur discret de priorité (aucun si normale).
                    if (priorityColor != null)
                      Positioned(
                        top: urgent ? 5 : 6,
                        right: urgent ? 5 : 6,
                        child: Container(
                          width: urgent ? 11 : 8,
                          height: urgent ? 11 : 8,
                          decoration: BoxDecoration(
                            color: priorityColor,
                            shape: BoxShape.circle,
                            boxShadow: urgent
                                ? [
                                    BoxShadow(
                                      color:
                                          priorityColor.withValues(alpha: 0.45),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Nom + libellé.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall.copyWith(
                        letterSpacing: -0.2,
                        decoration:
                            completed ? TextDecoration.lineThrough : null,
                        decorationColor: scheme.outline,
                        color: completed || muted
                            ? scheme.outline
                            : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        // Icône de catégorie (masquée pour « Autre »).
                        if (activity.categoryId != CategoryPresets.otherId)
                          _CategoryIcon(categoryId: activity.categoryId),
                        if (activity.categoryId != CategoryPresets.otherId)
                          const SizedBox(width: 5),
                        Icon(
                          SoundOption.fromId(activity.sound).icon,
                          size: 13,
                          color: scheme.outline,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: scheme.outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions.
              SizedBox(
                width: 44,
                height: 44,
                child: Checkbox(
                  value: completed,
                  onChanged: (_) => onToggle(),
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: scheme.outline,
                  ),
                  tooltip: context.l10n.delete,
                  onPressed: onDelete,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _repeatLabel(BuildContext context) {
    final s = context.l10n;
    switch (activity.repeat) {
      case RepeatRule.none:
        return s.once;
      case RepeatRule.daily:
        return s.repeatDaily;
      case RepeatRule.weekly:
        if (activity.weekdays.length == 7) return s.repeatDaily;
        if (activity.weekdays.length == 1) {
          const full = {
            1: 'monday',
            2: 'tuesday',
            3: 'wednesday',
            4: 'thursday',
            5: 'friday',
            6: 'saturday',
            7: 'sunday',
          };
          return s.tr(full[activity.weekdays.first]!);
        }
        const short = {
          1: 'mon',
          2: 'tue',
          3: 'wed',
          4: 'thu',
          5: 'fri',
          6: 'sat',
          7: 'sun',
        };
        final days =
            activity.weekdays.map((w) => s.tr(short[w]!)).join(' · ');
        return days;
      case RepeatRule.monthly:
        return s.monthly;
    }
  }
}

/// Petite icône (émoji) de la catégorie, masquée si la catégorie n'existe plus.
class _CategoryIcon extends ConsumerWidget {
  const _CategoryIcon({required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(categoryByIdProvider(categoryId));
    final icon = category?.icon;
    if (icon == null || icon.isEmpty) return const SizedBox.shrink();
    return Text(icon, style: const TextStyle(fontSize: 13));
  }
}
