import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/activity_priority.dart';

/// Sélecteur de priorité : 3 segments (Normal, Important, Urgent).
class PrioritySelector extends StatelessWidget {
  const PrioritySelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final Priority selected;
  final ValueChanged<Priority> onSelected;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<Priority>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [
          ButtonSegment(
            value: Priority.normal,
            label: Text(s.priorityNormal),
          ),
          ButtonSegment(
            value: Priority.important,
            label: Text(s.priorityImportant),
          ),
          ButtonSegment(
            value: Priority.urgent,
            label: Text(s.priorityUrgent),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (sel) => onSelected(sel.first),
      ),
    );
  }
}
