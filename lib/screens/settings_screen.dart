import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_info.dart';
import '../l10n/l10n.dart';
import '../models/app_settings.dart';
import '../models/category.dart';
import '../models/lock_settings.dart';
import '../models/sound_option.dart';
import '../providers/providers.dart';
import '../services/custom_sound_service.dart';
import '../services/sound_preview_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialog.dart';
import '../widgets/category_editor_dialog.dart';
import '../widgets/lock_setup.dart';
import '../widgets/section_header.dart';
import '../widgets/sound_picker_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final v = await AppInfo.version();
    if (mounted) setState(() => _version = v);
  }

  @override
  void dispose() {
    SoundPreviewService.instance.stop();
    super.dispose();
  }

  Future<void> _applySettings(AppSettings next) async {
    final notifier = ref.read(settingsProvider.notifier);
    final previous = ref.read(settingsProvider);
    final s = context.l10n;
    await notifier.update(next);

    if (previous.reminderOffsetMinutes != next.reminderOffsetMinutes) {
      final notifications = ref.read(notificationServiceProvider);
      final activities = ref.read(activitiesProvider);
      await notifications.rescheduleAll(
        activities,
        reminderOffsetMinutes: next.reminderOffsetMinutes,
        s: s,
      );
    }
  }
  Future<void> _pickDefaultSound() async {
    final settings = ref.read(settingsProvider);
    final chosen = await showSoundPickerSheet(
      context,
      currentId: settings.defaultSound,
      importCustom: CustomSoundService.pickAndImport,
    );
    if (chosen == null || !mounted) return;
    await _applySettings(
      ref.read(settingsProvider).copyWith(defaultSound: chosen.id),
    );
  }

  Future<void> _testSound(String soundId) async {
    await SoundPreviewService.instance.play(soundId);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final s = ref.watch(stringsProvider);
    final defaultSound = SoundOption.fromId(settings.defaultSound);

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeader.label(
            s.appearance,
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          ),
          _SectionCard(
            children: [
              _SettingRow(
                icon: Icons.brightness_6,
                title: s.theme,
                subtitle: _themeLabel(settings.themeMode, s),
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: const Icon(Icons.light_mode),
                      label: Text(s.themeLight),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: const Icon(Icons.dark_mode),
                      label: Text(s.themeDark),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (selection) => _applySettings(
                    settings.copyWith(themeMode: selection.first),
                  ),
                ),
              ),
              const Divider(height: 1),
              _SettingRow(
                icon: Icons.language,
                title: s.language,
                subtitle: settings.locale == 'fr' ? s.french : 'English',
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(value: 'fr', label: Text('FR')),
                    ButtonSegment(value: 'en', label: Text('EN')),
                  ],
                  selected: {settings.locale},
                  onSelectionChanged: (selection) =>
                      _applySettings(settings.copyWith(locale: selection.first)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SectionHeader.label(
            s.notifications,
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          ),
          _SectionCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _TileIcon(icon: Icons.volume_up, scheme: scheme),
                title: Text(s.defaultSound),
                subtitle: Text(soundLabel(defaultSound, s)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickDefaultSound,
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _TileIcon(
                  icon: Icons.notifications_active_outlined,
                  scheme: scheme,
                ),
                title: Text(s.reminderBefore),
                subtitle: Text(
                  settings.reminderOffsetMinutes == 0
                      ? s.reminderAtExact
                      : s.reminderMinutes(settings.reminderOffsetMinutes),
                ),
                trailing: DropdownButton<int>(
                  value: settings.reminderOffsetMinutes,
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(16),
                  items: [
                    for (final option in AppSettings.reminderOptions)
                      DropdownMenuItem(
                        value: option,
                        child: Text(
                          option == 0
                              ? s.reminderAtExact
                              : s.reminderMinutes(option),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _applySettings(
                        settings.copyWith(reminderOffsetMinutes: value),
                      );
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _TileIcon(
                  icon: Icons.notification_important,
                  scheme: scheme,
                ),
                title: Text(s.trySound),
                subtitle: Text(s.trySoundHint),
                trailing: IconButton(
                  tooltip: s.test,
                  onPressed: () => _testSound(defaultSound.id),
                  icon: const Icon(Icons.play_circle_fill),
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SectionHeader.label(
            s.categories,
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          ),
          _CategoriesSection(),
          const SizedBox(height: 24),
          SectionHeader.label(
            s.security,
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          ),
          _SecuritySection(),
          const SizedBox(height: 24),
          SectionHeader.label(
            s.privacy,
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          ),
          _SectionCard(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _TileIcon(icon: Icons.lock_outline, scheme: scheme),
                title: Text(s.offline),
                subtitle: Text(s.offlineHint),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              _version == null
                  ? s.appName
                  : '${s.appName} · v$_version',
              style: TextStyle(
                fontSize: 12,
                color: scheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode, AppStrings s) => switch (mode) {
        ThemeMode.light => s.themeLight,
        ThemeMode.dark => s.themeDark,
        ThemeMode.system => s.themeSystem,
      };
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(children: children),
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.icon, required this.scheme});

  final IconData icon;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: scheme.onPrimaryContainer, size: 22),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TileIcon(icon: icon, scheme: scheme),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: scheme.outline),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: child),
        ],
      ),
    );
  }
}

/// Section « Sécurité » : interrupteur de verrouillage + méthode active.
class _SecuritySection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends ConsumerState<_SecuritySection> {
  bool _biometricSupported = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final ok = await ref.read(biometricServiceProvider).isSupported;
    if (mounted) setState(() => _biometricSupported = ok);
  }

  Future<void> _onSwitch(bool enabled) async {
    final lock = ref.read(lockSettingsProvider);
    if (!enabled) {
      if (lock.enabled) {
        final ok = await promptLockVerification(ref, context, lock);
        if (!ok || !mounted) return;
      }
      await ref
          .read(lockSettingsProvider.notifier)
          .update(const LockSettings(enabled: false));
      return;
    }

    final method = await _pickMethod();
    if (method == null || !mounted) return;

    if (method == LockMethod.biometric && !_biometricSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.noBiometric)),
      );
      return;
    }

    final setup = await promptLockSetup(context, method);
    if (setup == null || !mounted) return;
    await ref.read(lockSettingsProvider.notifier).update(setup);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.lockActivated)),
    );
  }

  Future<LockMethod?> _pickMethod() async {
    final scheme = Theme.of(context).colorScheme;
    final s = context.l10n;
    final methods = [
      if (_biometricSupported) LockMethod.biometric,
      ...LockMethod.values.where((m) => m != LockMethod.biometric),
    ];
    return showModalBottomSheet<LockMethod>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                s.lockMethodTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ),
            for (final method in methods)
              ListTile(
                leading: Icon(_methodIcon(method), color: scheme.primary),
                title: Text(_methodLabel(method, s)),
                subtitle: Text(_methodHint(method, s)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pop(method),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeMethod() async {
    final lock = ref.read(lockSettingsProvider);
    final ok = await promptLockVerification(ref, context, lock);
    if (!ok || !mounted) return;
    final method = await _pickMethod();
    if (method == null || method == lock.method || !mounted) return;
    final setup = await promptLockSetup(context, method);
    if (setup == null || !mounted) return;
    await ref
        .read(lockSettingsProvider.notifier)
        .update(setup.copyWith(useBiometric: lock.useBiometric));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${context.l10n.methodChanged} — ${_methodLabel(method, context.l10n)}',
        ),
      ),
    );
  }

  Future<void> _changeCode() async {
    final lock = ref.read(lockSettingsProvider);
    final ok = await promptLockVerification(ref, context, lock);
    if (!ok || !mounted) return;
    final setup = await promptLockSetup(context, lock.method);
    if (setup == null || !mounted) return;
    await ref
        .read(lockSettingsProvider.notifier)
        .update(setup.copyWith(useBiometric: lock.useBiometric));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.codeUpdated)),
    );
  }

  IconData _methodIcon(LockMethod method) => switch (method) {
        LockMethod.pin => Icons.pin_outlined,
        LockMethod.password => Icons.key_outlined,
        LockMethod.pattern => Icons.gesture,
        LockMethod.biometric => Icons.fingerprint,
      };

  String _methodLabel(LockMethod method, AppStrings s) => switch (method) {
        LockMethod.pin => s.pinLabel,
        LockMethod.password => s.passwordLabel,
        LockMethod.pattern => s.patternLabel,
        LockMethod.biometric => s.biometricLabel,
      };

  String _methodHint(LockMethod method, AppStrings s) => switch (method) {
        LockMethod.pin => s.pinHint,
        LockMethod.password => s.passwordHint,
        LockMethod.pattern => s.patternHint,
        LockMethod.biometric => s.biometricHint,
      };

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(lockSettingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final s = context.l10n;

    return _SectionCard(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: _TileIcon(
            icon: lock.enabled ? Icons.lock : Icons.lock_open_outlined,
            scheme: scheme,
          ),
          title: Text(s.lockApp),
          subtitle: Text(
            lock.enabled
                ? s.lockMethod(_methodLabel(lock.method, s))
                : s.lockDisabled,
          ),
          value: lock.enabled,
          onChanged: _onSwitch,
        ),
        if (lock.enabled) ...[
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: _TileIcon(icon: Icons.swap_horiz, scheme: scheme),
            title: Text(s.changeMethod),
            subtitle: Text(_methodLabel(lock.method, s)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _changeMethod,
          ),
          if (lock.method != LockMethod.biometric) ...[
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _TileIcon(icon: Icons.edit_outlined, scheme: scheme),
              title: Text(s.modifyCode),
              trailing: const Icon(Icons.chevron_right),
              onTap: _changeCode,
            ),
          ],
          if (_biometricSupported) ...[
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: _TileIcon(icon: Icons.fingerprint, scheme: scheme),
              title: Text(s.unlockFingerprint),
              subtitle: Text(s.unlockFingerprintHint),
              value: lock.useBiometric,
              onChanged: (v) => ref
                  .read(lockSettingsProvider.notifier)
                  .update(lock.copyWith(useBiometric: v)),
            ),
          ],
        ],
      ],
    );
  }
}

/// Section « Catégories » : liste des catégories avec compteur d'activités,
/// création, renommage, édition et suppression (avec réassignation vers
/// « Autre »). Les catégories intégrées sont fixes (noms traduits) et ne
/// peuvent être ni modifiées ni supprimées.
class _CategoriesSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;
    final categories = ref.watch(categoriesProvider);
    final activities = ref.watch(activitiesProvider);

    final counts = <String, int>{};
    for (final a in activities) {
      counts[a.categoryId] = (counts[a.categoryId] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          children: [
            for (final c in categories) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _CategoryAvatar(category: c),
                title: Text(
                  c.displayName(s),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(s.activitiesLabel(counts[c.id] ?? 0)),
                trailing: c.builtin
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: s.edit,
                            onPressed: () => _editCategory(ref, context, c),
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: scheme.outline,
                            ),
                          ),
                          IconButton(
                            tooltip: s.delete,
                            onPressed: () => _deleteCategory(ref, context, c),
                            icon: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: scheme.outline,
                            ),
                          ),
                        ],
                      ),
              ),
              const Divider(height: 1),
            ],
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => _createCategory(ref, context),
              icon: const Icon(Icons.add),
              label: Text(s.newCategory),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _createCategory(WidgetRef ref, BuildContext context) async {
    final data =
        await showCategoryEditorDialog(context, title: context.l10n.newCategory);
    if (data == null || !context.mounted) return;
    final category = Category.create(
      name: data.name,
      icon: data.icon,
      colorIndex: data.colorIndex,
    );
    await ref.read(categoriesProvider.notifier).create(category);
  }

  Future<void> _editCategory(
      WidgetRef ref, BuildContext context, Category category) async {
    final s = context.l10n;
    final data = await showCategoryEditorDialog(
      context,
      initialName: category.displayName(s),
      initialIcon: category.icon,
      initialColorIndex: category.colorIndex,
      title: s.editCategory,
    );
    if (data == null || !context.mounted) return;

    // Les catégories intégrées sont fixes : seule une édition n'a pas lieu
    // d'être ici (l'UI ne les affiche pas), garde défensive pour la clarté.
    if (category.builtin) return;

    final next = category.copyWith(
      name: data.name.trim(),
      icon: data.icon,
      colorIndex: data.colorIndex,
    );
    await ref.read(categoriesProvider.notifier).update(next);
  }

  Future<void> _deleteCategory(
      WidgetRef ref, BuildContext context, Category category) async {
    if (category.isFallback) return; // la catégorie de repli n'est jamais supprimable
    final s = context.l10n;
    final activities = ref.read(activitiesProvider);
    final affected =
        activities.where((a) => a.categoryId == category.id).toList();

    final ok = await showConfirmDialog(
      context,
      title: s.deleteCategoryTitle,
      body: s.deleteCategoryBody(category.displayName(s), affected.length),
      confirmLabel: s.delete,
    );
    if (ok != true || !context.mounted) return;

    // 1. Réassigner puis sauver les activités (avant la suppression).
    if (affected.isNotEmpty) {
      final reassigned = [
        for (final a in affected)
          a.copyWith(categoryId: CategoryPresets.otherId),
      ];
      await ref.read(activitiesProvider.notifier).updateAll(reassigned);
    }
    // 2. Supprimer puis sauver les catégories.
    await ref.read(categoriesProvider.notifier).delete(category.id);
  }
}

/// Pastille colorée avec l'émoji de la catégorie.
class _CategoryAvatar extends StatelessWidget {
  const _CategoryAvatar({required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.categoryColor(category.colorIndex);
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Text(category.icon, style: const TextStyle(fontSize: 17)),
    );
  }
}
