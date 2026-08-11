import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/activity_priority.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/dimens.dart';
import '../utils/activity_search.dart';
import 'section_header.dart';

/// Ouvre la feuille de filtres de la recherche.
///
/// Chaque toucher applique immédiatement le filtre via [onChanged] : l'écran
/// de recherche se met à jour en direct derrière la feuille. La feuille est
/// fermée par glissement ou par le bouton de fermeture.
Future<void> showFilterSheet(
  BuildContext context, {
  required ActivityFilter current,
  required List<Category> categories,
  required ValueChanged<ActivityFilter> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _FilterSheet(
      current: current,
      categories: categories,
      onChanged: onChanged,
    ),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.current,
    required this.categories,
    required this.onChanged,
  });

  final ActivityFilter current;
  final List<Category> categories;
  final ValueChanged<ActivityFilter> onChanged;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ActivityFilter _filter = widget.current;

  void _update(ActivityFilter filter) {
    setState(() => _filter = filter);
    widget.onChanged(filter);
  }

  void _clearAll() => _update(const ActivityFilter());

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.filters,
                      style: AppTypography.sectionTitle.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _filter.isActive ? _clearAll : null,
                    icon: const Icon(Icons.filter_alt_off, size: 18),
                    label: Text(s.clearAll),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                children: [
                  _dateSection(s, scheme),
                  _statusSection(s, scheme),
                  _prioritySection(s, scheme),
                  _categorySection(s, scheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateSection(AppStrings s, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader.label(s.filterDate),
        _OptionTile(
          label: s.all,
          selected: _filter.date == DateScope.all,
          onTap: () => _update(_filter.copyWith(date: DateScope.all)),
        ),
        _OptionTile(
          label: s.today,
          selected: _filter.date == DateScope.today,
          onTap: () => _update(_filter.copyWith(date: DateScope.today)),
        ),
        _OptionTile(
          label: s.tomorrow,
          selected: _filter.date == DateScope.tomorrow,
          onTap: () => _update(_filter.copyWith(date: DateScope.tomorrow)),
        ),
        _OptionTile(
          label: s.thisWeek,
          selected: _filter.date == DateScope.thisWeek,
          onTap: () => _update(_filter.copyWith(date: DateScope.thisWeek)),
        ),
      ],
    );
  }

  Widget _statusSection(AppStrings s, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader.label(s.filterStatus),
        _OptionTile(
          label: s.all,
          selected: _filter.status == StatusFilter.all,
          onTap: () => _update(_filter.copyWith(status: StatusFilter.all)),
        ),
        _OptionTile(
          label: s.statusTodo,
          selected: _filter.status == StatusFilter.todo,
          onTap: () => _update(_filter.copyWith(status: StatusFilter.todo)),
        ),
        _OptionTile(
          label: s.statusDone,
          subtitle: s.statusDoneHint,
          selected: _filter.status == StatusFilter.done,
          onTap: () => _update(_filter.copyWith(status: StatusFilter.done)),
        ),
      ],
    );
  }

  Widget _prioritySection(AppStrings s, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader.label(s.filterPriority),
        _OptionTile(
          label: s.all,
          selected: _filter.priority == null,
          onTap: () => _update(_filter.copyWith(clearPriority: true)),
        ),
        _OptionTile(
          label: s.priorityNormal,
          selected: _filter.priority == Priority.normal,
          onTap: () => _update(_filter.copyWith(priority: Priority.normal)),
        ),
        _OptionTile(
          label: s.priorityImportant,
          selected: _filter.priority == Priority.important,
          onTap: () => _update(_filter.copyWith(priority: Priority.important)),
        ),
        _OptionTile(
          label: s.priorityUrgent,
          selected: _filter.priority == Priority.urgent,
          onTap: () => _update(_filter.copyWith(priority: Priority.urgent)),
        ),
      ],
    );
  }

  Widget _categorySection(AppStrings s, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader.label(s.filterCategory),
        _OptionTile(
          label: s.all,
          selected: _filter.categoryId == null,
          onTap: () => _update(_filter.copyWith(clearCategory: true)),
        ),
        for (final category in widget.categories)
          _OptionTile(
            leading: _CategoryAvatar(category: category),
            label: category.displayName(s),
            selected: _filter.categoryId == category.id,
            onTap: () => _update(_filter.copyWith(categoryId: category.id)),
          ),
      ],
    );
  }
}

/// Ligne d'option de filtre : libellé, sous-titre éventuel, coche si sélectionnée.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final Widget? leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      leading: leading,
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.titleSmall.copyWith(
          fontWeight: selected ? AppTypography.w700 : AppTypography.w500,
          color: scheme.onSurface,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: AppTypography.caption.copyWith(color: scheme.outline),
            ),
      trailing: selected
          ? Icon(Icons.check_circle, color: scheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

/// Pastille colorée avec l'émoji de la catégorie (cohérent avec
/// category_picker_sheet).
class _CategoryAvatar extends StatelessWidget {
  const _CategoryAvatar({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.categoryColor(category.colorIndex);
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Text(category.icon, style: const TextStyle(fontSize: 14)),
    );
  }
}
