import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../models/activity.dart';
import '../models/activity_priority.dart';
import '../models/category.dart';
import '../models/routine.dart';
import '../models/routine_template.dart';
import '../models/sound_option.dart';
import '../providers/providers.dart';
import '../services/custom_sound_service.dart';
import '../services/notification_service.dart';
import '../services/routine_service.dart';
import '../services/sound_preview_service.dart';
import '../theme/app_typography.dart';
import '../utils/dates.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/priority_selector.dart';
import '../widgets/repeat_selector.dart';
import '../widgets/section_header.dart';
import '../widgets/selector_tile.dart';
import '../widgets/sound_picker_sheet.dart';
import 'add_activity_screen.dart';

/// Crée ou modifie une routine et ses activités.
///
/// Les activités existantes restent inchangées : une ligne existante est
/// modifiée via l'écran habituel, jamais en place. L'enregistrement est
/// transactionnel : les notifications sont planifiées AVANT toute
/// persistance, et un échec annule ce qui a été planifié.
class RoutineEditScreen extends ConsumerStatefulWidget {
  const RoutineEditScreen({super.key, this.routine});

  /// Routine à modifier, ou `null` pour une création.
  final Routine? routine;

  @override
  ConsumerState<RoutineEditScreen> createState() => _RoutineEditScreenState();
}

class _RoutineEditScreenState extends ConsumerState<RoutineEditScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late String _icon;
  late List<_ActivityDraft> _rows;

  /// Clé du modèle actuellement appliqué (surbrillance dans le sélecteur).
  String? _selectedTemplateKey;

  /// `true` quand le nom a été rempli automatiquement depuis un modèle :
  /// changer de modèle met alors aussi le nom à jour au lieu de laisser
  /// l'ancien (« Routine du matin » alors qu'on a choisi « Soirée »).
  bool _nameAutoFilled = false;

  bool get _isEditing => widget.routine != null;

  @override
  void initState() {
    super.initState();
    final routine = widget.routine;
    if (routine != null) {
      _nameController.text = routine.name;
      _descriptionController.text = routine.description ?? '';
      _icon = routine.icon;
      final resolved = ref.read(routineActivitiesProvider)[routine.id] ?? [];
      _rows = [
        for (final a in resolved)
          _ActivityDraft(
            existingId: a.id,
            name: a.name,
            hour: a.hour,
            minute: a.minute,
            repeat: a.repeat,
            weekdays: List.of(a.weekdays),
            sound: a.sound,
            date: a.date,
            priority: a.priority,
            categoryId: a.categoryId,
          ),
      ];
    } else {
      _icon = '📋';
      _rows = [];
    }
  }

  @override
  void dispose() {
    SoundPreviewService.instance.stop();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _applyTemplate(RoutineTemplate template) {
    setState(() {
      if (_nameController.text.trim().isEmpty || _nameAutoFilled) {
        _nameController.text = context.l10n.tr(template.key);
        _nameAutoFilled = true;
      }
      _icon = template.icon;
      _selectedTemplateKey = template.key;
      final defaultSound = ref.read(settingsProvider).defaultSound;
      _rows = [
        for (final a in template.activities)
          _ActivityDraft(
            name: context.l10n.tr(a.nameKey),
            hour: a.hour,
            minute: a.minute,
            repeat: RepeatRule.daily,
            weekdays: const [],
            sound: defaultSound,
            date: DateTime.now(),
          ),
      ];
    });
  }

  Future<void> _openActivityEditor({_ActivityDraft? draft}) async {
    final result = await showModalBottomSheet<_ActivityDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _RoutineActivitySheet(
        initial: draft ??
            _ActivityDraft(
              name: '',
              hour: 12,
              minute: 0,
              repeat: RepeatRule.daily,
              weekdays: const [],
              sound: ref.read(settingsProvider).defaultSound,
              date: DateTime.now(),
            ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (draft == null) {
        _rows.add(result);
      } else {
        final index = _rows.indexOf(draft);
        if (index >= 0) _rows[index] = result;
      }
    });
  }

  Future<void> _openExistingActivity(_ActivityDraft row) async {
    final activityId = row.existingId;
    if (activityId == null) return;
    final activity = ref
        .read(activitiesProvider)
        .where((a) => a.id == activityId)
        .firstOrNull;
    if (activity == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddActivityScreen(editingActivity: activity),
      ),
    );
    // Rafraîchit la ligne si l'activité a été modifiée.
    if (mounted) {
      final updated = ref
          .read(activitiesProvider)
          .where((a) => a.id == activityId)
          .firstOrNull;
      if (updated != null) {
        final index = _rows.indexWhere((r) => r.existingId == activityId);
        if (index >= 0) {
          setState(() {
            _rows[index] = _ActivityDraft(
              existingId: updated.id,
              name: updated.name,
              hour: updated.hour,
              minute: updated.minute,
              repeat: updated.repeat,
              weekdays: List.of(updated.weekdays),
              sound: updated.sound,
              date: updated.date,
              priority: updated.priority,
              categoryId: updated.categoryId,
            );
          });
        }
      }
    }
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _rows.length) return;
    setState(() {
      final row = _rows.removeAt(index);
      _rows.insert(target, row);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.routineActivityRequired)),
      );
      return;
    }

    final s = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final offset = ref.read(settingsProvider).reminderOffsetMinutes;
    final notifications = ref.read(notificationServiceProvider);
    final activitiesNotifier = ref.read(activitiesProvider.notifier);
    final routinesNotifier = ref.read(routinesProvider.notifier);
    final current = ref.read(activitiesProvider);
    final used = NotificationService.usedNotificationIds(current);
    final enabled = widget.routine?.active ?? true;

    // 1. Construire les nouvelles activités (IDs de notification uniques).
    final newActivities = RoutineService.buildActivities(
      [
        for (final r in _rows.where((r) => r.existingId == null))
          RoutineActivityDraft(
            name: r.name,
            hour: r.hour,
            minute: r.minute,
            repeat: r.repeat,
            weekdays: r.weekdays,
            sound: r.sound,
            date: r.date,
            priority: r.priority,
            categoryId: r.categoryId,
          ),
      ],
      usedIds: used,
      enabled: enabled,
    );

    // 2. Planifier d'abord : un échec annule tout, rien n'est persisté.
    final scheduled = <Activity>[];
    try {
      for (final a in newActivities) {
        await notifications.scheduleActivity(a,
            reminderOffsetMinutes: offset,
            s: s,
            alarmMode: ref.read(settingsProvider).alarmMode);
        scheduled.add(a);
      }
    } catch (_) {
      for (final a in scheduled) {
        await notifications.cancelActivity(a);
      }
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(s.routineCreationError)),
        );
      }
      return;
    }

    // 3. Persister (rollback des notifications si l'écriture échoue).
    try {
      if (newActivities.isNotEmpty) {
        await activitiesNotifier.addAll(newActivities);
      }

      final aliveIds = {for (final a in current) a.id};
      final newIds = newActivities.map((a) => a.id).toList();
      var newIndex = 0;
      final finalIds = <String>[];
      for (final r in _rows) {
        final existing = r.existingId;
        if (existing != null && aliveIds.contains(existing)) {
          finalIds.add(existing);
        } else if (existing == null) {
          finalIds.add(newIds[newIndex++]);
        }
      }

      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      if (_isEditing) {
        final updated = widget.routine!.copyWith(
          name: name,
          icon: _icon,
          description: description.isEmpty ? null : description,
          activityIds: finalIds,
        );
        await routinesNotifier.update(updated);
      } else {
        final routine = Routine.create(
          name: name,
          icon: _icon,
          description: description.isEmpty ? null : description,
          activityIds: finalIds,
        );
        await routinesNotifier.create(routine);
      }
    } catch (_) {
      for (final a in scheduled) {
        await notifications.cancelActivity(a);
      }
      for (final a in newActivities) {
        await activitiesNotifier.remove(a.id); // rollback si ajout partiel
      }
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(s.routineCreationError)),
        );
      }
      return;
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? s.editRoutine : s.createRoutine),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: s.routineName,
                hintText: s.routineNameHint,
                prefixIcon: const Icon(Icons.view_agenda_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? s.routineNameError : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: s.routineDescription,
                hintText: s.routineDescriptionHint,
                prefixIcon: const Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 20),
            if (!_isEditing) ...[
              SectionHeader.label(s.chooseTemplate),
              const SizedBox(height: 10),
              _TemplatePicker(
                onSelected: _applyTemplate,
                customLabel: s.tmplCustom,
                selectedKey: _selectedTemplateKey,
              ),
              const SizedBox(height: 20),
            ],
            SectionHeader.label(s.routineIcon),
            const SizedBox(height: 6),
            _IconPicker(
              selected: _icon,
              onSelected: (i) => setState(() => _icon = i),
            ),
            const SizedBox(height: 24),
            SectionHeader.label(s.routineActivities),
            const SizedBox(height: 10),
            if (_rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    s.routineActivityRequired,
                    style: AppTypography.bodyMedium.copyWith(
                      color: scheme.outline,
                    ),
                  ),
                ),
              )
            else
              for (var i = 0; i < _rows.length; i++)
                _ActivityRow(
                  draft: _rows[i],
                  canMoveUp: i > 0,
                  canMoveDown: i < _rows.length - 1,
                  onEdit: () => _rows[i].existingId == null
                      ? _openActivityEditor(draft: _rows[i])
                      : _openExistingActivity(_rows[i]),
                  onMoveUp: () => _move(i, -1),
                  onMoveDown: () => _move(i, 1),
                  onDelete: _rows[i].existingId == null
                      ? () => setState(() => _rows.removeAt(i))
                      : null,
                ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openActivityEditor(),
              icon: const Icon(Icons.add),
              label: Text(s.addRoutineActivity),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(_isEditing ? s.saveChanges : s.createRoutine),
            ),
          ],
        ),
      ),
    );
  }
}

// __PART_B__

/// Brouillon d'activité d'une routine (ligne de l'éditeur).
class _ActivityDraft {
  _ActivityDraft({
    this.existingId,
    required this.name,
    required this.hour,
    required this.minute,
    required this.repeat,
    required this.weekdays,
    required this.sound,
    required this.date,
    this.priority = Priority.normal,
    this.categoryId = CategoryPresets.otherId,
  });

  /// Non nul quand la ligne référence une activité déjà enregistrée.
  final String? existingId;
  final String name;
  final int hour;
  final int minute;
  final RepeatRule repeat;
  final List<int> weekdays;
  final String sound;
  final DateTime date;
  final Priority priority;
  final String categoryId;
}

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({
    required this.onSelected,
    required this.customLabel,
    this.selectedKey,
  });

  final ValueChanged<RoutineTemplate> onSelected;
  final String customLabel;

  /// Clé du modèle mis en surbrillance (`null` = aucun).
  final String? selectedKey;

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    // SingleChildScrollView horizontal + Row : un ListView imbriqué dans le
    // ListView vertical de l'écran provoque des conflits de gestes — un tap
    // peut être interprété comme un scroll et la carte ne réagit pas.
    return SizedBox(
      height: 100,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in RoutineTemplate.templates)
              _TemplateCard(
                icon: t.icon,
                label: s.tr(t.key),
                selected: selectedKey == t.key,
                onTap: () => onSelected(t),
              ),
            _TemplateCard(
              icon: '➕',
              label: customLabel,
              selected: selectedKey == 'tmplCustom',
              onTap: () => onSelected(
                const RoutineTemplate(key: 'tmplCustom', icon: '📋', activities: []),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;

  /// Mis en surbrillance quand ce modèle est celui appliqué.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 92,
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer.withValues(alpha: 0.7)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.4),
              width: selected ? 1.6 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.labelXs.copyWith(
                  fontWeight: AppTypography.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final icon in RoutineTemplate.icons)
          InkWell(
            onTap: () => onSelected(icon),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected == icon
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(icon, style: const TextStyle(fontSize: 20)),
            ),
          ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.draft,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onEdit,
    required this.onMoveUp,
    required this.onMoveDown,
    this.onDelete,
  });

  final _ActivityDraft draft;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = formatTime(draft.hour, draft.minute);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  time,
                  style: AppTypography.sectionTitle.copyWith(
                    fontSize: AppTypography.sizeMd,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _repeatLabel(context, draft),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelXs.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              _TinyButton(
                icon: Icons.keyboard_arrow_up,
                tooltip: 'Up',
                onPressed: canMoveUp ? onMoveUp : null,
              ),
              _TinyButton(
                icon: Icons.keyboard_arrow_down,
                tooltip: 'Down',
                onPressed: canMoveDown ? onMoveDown : null,
              ),
              _TinyButton(
                icon: Icons.edit_outlined,
                tooltip: context.l10n.edit,
                onPressed: onEdit,
              ),
              if (onDelete != null)
                _TinyButton(
                  icon: Icons.delete_outline,
                  tooltip: context.l10n.delete,
                  onPressed: onDelete!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _repeatLabel(BuildContext context, _ActivityDraft d) {
    final s = context.l10n;
    switch (d.repeat) {
      case RepeatRule.none:
        return s.once;
      case RepeatRule.daily:
        return s.repeatDaily;
      case RepeatRule.weekly:
        if (d.weekdays.isEmpty) return s.days;
        const short = {
          1: 'mon',
          2: 'tue',
          3: 'wed',
          4: 'thu',
          5: 'fri',
          6: 'sat',
          7: 'sun',
        };
        if (d.weekdays.length == 7) return s.repeatDaily;
        return d.weekdays.map((w) => s.tr(short[w]!)).join(' · ');
      case RepeatRule.monthly:
        return s.monthly;
    }
  }
}

class _TinyButton extends StatelessWidget {
  const _TinyButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      icon: Icon(icon, size: 18, color: scheme.outline),
    );
  }
}

/// Feuille d'édition d'une activité de routine (nom, heure, répétition,
/// jours, date, son). Retourne le brouillon modifié via `Navigator.pop`.
class _RoutineActivitySheet extends ConsumerStatefulWidget {
  const _RoutineActivitySheet({required this.initial});

  final _ActivityDraft initial;

  @override
  ConsumerState<_RoutineActivitySheet> createState() =>
      _RoutineActivitySheetState();
}

class _RoutineActivitySheetState extends ConsumerState<_RoutineActivitySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late TimeOfDay _time;
  late DateTime _date;
  late RepeatRule _repeat;
  late List<int> _weekdays;
  late String _sound;
  late Priority _priority;
  late String _categoryId;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _nameController = TextEditingController(text: d.name);
    _time = TimeOfDay(hour: d.hour, minute: d.minute);
    _date = d.date;
    _repeat = d.repeat;
    _weekdays = List.of(d.weekdays);
    _sound = d.sound;
    _priority = d.priority;
    _categoryId = d.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: context.l10n.chooseActivityTime,
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 5),
      helpText: context.l10n.date,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickSound() async {
    final chosen = await showSoundPickerSheet(
      context,
      currentId: _sound,
      importCustom: CustomSoundService.pickAndImport,
    );
    if (chosen != null && mounted) setState(() => _sound = chosen.id);
  }

  Future<void> _pickCategory() async {
    final chosen =
        await showCategoryPickerSheet(context, currentId: _categoryId);
    if (chosen != null && mounted) setState(() => _categoryId = chosen.id);
  }

  String _categoryValue(BuildContext context) {
    final category = ref.watch(categoryByIdProvider(_categoryId));
    final s = context.l10n;
    return category?.displayName(s) ?? s.categoryOther;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _ActivityDraft(
        name: _nameController.text.trim(),
        hour: _time.hour,
        minute: _time.minute,
        repeat: _repeat,
        weekdays:
            _repeat == RepeatRule.weekly ? List.of(_weekdays) : const [],
        sound: _sound,
        date: _date,
        priority: _priority,
        categoryId: _categoryId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.routineActivityTitle,
                style: AppTypography.titleMediumStrong.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: s.nameLabel,
                  hintText: s.routineActivityNameHint,
                  prefixIcon: const Icon(Icons.edit_note),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? s.nameError : null,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SelectorTile(
                      dense: true,
                      icon: Icons.schedule,
                      title: s.time,
                      value: formatTime(_time.hour, _time.minute),
                      onTap: _pickTime,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_repeat == RepeatRule.none)
                    Expanded(
                      child: SelectorTile(
                        dense: true,
                        icon: Icons.calendar_today,
                        title: s.date,
                        value: _date.localized(s),
                        onTap: _pickDate,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SelectorTile(
                dense: true,
                icon: SoundOption.fromId(_sound).icon,
                title: s.notificationSound,
                value: soundLabel(SoundOption.fromId(_sound), s),
                onTap: _pickSound,
              ),
              const SizedBox(height: 20),
              SectionHeader.label(s.priority),
              const SizedBox(height: 8),
              PrioritySelector(
                selected: _priority,
                onSelected: (p) => setState(() => _priority = p),
              ),
              const SizedBox(height: 12),
              SelectorTile(
                dense: true,
                icon: Icons.label_outline,
                title: s.category,
                value: _categoryValue(context),
                onTap: _pickCategory,
              ),
              const SizedBox(height: 20),
              SectionHeader.label(s.repeat),
              const SizedBox(height: 8),
              RepeatSelector(
                selected: _repeat,
                onSelected: (rule) => setState(() {
                  _repeat = rule;
                  if (rule == RepeatRule.weekly && _weekdays.isEmpty) {
                    _weekdays = [DateTime.now().weekday];
                  }
                }),
              ),
              if (_repeat == RepeatRule.weekly) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 1; i <= 7; i++)
                      FilterChip(
                        label: Text(_weekdayLabel(s, i)),
                        selected: _weekdays.contains(i),
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            if (!_weekdays.contains(i)) _weekdays.add(i);
                          } else {
                            _weekdays.remove(i);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(s.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sélecteur de répétition : 4 segments égaux.
String _weekdayLabel(AppStrings s, int weekday) => switch (weekday) {
      1 => s.mon,
      2 => s.tue,
      3 => s.wed,
      4 => s.thu,
      5 => s.fri,
      6 => s.sat,
      7 => s.sun,
      _ => '',
    };
