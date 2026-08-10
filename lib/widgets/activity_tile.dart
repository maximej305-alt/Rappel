import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/activity.dart';
import '../models/sound_option.dart';

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

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              // Heure : case fixe et alignée.
              Container(
                width: 58,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: completed
                      ? scheme.primaryContainer.withValues(alpha: 0.7)
                      : scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: completed
                        ? scheme.onPrimaryContainer
                        : scheme.primary,
                  ),
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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
                            style: TextStyle(
                              fontSize: 12,
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
                width: 38,
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
