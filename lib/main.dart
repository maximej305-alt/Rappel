import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'l10n/app_strings_ext.dart';
import 'providers/providers.dart';
import 'screens/lock_gate.dart';
import 'screens/root_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/quick_action_handler.dart';
import 'services/sound_preview_service.dart';
import 'services/storage_service.dart';
import 'services/today_widget_service.dart';
import 'theme/app_theme.dart';
import 'utils/dates.dart';

/// Démarrage : initialise le strict minimum vital (dates locales, stockage
/// chiffré, application des marquages « Terminé » différés), puis affiche
/// immédiatement l'interface. Les initialisations secondaires (fuseau
/// horaire, permissions, replanification des rappels) s'exécutent après la
/// première frame, hors du chemin critique de démarrage.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Stockage chiffré local — indispensable avant tout accès aux données.
  final storage = StorageService();
  await storage.init();

  // Dates localisées : seul le locale utilisateur est nécessaire avant la
  // première frame ; les replis FR/EN sont chargés après, hors chemin
  // critique (gain de démarrage sur appareils anciens).
  final bootLocale = storage.loadSettings().locale;
  await initializeDateFormatting(intlLocale(bootLocale));

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
    // Miroir des widgets d'écran d'accueil : à chaque changement d'activités
    // et au rollover minuit, toutes les données sont réécrites pour les 6
    // widgets (liste, prochaine, progression, série, semaine).
    ref.listenManual(activitiesProvider, (_, next) {
      HomeWidgetSync.updateSource(
        next,
        stats: ref.read(habitStatsProvider),
        letters: _weekLetters(),
      );
    });
    ref.listenManual(todayProvider, (_, _) {
      _syncWidgetsNow();
    });
    // Initialisations secondaires déclenchées après la première frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _secondaryInit());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Réécrit les données de tous les widgets immédiatement.
  void _syncWidgetsNow() {
    HomeWidgetSync.updateSource(
      ref.read(activitiesProvider),
      stats: ref.read(habitStatsProvider),
      letters: _weekLetters(),
    );
  }

  /// Initiales des jours (lun → dim) dans la langue active.
  List<String> _weekLetters() {
    final s = appStringsFor(ref.read(settingsProvider).locale);
    return [s.mon, s.tue, s.wed, s.thu, s.fri, s.sat, s.sun]
        .map((e) => e.substring(0, 1))
        .toList();
  }

  /// Fuseau horaire, permissions et replanification des rappels : hors du
  /// chemin critique du démarrage. En cas d'échec, l'app reste utilisable ;
  /// un changement de réglages replanifie à nouveau.
  Future<void> _secondaryInit() async {
    try {
      // Replis FR/EN pour les formats de date : nécessaires seulement si
      // l'utilisateur change de langue, jamais avant la première frame.
      await initializeDateFormatting('fr_FR');
      await initializeDateFormatting('en_US');
      final notifications = ref.read(notificationServiceProvider);
      await notifications.init(onBackgroundAction: notificationActionCallback);
      final settings = ref.read(settingsProvider);
      // Attendre la fin du chargement Hive avant de replanifier : sans quoi on
      // relit la liste vide initiale et aucun rappel n'est programmé.
      await ref.read(activitiesProvider.notifier).ready;
      // Premier remplissage de tous les widgets avec les données réelles.
      _syncWidgetsNow();
      // Replanification + persistance des IDs réalloués (collisions).
      await rescheduleAllPersisted(
        ref,
        reminderOffsetMinutes: settings.reminderOffsetMinutes,
        s: appStringsFor(settings.locale),
        alarmMode: settings.alarmMode,
      );
      debugPrint(
        '[Rappel] secondaryInit OK, '
        'activities=${ref.read(activitiesProvider).length}',
      );
    } catch (e, st) {
      debugPrint('[Rappel] secondaryInit FAILED: $e\n$st');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Passage en arrière-plan : flush immédiat de toute écriture d'activités
    // en attente (debounce) — un cochage confirmé n'est jamais perdu même si
    // l'OS tue le processus ensuite.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(activitiesProvider.notifier).flushPendingWrite();
    }
    // Libère le lecteur d'aperçu quand l'app est détachée (fin de vie).
    if (state == AppLifecycleState.detached) {
      SoundPreviewService.instance.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final palette = ref.watch(paletteProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: ref.watch(stringsProvider).appName,
      debugShowCheckedModeBanner: false,
      locale: Locale(settings.locale),
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('es'),
        Locale('de'),
        Locale('it'),
        Locale('pt'),
        Locale('zh'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightFor(palette, fontFamily: settings.fontFamily),
      darkTheme: AppTheme.darkFor(palette, amoled: settings.amoled, fontFamily: settings.fontFamily),
      themeMode: themeMode,
      // Échelle de texte : le réglage interne multiplie l'échelle système
      // (accessibilité OS) et reste borné pour éviter les mises en page
      // illisibles ou cassées.
      builder: (context, child) {
        final data = MediaQuery.of(context);
        final systemFactor = data.textScaler.scale(14) / 14;
        final effective = TextScaler.linear(
          (systemFactor * settings.textScale).clamp(0.8, 2.0),
        );
        return MediaQuery(
          data: data.copyWith(textScaler: effective),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _StartGate(),
    );
  }
}

/// Séquence de lancement : splash Rappel+ puis contenu réel (accueil si aucune
/// sécurité, écran de verrouillage sinon — géré par [LockGate]).
class _StartGate extends StatefulWidget {
  const _StartGate();

  @override
  State<_StartGate> createState() => _StartGateState();
}

class _StartGateState extends State<_StartGate> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onDone: () => setState(() => _showSplash = false),
      );
    }
    return const LockGate(child: RootScreen());
  }
}
