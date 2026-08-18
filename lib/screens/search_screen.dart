import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../l10n/l10n.dart';
import '../models/activity.dart';
import '../models/activity_priority.dart';
import '../models/category.dart';
import '../providers/providers.dart';
import '../theme/app_typography.dart';
import '../theme/dimens.dart';
import '../utils/activity_search.dart';
import '../widgets/activity_tile.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/filter_sheet.dart';
import 'add_activity_screen.dart';

/// Recherche globale : saisie (nom + catégorie, insensible à la casse et aux
/// accents) combinable avec des filtres. L'état (requête + filtres) est local
/// à cet écran et n'est jamais persisté.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  ActivityFilter _filter = const ActivityFilter();

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = value);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _query = '');
  }

  void _clearAll() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _query = '';
      _filter = const ActivityFilter();
    });
  }

  Future<void> _openFilters() async {
    await showFilterSheet(
      context,
      current: _filter,
      categories: ref.read(categoriesProvider),
      onChanged: (filter) => setState(() => _filter = filter),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activities = ref.watch(activitiesProvider);
    final categories = ref.watch(categoriesProvider);
    final s = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();

    final results = filterActivities(
      activities: activities,
      categories: categories,
      query: _query,
      filter: _filter,
      now: today,
      s: s,
    );

    final searching = _query.trim().isNotEmpty || _filter.isActive;

    return Scaffold(
      appBar: AppBar(title: Text(s.searchTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.xs,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    onChanged: _onQueryChanged,
                    textInputAction: TextInputAction.search,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: AppTypography.w400,
                    ),
                    decoration: InputDecoration(
                      hintText: s.searchHint,
                      hintStyle: AppTypography.titleSmall.copyWith(
                        fontWeight: AppTypography.w400,
                        color: scheme.outline,
                      ),
                      prefixIcon: Icon(Icons.search, color: scheme.outline),
                      suffixIcon: _query.trim().isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: s.clearSearch,
                              color: scheme.outline,
                              onPressed: _clearSearch,
                            ),
                      filled: true,
                      fillColor:
                          scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: _openFilters,
                  tooltip: s.filters,
                  icon: Badge(
                    isLabelVisible: _filter.activeCount > 0,
                    label: Text('${_filter.activeCount}'),
                    child: const Icon(Icons.tune),
                  ),
                ),
              ],
            ),
          ),
          if (_filter.isActive)
            _buildFilterChips(s, categories),
          Expanded(
            child: searching && results.isEmpty
                ? _buildEmptyState(s)
                : _buildResults(results, today, s),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(AppStrings s, List<Category> categories) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xs,
        ),
        children: [
          if (_filter.date != DateScope.all)
            _chip(
              label: _dateChipLabel(_filter.date, s),
              onDeleted: () => setState(
                () => _filter = _filter.copyWith(date: DateScope.all),
              ),
            ),
          if (_filter.status != StatusFilter.all)
            _chip(
              label: _statusChipLabel(_filter.status, s),
              onDeleted: () => setState(
                () => _filter = _filter.copyWith(status: StatusFilter.all),
              ),
            ),
          if (_filter.priority != null)
            _chip(
              label: _priorityChipLabel(_filter.priority!, s),
              onDeleted: () => setState(
                () => _filter = _filter.copyWith(clearPriority: true),
              ),
            ),
          if (_filter.categoryId != null)
            _chip(
              label: _categoryChipLabel(_filter.categoryId!, categories, s),
              onDeleted: () => setState(
                () => _filter = _filter.copyWith(clearCategory: true),
              ),
            ),
          TextButton(
            onPressed: () => setState(() => _filter = const ActivityFilter()),
            child: Text(s.clearAll),
          ),
        ],
      ),
    );
  }

  Widget _chip({required String label, required VoidCallback onDeleted}) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xsm),
      child: InputChip(
        label: Text(label),
        onDeleted: onDeleted,
        visualDensity: VisualDensity.compact,
        deleteIconColor: Theme.of(context).colorScheme.outline,
      ),
    );
  }

  Widget _buildResults(
    List<Activity> results,
    DateTime today,
    AppStrings s,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final activity = results[index];
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: ActivityTile(
            activity: activity,
            day: today,
            onTap: () => _openEdit(activity),
            onToggle: () => toggleCompletedWithAlarm(ref, activity, today),
            onDelete: () => _deleteActivity(activity, s),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(AppStrings s) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppEmptyState(
            icon: Icons.search_off,
            title: s.noResults,
            hint: s.noResultsHint,
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: _clearAll,
            icon: const Icon(Icons.restart_alt),
            label: Text(s.clearSearchFilters),
          ),
        ],
      ),
    );
  }

  String _dateChipLabel(DateScope scope, AppStrings s) {
    switch (scope) {
      case DateScope.all:
        return s.all;
      case DateScope.today:
        return s.today;
      case DateScope.tomorrow:
        return s.tomorrow;
      case DateScope.thisWeek:
        return s.thisWeek;
    }
  }

  String _statusChipLabel(StatusFilter status, AppStrings s) {
    switch (status) {
      case StatusFilter.all:
        return s.all;
      case StatusFilter.todo:
        return s.statusTodo;
      case StatusFilter.done:
        return s.statusDone;
    }
  }

  String _priorityChipLabel(Priority priority, AppStrings s) {
    switch (priority) {
      case Priority.normal:
        return s.priorityNormal;
      case Priority.important:
        return s.priorityImportant;
      case Priority.urgent:
        return s.priorityUrgent;
    }
  }

  String _categoryChipLabel(
    String categoryId,
    List<Category> categories,
    AppStrings s,
  ) {
    for (final c in categories) {
      if (c.id == categoryId) return c.displayName(s);
    }
    return categoryId;
  }

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
