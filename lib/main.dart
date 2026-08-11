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

/// Démarrage : initialise le strict minimum vital (dates locales, stockage
/// chiffré, application des marquages « Terminé » différés), puis affiche
/// immédiatement l'interface. Les initialisations secondaires (fuseau
/// horaire, permissions, replanification des rappels) s'exécutent après la
/// première frame, hors du chemin critique de démarrage.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dates en français (et anglais) pour le calendrier et l'interface.
  // Chargement en mémoire, rapide et indispensable avant le premier rendu.
  await initializeDateFormatting('fr_FR');
  await initializeDateFormatting('en_US');

  // Stockage chiffré local — indispensable avant tout accès aux données.
  final storage = StorageService();
  await storage.init();

  // Répertoire du journal des actions rapides + application des marquages
  // « Terminé » différés (cohérence des données) : doivent précéder
  // l'affichage pour que l'état soit juste dès la première frame.
  final notifications = NotificationService.instance;
  await notifications.initJournalDir();
  var activities = storage.loadActivities();
  activities = await notifications.applyQueuedCompletion(activities);
  await storage.saveActivities(activities);

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
    // Initialisations secondaires déclenchées après la première frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _secondaryInit());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Fuseau horaire, permissions et replanification des rappels : hors du
  /// chemin critique du démarrage. En cas d'échec, l'app reste utilisable ;
  /// un changement de réglages replanifie à nouveau.
  Future<void> _secondaryInit() async {
    try {
      final notifications = ref.read(notificationServiceProvider);
      await notifications.init(onBackgroundAction: notificationActionCallback);
      final settings = ref.read(settingsProvider);
      final activities = ref.read(activitiesProvider);
      await notifications.rescheduleAll(
        activities,
        reminderOffsetMinutes: settings.reminderOffsetMinutes,
        s: settings.locale.startsWith('en') ? AppStrings.en : AppStrings.fr,
      );
    } catch (_) {
      // Les notifications restent inactives jusqu'au prochain appel ;
      // l'interface n'est pas bloquée pour autant.
    }
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
