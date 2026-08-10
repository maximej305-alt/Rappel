import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'l10n/app_strings.dart';
import 'providers/providers.dart';
import 'screens/lock_gate.dart';
import 'screens/root_screen.dart';
import 'services/notification_service.dart';
import 'services/quick_action_handler.dart';
import 'services/sound_preview_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dates en français (et anglais) pour le calendrier et l'interface.
  await initializeDateFormatting('fr_FR');
  await initializeDateFormatting('en_US');

  // Stockage chiffré local.
  final storage = StorageService();
  await storage.init();

  // Notifications locales (permissions + fuseau horaire).
  // Le callback d'arrière-plan gère les actions rapides (Terminé, +5, +10,
  // +30, Demain) sans rouvrir l'application.
  final notifications = NotificationService.instance;
  await notifications.init(onBackgroundAction: notificationActionCallback);

  // Applique les marquages « Terminé » différés par les actions rapides.
  final settings = storage.loadSettings();
  var activities = storage.loadActivities();
  activities = await notifications.applyQueuedCompletion(activities);
  await storage.saveActivities(activities);

  // Reconstruit les rappels depuis les activités enregistrées
  // (applied aussi après un redémarrage ou une réinstallation).
  await notifications.rescheduleAll(
    activities,
    reminderOffsetMinutes: settings.reminderOffsetMinutes,
    s: settings.locale.startsWith('en') ? AppStrings.en : AppStrings.fr,
  );

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
      ],
      child: const RappelPlusApp(),
    ),
  );
}

class RappelPlusApp extends ConsumerStatefulWidget {
  const RappelPlusApp({super.key});

  @override
  ConsumerState<RappelPlusApp> createState() => _RappelPlusAppState();
}

class _RappelPlusAppState extends ConsumerState<RappelPlusApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Libère le lecteur d'aperçu quand l'app est détachée (fin de vie).
    if (state == AppLifecycleState.detached) {
      SoundPreviewService.instance.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: ref.watch(stringsProvider).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const LockGate(child: RootScreen()),
    );
  }
}
