import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../models/activity.dart';
import '../models/activity_priority.dart';
import '../models/category.dart';
import '../models/sound_option.dart';
import '../providers/providers.dart';
import '../services/custom_sound_service.dart';
import '../services/notification_service.dart';
import '../services/sound_preview_service.dart';
import '../utils/dates.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/priority_selector.dart';
import '../widgets/repeat_selector.dart';
import '../widgets/section_header.dart';
import '../widgets/selector_tile.dart';
import '../widgets/sound_picker_sheet.dart';

class AddActivityScreen extends ConsumerStatefulWidget {
  const AddActivityScreen({super.key, this.editingActivity});

  final Activity? editingActivity;

  @override
  ConsumerState<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends ConsumerState<AddActivityScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late TimeOfDay _time;
  late DateTime _date;
  late RepeatRule _repeat;
  late List<int> _weekdays;
  late String _sound;
  late bool _enabled;
  late Priority _priority;
  late String _categoryId;

  bool get _isEditing => widget.editingActivity != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editingActivity;
    if (editing != null) {
      _time = TimeOfDay(hour: editing.hour, minute: editing.minute);
      _date = editing.date;
      _repeat = editing.repeat;
      _weekdays = List.of(editing.weekdays);
      _sound = editing.sound;
      _enabled = editing.enabled;
      _priority = editing.priority;
      _categoryId = editing.categoryId;
      _nameController.text = editing.name;
    } else {
      _time = const TimeOfDay(hour: 12, minute: 0);
      _date = DateTime.now();
      _repeat = RepeatRule.daily;
      _weekdays = [DateTime.now().weekday];
      _sound = ref.read(settingsProvider).defaultSound;
      _enabled = true;
      _priority = Priority.normal;
      _categoryId = CategoryPresets.otherId;
    }
  }

  @override
  void dispose() {
    SoundPreviewService.instance.stop();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: context.l10n.time,
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
    final chosen = await showCategoryPickerSheet(context, currentId: _categoryId);
    if (chosen != null && mounted) setState(() => _categoryId = chosen.id);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_repeat == RepeatRule.weekly && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.chooseOneWeekday)),
      );
      return;
    }

    final name = _nameController.text.trim();
    final offset = ref.read(settingsProvider).reminderOffsetMinutes;
    final notifier = ref.read(activitiesProvider.notifier);
    final notifications = ref.read(notificationServiceProvider);
    final s = context.l10n;

    if (_isEditing) {
      final others = ref
          .read(activitiesProvider)
          .where((a) => a.id != widget.editingActivity!.id)
          .toList();
      final updated = NotificationService.ensureUniqueNotificationId(
        widget.editingActivity!.copyWith(
          name: name,
          hour: _time.hour,
          minute: _time.minute,
          date: _date,
          repeat: _repeat,
          weekdays: _repeat == RepeatRule.weekly ? List.of(_weekdays) : null,
          sound: _sound,
          enabled: _enabled,
          priority: _priority,
          categoryId: _categoryId,
        ),
        others,
      );
      await notifications.cancelActivity(widget.editingActivity!);
      await notifications.scheduleActivity(updated,
          reminderOffsetMinutes: offset,
          s: s,
          alarmMode: ref.read(settingsProvider).alarmMode);
      await notifier.update(updated);
    } else {
      final weekdays =
          _repeat == RepeatRule.weekly ? List.of(_weekdays) : const <int>[];
      final activity = Activity.create(
        name: name,
        hour: _time.hour,
        minute: _time.minute,
        date: _date,
        repeat: _repeat,
        weekdays: weekdays,
        sound: _sound,
        enabled: _enabled,
        priority: _priority,
        categoryId: _categoryId,
        notificationId: NotificationService.allocateFreshId(
          NotificationService.usedNotificationIds(
              ref.read(activitiesProvider)),
          repeat: _repeat,
          weekdays: weekdays,
        ),
      );
      await notifications.scheduleActivity(activity,
          reminderOffsetMinutes: offset,
          s: s,
          alarmMode: ref.read(settingsProvider).alarmMode);
      await notifier.add(activity);
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final category = ref.watch(categoryByIdProvider(_categoryId));
    final categoryValue = category?.displayName(s) ?? s.categoryOther;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? s.editActivity : s.newActivity),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // Nom de l'activité.
            TextFormField(
              controller: _nameController,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: s.nameLabel,
                hintText: s.nameHint,
                prefixIcon: const Icon(Icons.edit_note),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? s.nameError : null,
            ),
            const SizedBox(height: 16),
            // Heure + Date côte à côte.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectorTile(
                    icon: Icons.schedule,
                    title: s.time,
                    value: formatTime(_time.hour, _time.minute),
                    onTap: _pickTime,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectorTile(
                    icon: Icons.calendar_today,
                    title: s.date,
                    value: _date.localized(s),
                    onTap: _pickDate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Son de notification.
            SelectorTile(
              icon: SoundOption.fromId(_sound).icon,
              title: s.notificationSound,
              value: soundLabel(SoundOption.fromId(_sound), s),
              onTap: _pickSound,
            ),
            const SizedBox(height: 24),
            SectionHeader.label(s.priority),
            const SizedBox(height: 10),
            PrioritySelector(
              selected: _priority,
              onSelected: (p) => setState(() => _priority = p),
            ),
            const SizedBox(height: 12),
            SelectorTile(
              icon: Icons.label_outline,
              title: s.category,
              value: categoryValue,
              onTap: _pickCategory,
            ),
            const SizedBox(height: 24),
            SectionHeader.label(s.repeat),
            const SizedBox(height: 10),
            RepeatSelector(
              selected: _repeat,
              onSelected: (rule) => setState(() {
                _repeat = rule;
                if (_repeat == RepeatRule.weekly && _weekdays.isEmpty) {
                  _weekdays = [DateTime.now().weekday];
                }
              }),
            ),
            if (_repeat == RepeatRule.weekly) ...[
              const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            // Rappels activés.
            Card(
              child: SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                title: Text(s.remindersEnabled),
                subtitle: Text(_enabled ? s.remindersOn : s.remindersOff),
                secondary: Icon(
                  _enabled
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  color: _enabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(_isEditing ? s.saveChanges : s.save),
            ),
          ],
        ),
      ),
    );
  }

  static String _weekdayLabel(AppStrings s, int weekday) => switch (weekday) {
        1 => s.mon,
        2 => s.tue,
        3 => s.wed,
        4 => s.thu,
        5 => s.fri,
        6 => s.sat,
        7 => s.sun,
        _ => '',
      };
}

/// Libellé de section (ex. « Répétition »).
extension DateFormatShort on DateTime {
  String localized(AppStrings s) {
    final now = DateTime.now();
    if (year == now.year && month == now.month && day == now.day) {
      return s.today;
    }
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (year == tomorrow.year &&
        month == tomorrow.month &&
        day == tomorrow.day) {
      return s.tomorrow;
    }
    final yy = (year % 100).toString().padLeft(2, '0');
    return '${day.toString().padLeft(2, '0')}/'
        '${month.toString().padLeft(2, '0')}/$yy';
  }
}
