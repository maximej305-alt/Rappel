import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/activity.dart';
import '../theme/app_typography.dart';

/// Sélecteur de répétition : 4 segments égaux, libellés jamais coupés.
class RepeatSelector extends StatelessWidget {
  const RepeatSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.dense = false,
  });

  final RepeatRule selected;
  final ValueChanged<RepeatRule> onSelected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = context.l10n;
    final entries = [
      (RepeatRule.none, s.once),
      (RepeatRule.daily, s.day),
      (RepeatRule.weekly, s.days),
      (RepeatRule.monthly, s.month),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final (rule, label) in entries)
            Expanded(
              child: _RepeatSegment(
                label: label,
                selected: rule == selected,
                dense: dense,
                onTap: () => onSelected(rule),
              ),
            ),
        ],
      ),
    );
  }
}

class _RepeatSegment extends StatelessWidget {
  const _RepeatSegment({
    required this.label,
    required this.selected,
    required this.dense,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.all(2),
        padding: EdgeInsets.symmetric(
          horizontal: 4,
          vertical: dense ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTypography.captionMd.copyWith(
            fontWeight: AppTypography.w700,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
