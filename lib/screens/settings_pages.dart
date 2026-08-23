import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/app_strings_ext.dart';
import '../l10n/l10n.dart';
import '../models/activity.dart';
import '../models/app_settings.dart';
import '../models/lock_settings.dart';
import '../models/sound_option.dart';
import '../providers/providers.dart';
import '../services/custom_sound_service.dart';
import '../theme/accent_color.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/dimens.dart';
import '../theme/theme_palette.dart';
import '../utils/dates.dart';
import '../widgets/category_editor_dialog.dart';
import '../widgets/lock_setup.dart';
import '../widgets/sound_picker_sheet.dart';

// ────────────────────────────────────────────────
// Aliases de commodité pour les constantes de dimensions.
// Le projet utilise AppSpacing / AppRadius, pas Dimens.
// ────────────────────────────────────────────────
const double _xs = AppSpacing.xs;
const double _s = AppSpacing.sm;
const double _m = AppSpacing.md2;
const double _l = AppSpacing.xl;
const double _xl = AppSpacing.xxl;

String lockMethodLabel(AppStrings s, LockMethod method) => switch (method) {
  LockMethod.pin => s.pinLabel,
  LockMethod.password => s.passwordLabel,
  LockMethod.pattern => s.patternLabel,
  LockMethod.biometric => s.biometricLabel,
};

/// Page de réglages Apparence (Thème, Palette, Accent, Taille du texte, Police, AMOLED).
class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final palette = ref.watch(paletteProvider);
    final s = ref.watch(stringsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(s.appearanceSettings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: _m, vertical: _s),
        children: [
          // Thème Clair / Sombre / Système
          Card(
            margin: const EdgeInsets.only(bottom: _m),
            child: Padding(
              padding: const EdgeInsets.all(_m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.theme,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: AppTypography.w700,
                    ),
                  ),
                  SizedBox(height: _s),
                  SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(s.themeLight),
                        icon: const Icon(Icons.light_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(s.themeDark),
                        icon: const Icon(Icons.dark_mode),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(s.themeSystem),
                        icon: const Icon(Icons.brightness_auto),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selected) {
                      ref
                          .read(settingsProvider.notifier)
                          .update(settings.copyWith(themeMode: selected.first));
                    },
                  ),
                ],
              ),
            ),
          ),

          // Palette de couleurs
          Card(
            margin: const EdgeInsets.only(bottom: _m),
            child: ListTile(
              title: Text(s.palette),
              subtitle: Text(palette.name.toUpperCase()),
              trailing: const Icon(Icons.palette_outlined),
              onTap: () async {
                final chosen = await showDialog<ThemePalette>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: Text(s.palette),
                    children: [
                      for (final p in ThemePalette.values)
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(ctx, p),
                          child: Text(p.name.toUpperCase()),
                        ),
                    ],
                  ),
                );
                if (chosen != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .update(settings.copyWith(palette: chosen));
                }
              },
            ),
          ),

          // Couleur d'accent (FAB, graphiques)
          Card(
            margin: const EdgeInsets.only(bottom: _m),
            child: ListTile(
              title: Text(s.accent),
              subtitle: Text(settings.accent.displayName),
              trailing: CircleAvatar(
                radius: 12,
                backgroundColor: settings.accent.forBrightness(
                  Theme.of(context).brightness,
                ),
              ),
              onTap: () async {
                final chosen = await showDialog<AccentColor>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: Text(s.accent),
                    children: [
                      for (final a in AccentColor.values)
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(ctx, a),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: a.forBrightness(
                                  Theme.of(context).brightness,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(a.name),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
                if (chosen != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .update(settings.copyWith(accent: chosen));
                }
              },
            ),
          ),

          // AMOLED
          if (themeMode == ThemeMode.dark || themeMode == ThemeMode.system)
            Card(
              margin: const EdgeInsets.only(bottom: _m),
              child: SwitchListTile(
                title: Text(s.amoledMode),
                subtitle: Text(s.amoledHint),
                value: settings.amoled,
                onChanged: (val) {
                  ref
                      .read(settingsProvider.notifier)
                      .update(settings.copyWith(amoled: val));
                },
              ),
            ),

          // Taille du texte
          Card(
            margin: const EdgeInsets.only(bottom: _m),
            child: Padding(
              padding: const EdgeInsets.all(_m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.textSize,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: AppTypography.w700,
                    ),
                  ),
                  SizedBox(height: _xs),
                  Text(
                    s.textSizeHint,
                    style: AppTypography.bodySmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  _TextScaleSlider(
                    initial: settings.textScale,
                    onCommit: (val) {
                      ref
                          .read(settingsProvider.notifier)
                          .update(settings.copyWith(textScale: val));
                    },
                  ),
                ],
              ),
            ),
          ),

          // Police d'écriture
          Card(
            margin: const EdgeInsets.only(bottom: _m),
            child: ListTile(
              title: Text(s.fontFamily),
              subtitle: Text(
                settings.fontFamily == 'System'
                    ? s.fontSystem
                    : AppTheme.fontDisplayName(settings.fontFamily),
              ),
              trailing: const Icon(Icons.font_download_outlined),
              onTap: () async {
                final chosen = await showDialog<String>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: Text(s.fontFamily),
                    children: [
                      for (final family in AppTheme.fontFamilies)
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(ctx, family),
                          child: Text(
                            family == 'System'
                                ? s.fontSystem
                                : AppTheme.fontDisplayName(family),
                          ),
                        ),
                    ],
                  ),
                );
                if (chosen != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .update(settings.copyWith(fontFamily: chosen));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Page de réglages Notifications (Sons, Mode alarme, Rappel avant).
class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final s = ref.watch(stringsProvider);
    final soundOption = SoundOption.fromId(settings.defaultSound);

    return Scaffold(
      appBar: AppBar(title: Text(s.notificationSettings)),
      body: ListView(
        padding: const EdgeInsets.all(_m),
        children: [
          // Mode Alarme
          Card(
            margin: const EdgeInsets.only(bottom: _m),
            child: SwitchListTile(
              title: Text(s.alarmMode),
              subtitle: Text(s.alarmModeHint),
              value: settings.alarmMode,
              onChanged: (val) async {
                final next = settings.copyWith(alarmMode: val);
                await ref.read(settingsProvider.notifier).update(next);
                await rescheduleAllPersisted(
                  ref,
                  reminderOffsetMinutes: next.reminderOffsetMinutes,
                  s: s,
                  alarmMode: val,
                );
              },
            ),
          ),

          // Ignorer « Ne pas déranger » (canaux alarme)
          const _DndTile(),

          // Son par défaut
          Card(
            margin: const EdgeInsets.only(bottom: _m),
            child: ListTile(
              title: Text(s.defaultSound),
              subtitle: Text(soundLabel(soundOption, s)),
              trailing: const Icon(Icons.music_note_outlined),
              onTap: () async {
                final chosen = await showSoundPickerSheet(
                  context,
                  currentId: settings.defaultSound,
                  importCustom: CustomSoundService.pickAndImport,
                );
                if (chosen == null) return;
                final oldDefault = settings.defaultSound;
                final next = settings.copyWith(defaultSound: chosen.id);
                await ref.read(settingsProvider.notifier).update(next);
                // Propager le nouveau son par défaut aux activités qui suivent
                // le défaut (sound 'default' ou l'ancien défaut), puis
                // replanifier pour que le changement sonne réellement.
                final activitiesNotifier = ref.read(
                  activitiesProvider.notifier,
                );
                final updated = <Activity>[];
                for (final a in ref.read(activitiesProvider)) {
                  if (a.sound == 'default' || a.sound == oldDefault) {
                    updated.add(a.copyWith(sound: chosen.id));
                  }
                }
                if (updated.isNotEmpty) {
                  await activitiesNotifier.updateAll(updated);
                }
                await rescheduleAllPersisted(
                  ref,
                  reminderOffsetMinutes: next.reminderOffsetMinutes,
                  s: s,
                  alarmMode: next.alarmMode,
                );
              },
            ),
          ),

          // Rappel en avance
          Card(
            margin: const EdgeInsets.only(bottom: _m),
            child: ListTile(
              title: Text(s.reminderBefore),
              subtitle: Text(
                settings.reminderOffsetMinutes == 0
                    ? s.exactTime
                    : s.reminderMinutes(settings.reminderOffsetMinutes),
              ),
              trailing: const Icon(Icons.timer_outlined),
              onTap: () async {
                final chosen = await showDialog<int>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: Text(s.reminderBefore),
                    children: [
                      for (final opt in AppSettings.reminderOptions)
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(ctx, opt),
                          child: Text(
                            opt == 0 ? s.exactTime : s.reminderMinutes(opt),
                          ),
                        ),
                    ],
                  ),
                );
                if (chosen != null) {
                  final next = settings.copyWith(reminderOffsetMinutes: chosen);
                  await ref.read(settingsProvider.notifier).update(next);
                  await rescheduleAllPersisted(
                    ref,
                    reminderOffsetMinutes: chosen,
                    s: s,
                    alarmMode: next.alarmMode,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Tuile « Ignorer Ne pas déranger » : autorisation d'accès à la politique
/// de notification Android (canaux alarme bypassDnd).
class _DndTile extends ConsumerStatefulWidget {
  const _DndTile();

  @override
  ConsumerState<_DndTile> createState() => _DndTileState();
}

class _DndTileState extends ConsumerState<_DndTile> {
  bool? _access;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  AndroidFlutterLocalNotificationsPlugin? _impl() =>
      FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  Future<void> _refresh() async {
    final access = await _impl()?.hasNotificationPolicyAccess() ?? false;
    if (mounted) setState(() => _access = access);
  }

  Future<void> _toggle() async {
    await _impl()?.requestNotificationPolicyAccess();
    final granted = await _impl()?.hasNotificationPolicyAccess() ?? false;
    if (!mounted) return;
    setState(() => _access = granted);
    if (granted) {
      final s = ref.read(stringsProvider);
      final settings = ref.read(settingsProvider);
      await rescheduleAllPersisted(
        ref,
        reminderOffsetMinutes: settings.reminderOffsetMinutes,
        s: s,
        alarmMode: settings.alarmMode,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: _m),
      child: SwitchListTile(
        title: Text(s.dndIgnore),
        subtitle: Text(s.dndIgnoreHint),
        value: _access ?? false,
        onChanged: (_) => _toggle(),
      ),
    );
  }
}

/// Page de réglages Sécurité (Verrou, PIN, Mot de passe, Motif, Biométrie, Secours).
class SecuritySettingsPage extends ConsumerWidget {
  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockSettings = ref.watch(lockSettingsProvider);
    final s = ref.watch(stringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.securitySettings)),
      body: ListView(
        padding: const EdgeInsets.all(_m),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: _m),
            child: SwitchListTile(
              title: Text(s.lockApp),
              subtitle: Text(lockSettings.enabled ? s.enabled : s.disabled),
              value: lockSettings.enabled,
              onChanged: (val) async {
                // Toute modification d'un verrou existant exige la
                // confirmation du code actuel (désactivation ou changement).
                // L'activation initiale part de zéro : aucune vérification.
                if (lockSettings.enabled) {
                  final verified = await promptLockVerification(
                    ref,
                    context,
                    lockSettings,
                  );
                  if (!verified || !context.mounted) return;
                }
                if (val) {
                  // Choisir la méthode de verrou via un dialog simple.
                  final method = await _pickLockMethod(context, s);
                  if (method == null || !context.mounted) return;
                  final setup = await promptLockSetup(context, method);
                  if (setup != null) {
                    await ref.read(lockSettingsProvider.notifier).update(setup);
                  }
                } else {
                  await ref
                      .read(lockSettingsProvider.notifier)
                      .update(lockSettings.copyWith(enabled: false));
                }
              },
            ),
          ),
          if (lockSettings.enabled)
            Card(
              margin: const EdgeInsets.only(bottom: _m),
              child: ListTile(
                title: Text(s.lockMethodTitle),
                subtitle: Text(lockMethodLabel(s, lockSettings.method)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () async {
                  // Confirme d'abord le code actuel avant de changer de méthode.
                  final verified = await promptLockVerification(
                    ref,
                    context,
                    lockSettings,
                  );
                  if (!verified || !context.mounted) return;
                  final method = await _pickLockMethod(context, s);
                  if (method == null || !context.mounted) return;
                  final setup = await promptLockSetup(context, method);
                  if (setup != null) {
                    await ref.read(lockSettingsProvider.notifier).update(setup);
                  }
                },
              ),
            ),
          if (lockSettings.enabled && lockSettings.method != LockMethod.biometric)
            Card(
              margin: const EdgeInsets.only(bottom: _m),
              child: SwitchListTile(
                title: Text(s.useDeviceFingerprintTitle),
                subtitle: Text(s.useDeviceFingerprintHint),
                value: lockSettings.useDeviceFingerprint,
                secondary: Icon(
                  Icons.fingerprint,
                  color: lockSettings.useDeviceFingerprint
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                onChanged: (val) async {
                  // Activation : vérifier qu'une empreinte existe déjà sur
                  // l'appareil. Sinon, on explique comment en ajouter une
                  // dans les paramètres Android (aucune inscription in-app).
                  if (val) {
                    final ok = await ProviderScope.containerOf(
                      context,
                      listen: false,
                    ).read(biometricServiceProvider).isSupported;
                    if (!context.mounted) return;
                    if (!ok) {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(s.biometricLabel),
                          content: Text(s.noFingerprintEnrolled),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text(s.ok),
                            ),
                          ],
                        ),
                      );
                      return;
                    }
                  }
                  await ref.read(lockSettingsProvider.notifier).update(
                        lockSettings.copyWith(useDeviceFingerprint: val),
                      );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Présente un dialog pour choisir la méthode de verrou.
  /// L'option biométrie est grisée si l'appareil n'a pas de capteur /
  /// aucune empreinte enregistrée.
  Future<LockMethod?> _pickLockMethod(BuildContext context, dynamic s) async {
    final biometricOk = await ProviderScope.containerOf(
      context,
      listen: false,
    ).read(biometricServiceProvider).isSupported;
    if (!context.mounted) return null;
    final title = context.l10n.lockMethodTitle;
    final s = context.l10n;
    return showDialog<LockMethod>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SimpleDialog(
          title: Text(title),
          children: [
            for (final m in LockMethod.values) ...[
              SimpleDialogOption(
                onPressed: biometricOk || m != LockMethod.biometric
                    ? () => Navigator.pop(ctx, m)
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lockMethodLabel(s, m),
                      style: TextStyle(
                        color: biometricOk || m != LockMethod.biometric
                            ? null
                            : scheme.outlineVariant,
                      ),
                    ),
                    if (m == LockMethod.biometric && !biometricOk)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          s.noBiometric,
                          style: TextStyle(fontSize: 12, color: scheme.outline),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Page de réglages Langue (Sélection avec aperçu RTL).
class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final s = ref.watch(stringsProvider);

    final languages = [
      ('fr', s.french, '🇫🇷'),
      ('en', s.english, '🇬🇧'),
      ('es', 'Español', '🇪🇸'),
      ('de', 'Deutsch', '🇩🇪'),
      ('it', 'Italiano', '🇮🇹'),
      ('pt', 'Português', '🇵🇹'),
      ('zh', '中文', '🇨🇳'),
      ('ar', 'العربية (RTL)', '🇸🇦'),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(s.languageSettings)),
      body: ListView(
        padding: const EdgeInsets.all(_m),
        children: [
          for (final (code, name, flag) in languages)
            Card(
              margin: const EdgeInsets.only(bottom: _s),
              child: ListTile(
                leading: Text(flag, style: const TextStyle(fontSize: 24)),
                title: Text(name),
                trailing: settings.locale == code
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () async {
                  await initializeDateFormatting(intlLocale(code));
                  final next = settings.copyWith(locale: code);
                  await ref.read(settingsProvider.notifier).update(next);
                  await rescheduleAllPersisted(
                    ref,
                    reminderOffsetMinutes: next.reminderOffsetMinutes,
                    s: appStringsFor(code),
                    alarmMode: next.alarmMode,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Page de réglages Données (Journal, Réinitialisation).
class DataSettingsPage extends ConsumerWidget {
  const DataSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.dataManagement)),
      body: ListView(
        padding: const EdgeInsets.all(_m),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: _m),
            child: ListTile(
              leading: Icon(
                Icons.privacy_tip_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(s.privacy),
              subtitle: Text(s.offlineHint),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: _m),
            child: ListTile(
              leading: const Icon(Icons.category_outlined),
              title: Text(s.categories),
              subtitle: Text(s.manageCategories),
              onTap: () => showCategoryEditorDialog(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Page À propos (Version, Changelog, Licence).
class AboutSettingsPage extends StatefulWidget {
  const AboutSettingsPage({super.key});

  @override
  State<AboutSettingsPage> createState() => _AboutSettingsPageState();
}

class _AboutSettingsPageState extends State<AboutSettingsPage> {
  String _version = '1.0.0+1';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = '${info.version}+${info.buildNumber}');
      }
    } catch (_) {
      // AppInfo.version() retourne String?; on utilise un repli.
      if (mounted) setState(() => _version = '1.0.0+1');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(s.aboutApp)),
      body: ListView(
        padding: const EdgeInsets.all(_m),
        children: [
          SizedBox(height: _l),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SizedBox(height: _m),
          Center(
            child: Text(
              s.appName,
              style: AppTypography.titleLarge.copyWith(
                fontWeight: AppTypography.w800,
              ),
            ),
          ),
          SizedBox(height: _xs),
          Center(
            child: Text(
              s.versionInfo.replaceAll('{version}', _version),
              style: AppTypography.bodyMedium.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(height: _xl),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(_m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.changelogTitle,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: AppTypography.w700,
                    ),
                  ),
                  const Divider(),
                  Text(
                    s.aboutChangelog,
                    style: AppTypography.bodyMedium.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Curseur de taille de texte : pendant le glisser, seule la valeur affichée
/// localement change (setState local, pas de rebuild global). Les réglages
/// (thème + MediaQuery de l'app entière) ne sont commités qu'à la fin du
/// glisser — le drag ne refait plus tout le layout de l'application par tick.
class _TextScaleSlider extends StatefulWidget {
  const _TextScaleSlider({required this.initial, required this.onCommit});

  final double initial;
  final ValueChanged<double> onCommit;

  @override
  State<_TextScaleSlider> createState() => _TextScaleSliderState();
}

class _TextScaleSliderState extends State<_TextScaleSlider> {
  late double _value = widget.initial;
  bool _dragging = false;

  @override
  void didUpdateWidget(_TextScaleSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial != widget.initial && !_dragging) {
      _value = widget.initial;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Slider(
      value: _value,
      min: 0.85,
      max: 1.5,
      divisions: 4,
      label: '${(_value * 100).round()}%',
      onChangeStart: (_) => setState(() => _dragging = true),
      onChanged: (val) => setState(() => _value = val),
      onChangeEnd: (val) {
        setState(() {
          _dragging = false;
          _value = val;
        });
        widget.onCommit(val);
      },
    );
  }
}
