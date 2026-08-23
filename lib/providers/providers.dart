import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'dart:async';

import '../l10n/app_strings.dart';
import '../l10n/app_strings_ext.dart';
import '../models/activity.dart';
import '../models/app_settings.dart';
import '../models/category.dart';
import '../models/lock_settings.dart';
import '../models/routine.dart';
import '../services/clock_service.dart';
import '../services/custom_sound_service.dart';
import '../services/notification_service.dart';
import '../services/stats_service.dart';
import '../services/storage_service.dart';
import '../theme/accent_color.dart';
import '../theme/theme_palette.dart';
import '../utils/activity_sort.dart';

/// Provider remplacé dans `main.dart` après initialisation du stockage.
final storageServiceProvider = Provider<StorageService>(
  (ref) => throw UnimplementedError('storageServiceProvider doit être injecté'),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService.instance,
);

/// Horloge centrale : émet la clé du jour courant et bascule automatiquement
/// à minuit (rollover). Tout provider qui dépend de [todayProvider] se
/// recalcule alors — plus besoin de relancer l'application à minuit.
class TodayNotifier extends StateNotifier<String> {
  TodayNotifier(this._clock) : super(_clock.todayKey()) {
    _schedule();
  }

  final Clock _clock;
  Timer? _timer;

  void _schedule() {
    _timer?.cancel();
    final now = _clock.now();
    final nextMidnight = DayKey.normalize(now.add(const Duration(days: 1)));
    _timer = Timer(nextMidnight.difference(now), () {
      state = _clock.todayKey();
      _schedule();
    });
    // Filet de sécurité : si l'horloge système change (NTP, voyage, réglage
    // manuel), le timer vers « l'ancien » prochain minuit peut tarder des
    // heures. Une vérification chaque minute rattrape tout décalage à un
    // coût négligeable (comparaison de deux chaînes).
    _driftCheck?.cancel();
    _driftCheck = Timer.periodic(const Duration(minutes: 1), (_) {
      final key = _clock.todayKey();
      if (key != state) state = key;
    });
  }

  Timer? _driftCheck;

  @override
  void dispose() {
    _timer?.cancel();
    _driftCheck?.cancel();
    super.dispose();
  }
}

final todayProvider = StateNotifierProvider<TodayNotifier, String>((ref) {
  return TodayNotifier(Clock.system());
});

class ActivitiesNotifier extends StateNotifier<List<Activity>> {
  ActivitiesNotifier(this._storage) : super(const []) {
    ready = _load();
  }

  final StorageService _storage;

  /// Future achevée quand les activités sont chargées depuis le stockage.
  /// Permet aux appels qui en dépendent (replanification des rappels) de lire
  /// des données justes au lieu de la liste vide initiale (course d'init).
  late final Future<void> ready;

  /// Charge les activités, remplace les sons custom dont le fichier a disparu
  /// par le son par défaut, et persiste la correction si nécessaire.
  Future<void> _load() async {
    final loaded = _storage.loadActivities();
    var changed = false;
    final sanitized = <Activity>[];
    for (final a in loaded) {
      final safe = CustomSoundService.fallbackSoundId(a.sound);
      if (safe != a.sound) changed = true;
      sanitized.add(safe == a.sound ? a : a.copyWith(sound: safe));
    }
    state = sanitized;
    if (changed) await _storage.saveActivities(sanitized);
  }

  /// Reporte plusieurs suppressions en une seule écriture Hive (suppression
  /// de routine) : un `setState` + un `put` au lieu d'un par activité.
  /// Purge aussi les références mortes dans les routines.
  Future<void> removeMany(List<String> ids) async {
    if (ids.isEmpty) return;
    final remove = ids.toSet();
    state = state.where((a) => !remove.contains(a.id)).toList();
    await _storage.saveActivities(state);
    await _purgeRoutineReferences(remove);
  }

  /// Retire de toutes les routines les IDs d'activités supprimées.
  Future<void> _purgeRoutineReferences(Set<String> ids) async {
    final routines = _storage.loadRoutines();
    var changed = false;
    final cleaned = <Routine>[];
    for (final r in routines) {
      final filtered =
          r.activityIds.where((x) => !ids.contains(x)).toList();
      if (filtered.length != r.activityIds.length) {
        changed = true;
        cleaned.add(r.copyWith(activityIds: filtered));
      } else {
        cleaned.add(r);
      }
    }
    if (changed) await _storage.saveRoutines(cleaned);
  }

  Future<void> add(Activity activity) async {
    state = [...state, activity];
    await _storage.saveActivities(state);
  }

  /// Ajout en lot (création de routine) : un seul `setState` + une seule
  /// écriture Hive pour éviter les rebuilds inutiles.
  Future<void> addAll(List<Activity> activities) async {
    if (activities.isEmpty) return;
    state = [...state, ...activities];
    await _storage.saveActivities(state);
  }

  Future<void> remove(String id) async {
    state = state.where((a) => a.id != id).toList();
    await _storage.saveActivities(state);
    // Purge des références mortes : une routine gardant l'ID d'une activité
    // supprimée grossit silencieusement et peut sembler non vide.
    await _purgeRoutineReferences({id});
  }

  Future<void> update(Activity activity) async {
    state = [for (final a in state) a.id == activity.id ? activity : a];
    await _storage.saveActivities(state);
  }

  /// Mise à jour en lot (réassignation de catégorie) : un seul `setState`
  /// + une seule écriture Hive.
  Future<void> updateAll(List<Activity> updates) async {
    if (updates.isEmpty) return;
    final byId = {for (final u in updates) u.id: u};
    state = [for (final a in state) byId.containsKey(a.id) ? byId[a.id]! : a];
    await _storage.saveActivities(state);
  }

  Future<void> toggleCompleted(String id, DateTime day) async {
    state = [
      for (final a in state)
        a.id == id ? a.withCompletedDay(day, !a.isCompletedOn(day)) : a,
    ];
    // Écriture Hive différée (debounce) : cocher/décocher est l'action la
    // plus fréquente — sérialiser toute la liste synchroniquement à chaque
    // tap fait bégayer l'UI. Les taps rapprochés fusionnent en un seul
    // enregistrement ; l'état en mémoire (source de vérité pour l'UI) est
    // mis à jour immédiatement.
    _scheduleActivitiesWrite();
  }

  Timer? _activitiesWriteTimer;

  /// Planifie l'écriture Hive de l'état courant, en annulant toute écriture
  /// déjà programmée (les toggles successifs fusionnent en une seule écriture).
  void _scheduleActivitiesWrite() {
    _activitiesWriteTimer?.cancel();
    _activitiesWriteTimer = Timer(const Duration(milliseconds: 400), () {
      _activitiesWriteTimer = null;
      _storage.saveActivities(state);
    });
  }

  /// Écrit immédiatement l'état en attente (s'il y en a un) puis annule le
  /// debounce. Appelé à la destruction du notifier et quand l'app passe en
  /// arrière-plan : UN COCHAGE CONFIRMÉ N'EST JAMAIS PERDU, même si l'app
  /// est tuée juste après l'action.
  Future<void> flushPendingWrite() async {
    if (_activitiesWriteTimer == null) return;
    _activitiesWriteTimer?.cancel();
    _activitiesWriteTimer = null;
    await _storage.saveActivities(state);
  }

  @override
  void dispose() {
    // Flush synchronique : on ne peut pas await dans dispose(), mais Hive
    // `put` écrit d'abord en mémoire avant le flush disque — l'état est
    // donc conservé même si le processus meurt peu après.
    if (_activitiesWriteTimer != null) {
      _activitiesWriteTimer!.cancel();
      _activitiesWriteTimer = null;
      _storage.saveActivities(state);
    }
    super.dispose();
  }
}

final activitiesProvider =
    StateNotifierProvider<ActivitiesNotifier, List<Activity>>((ref) {
      final storage = ref.watch(storageServiceProvider);
      return ActivitiesNotifier(storage);
    });

/// Statistiques de la routine, recalculées uniquement quand les activités
/// changent (jamais de calcul lourd dans `build()`). Le jour courant suit
/// le rollover de minuit via [todayProvider].
final habitStatsProvider = Provider<HabitStats>((ref) {
  final activities = ref.watch(activitiesProvider);
  final today = DayKey.date(ref.watch(todayProvider));
  return StatsCalculator.compute(activities, today);
});

/// Activités dues aujourd'hui, triées. Recalculées uniquement quand la liste
/// globale change OU quand le jour change (rollover minuit).
final todayActivitiesProvider = Provider<List<Activity>>((ref) {
  final activities = ref.watch(activitiesProvider);
  final today = DayKey.date(ref.watch(todayProvider));
  return activities.where((a) => a.isDueOn(today)).toList()
    ..sort(compareActivities);
});

/// Activités dues un jour donné, triées. Memoïsées par clé de jour (évite le
/// recalcule du calendrier à chaque rebuild de l'écran).
final dayActivitiesProvider = Provider.family<List<Activity>, String>((
  ref,
  dayKey,
) {
  final activities = ref.watch(activitiesProvider);
  final day = Activity.parseDateKey(dayKey);
  if (day == null) return const [];
  return activities.where((a) => a.isDueOn(day)).toList()
    ..sort(compareActivities);
});

/// Événements du calendrier pour le mois de [month] (fenêtre élargie pour
/// couvrir les jours des bordures du TableCalendar). Memoïsés par mois :
/// recalculés uniquement quand la liste globale change OU quand le mois
/// affiché change — jamais à chaque rebuild de l'écran (changement de jour,
/// changement de page, etc.). Seule contrainte : la clé est le 1er du mois.
///
/// Les clés sont des `DateTime.utc` à minuit : TableCalendar transmet ses
/// jours au `eventLoader` en UTC ; comparer avec des DateTime locaux ferait
/// rater les clés dans tout fuseau décalé (marqueurs invisibles).
final monthEventsProvider =
    Provider.family<Map<DateTime, List<Activity>>, DateTime>((ref, month) {
      final activities = ref.watch(activitiesProvider);
      final monthStart = DateTime(month.year, month.month, 1);
      final start = monthStart.subtract(const Duration(days: 7));
      final end = DateTime(
        month.year,
        month.month + 1,
        1,
      ).add(const Duration(days: 14));
      final events = <DateTime, List<Activity>>{};
      for (final a in activities) {
        var cursor = start;
        while (!cursor.isAfter(end)) {
          if (a.isDueOn(cursor)) {
            events
                .putIfAbsent(DateTime.utc(cursor.year, cursor.month, cursor.day),
                    () => [])
                .add(a);
          }
          cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
        }
      }
      return events;
    });

/// Notifier des catégories. La catégorie de repli « Autre » est protégée :
/// [delete] ne l'écrase jamais. Pour une suppression complète, utiliser
/// [deleteCategoryAndReassign] qui réassigne les activités concernées.
class CategoriesNotifier extends StateNotifier<List<Category>> {
  CategoriesNotifier(this._storage) : super(const []);

  final StorageService _storage;

  void load() => state = _storage.loadCategories();

  Future<void> create(Category category) async {
    state = [...state, category];
    await _storage.saveCategories(state);
  }

  Future<void> update(Category category) async {
    state = [for (final c in state) c.id == category.id ? category : c];
    await _storage.saveCategories(state);
  }

  Future<void> delete(String id) async {
    final target = state.where((c) => c.id == id).toList();
    if (target.isEmpty || target.first.isFallback) return;
    state = state.where((c) => c.id != id).toList();
    await _storage.saveCategories(state);
  }
}

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, List<Category>>((ref) {
      final storage = ref.watch(storageServiceProvider);
      return CategoriesNotifier(storage)..load();
    });

/// Résout une catégorie par identifiant ; `null` si elle n'existe plus
/// (les activités tombent alors sur la catégorie de repli « Autre »).
final categoryByIdProvider = Provider.family<Category?, String>((ref, id) {
  final categories = ref.watch(categoriesProvider);
  for (final c in categories) {
    if (c.id == id) return c;
  }
  return null;
});

/// Notifier des routines : groupe de références vers les activités globales.
class RoutinesNotifier extends StateNotifier<List<Routine>> {
  RoutinesNotifier(this._storage) : super(const []);

  final StorageService _storage;

  void load() => state = _storage.loadRoutines();

  Future<void> create(Routine routine) async {
    state = [...state, routine];
    await _storage.saveRoutines(state);
  }

  Future<void> update(Routine routine) async {
    state = [for (final r in state) r.id == routine.id ? routine : r];
    await _storage.saveRoutines(state);
  }

  Future<void> remove(String id) async {
    state = state.where((r) => r.id != id).toList();
    await _storage.saveRoutines(state);
  }
}

final routinesProvider = StateNotifierProvider<RoutinesNotifier, List<Routine>>(
  (ref) {
    final storage = ref.watch(storageServiceProvider);
    return RoutinesNotifier(storage)..load();
  },
);

/// Activités de chaque routine, résolues depuis la liste globale.
///
/// Lecture seule : les références devenues invalides (activité supprimée
/// ailleurs) sont simplement ignorées, sans jamais muter les routines.
final routineActivitiesProvider = Provider<Map<String, List<Activity>>>((ref) {
  final routines = ref.watch(routinesProvider);
  final activities = ref.watch(activitiesProvider);
  final byId = {for (final a in activities) a.id: a};
  return {
    for (final r in routines)
      r.id: [
        for (final id in r.activityIds)
          if (byId.containsKey(id)) byId[id]!,
      ],
  };
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._storage) : super(const AppSettings());

  final StorageService _storage;

  /// Charge les réglages, remplace un son par défaut custom disparu par le
  /// son par défaut, et persiste la correction si nécessaire.
  Future<void> load() async {
    final loaded = _storage.loadSettings();
    final safe = CustomSoundService.fallbackSoundId(loaded.defaultSound);
    if (safe == loaded.defaultSound) {
      state = loaded;
      return;
    }
    state = loaded.copyWith(defaultSound: safe);
    await _storage.saveSettings(state);
  }

  Future<void> update(AppSettings settings) async {
    state = settings;
    await _storage.saveSettings(settings);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  final storage = ref.watch(storageServiceProvider);
  return SettingsNotifier(storage)..load();
});

final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(settingsProvider).themeMode,
);

final localeProvider = Provider<String>(
  (ref) => ref.watch(settingsProvider).locale,
);

/// Palette de couleurs active (sélection dans les réglages).
final paletteProvider = Provider<ThemePalette>(
  (ref) => ref.watch(settingsProvider).palette,
);

/// Couleur d'accent active (sélection dans les réglages).
final accentProvider = Provider<AccentColor>(
  (ref) => ref.watch(settingsProvider).accent,
);

/// Chaînes traduites selon la langue choisie (avec repli anglais).
final stringsProvider = Provider<AppStrings>(
  (ref) => appStringsFor(ref.watch(localeProvider)),
);

class LockNotifier extends StateNotifier<LockSettings> {
  LockNotifier(this._storage) : super(const LockSettings());

  final StorageService _storage;

  /// Charge les réglages de verrou de façon SYNCHRONE (l'écran de verrouillage
/// doit être prêt à la première frame), puis migre en tâche de fond tout
/// secret hérité stocké en clair (motif des anciennes versions) vers un
/// hash PBKDF2 persisté immédiatement.
void load() {
  final loaded = _storage.loadLockSettings();
  state = loaded;
  // Exposé pour les tests / appelants qui veulent attendre la fin de la
  // migration des secrets legacy.
  migrationDone = loaded.migrateLegacySecrets().then((migrated) async {
    final (settings, changed) = migrated;
    if (!changed) return;
    // Garde anti-écrasement : ne s'applique que si le verrou n'a pas été
    // modifié entre-temps par l'utilisateur.
    if (!identical(state, loaded) && state != loaded) return;
    state = settings;
    try {
      await _storage.saveLockSettings(settings);
    } catch (_) {
      // Écriture impossible : la migration retentera au prochain lancement.
    }
  });
}

/// Future achevé quand la migration éventuelle des secrets hérités est
/// terminée (voir [load]).
Future<void> migrationDone = Future.value();

  Future<void> update(LockSettings lock) async {
    state = lock;
    await _storage.saveLockSettings(lock);
  }
}

final lockSettingsProvider = StateNotifierProvider<LockNotifier, LockSettings>((
  ref,
) {
  final storage = ref.watch(storageServiceProvider);
  return LockNotifier(storage)..load();
});

/// Résultat d'une tentative d'authentification biométrique, distingué pour
/// permettre des messages clairs à l'utilisateur.
enum BiometricAuthResult {
  /// Empreinte / Face ID validé.
  success,

  /// L'utilisateur a annulé (ou le système a interrompu la tentative).
  cancelled,

  /// Capteur présent mais aucune empreinte enregistrée dans le système.
  notEnrolled,

  /// Trop de tentatives : le capteur est verrouillé temporairement.
  lockedOut,

  /// Capteur absent, indisponible, ou pas de code de déverrouillage.
  unavailable,

  /// Échec inattendu.
  failure,
}

/// Service d'authentification par empreinte / Face ID.
final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// La biométrie est utilisable : l'appareil prend en charge
  /// l'authentification biométrique.
  ///
  /// Tolérant : sur certains appareils (notamment Android 9), les appels
  /// `canCheckBiometrics` / `getAvailableBiometrics` échouent ou renvoient
  /// une liste vide alors que des empreintes SONT enregistrées côté système.
  /// On se fie donc à `isDeviceSupported()` seul ; si aucune empreinte
  /// n'existe, `authenticate()` affichera le dialogue système approprié
  /// (ou échouera proprement) — jamais de blocage injustifié.
  Future<bool> get isSupported async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Capteur présent (indépendamment des empreintes enregistrées) — permet
  /// de distinguer « aucun capteur » de « capteur sans empreinte ».
  Future<bool> get hasBiometricHardware async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<BiometricAuthResult> authenticate({String? localizedReason}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason:
            localizedReason ?? 'Unlock Rappel+ with your fingerprint',
        biometricOnly: true,
      );
      return ok ? BiometricAuthResult.success : BiometricAuthResult.cancelled;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.noBiometricsEnrolled =>
          BiometricAuthResult.notEnrolled,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          BiometricAuthResult.lockedOut,
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout => BiometricAuthResult.cancelled,
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
        LocalAuthExceptionCode.uiUnavailable ||
        LocalAuthExceptionCode.noCredentialsSet =>
          BiometricAuthResult.unavailable,
        _ => BiometricAuthResult.failure,
      };
    } catch (_) {
      return BiometricAuthResult.failure;
    }
  }
}

/// Supprime une catégorie en réassignant D'ABORD ses activités vers la
/// catégorie de repli « Autre ». Aucun `categoryId` orphelin ne peut
/// subsister, même si l'écriture des catégories échoue ensuite (les
/// activités pointeraient alors vers « Autre », ce qui reste cohérent).
Future<bool> deleteCategoryAndReassign(WidgetRef ref, String id) async {
  final categories = ref.read(categoriesProvider);
  final target = categories.where((c) => c.id == id).toList();
  if (target.isEmpty || target.first.isFallback) return false;
  final activities = ref.read(activitiesProvider);
  final affected =
      activities.any((a) => a.categoryId == id);
  if (affected) {
    await ref.read(activitiesProvider.notifier).updateAll([
      for (final a in activities)
        a.categoryId == id
            ? a.copyWith(categoryId: CategoryPresets.otherId)
            : a,
    ]);
  }
  await ref.read(categoriesProvider.notifier).delete(id);
  return true;
}

/// Replanifie tous les rappels et persiste les identifiants réalloués.
///
/// `rescheduleAll` peut réallouer des `notificationId` en collision : sans
/// persistance de la liste corrigée, les futurs `cancelActivity` annuleraient
/// d'anciens IDs et laisseraient sonner des alarmes orphelines.
Future<void> rescheduleAllPersisted(
  WidgetRef ref, {
  required int reminderOffsetMinutes,
  required AppStrings s,
  required bool alarmMode,
}) async {
  final notifications = ref.read(notificationServiceProvider);
  final activities = ref.read(activitiesProvider);
  final rescheduled = await notifications.rescheduleAll(
    activities,
    reminderOffsetMinutes: reminderOffsetMinutes,
    s: s,
    alarmMode: alarmMode,
  );
  // L'ordre est préservé par rescheduleAll → comparaison index à index.
  for (var i = 0; i < rescheduled.length && i < activities.length; i++) {
    if (rescheduled[i].notificationId != activities[i].notificationId) {
      await ref.read(activitiesProvider.notifier).updateAll(rescheduled);
      return;
    }
  }
}

/// Bascule « terminé » en synchronisant l'alarme de l'occurrence : marquer
/// terminé annule la notification du jour (sans casser la série des
/// récurrents) ; re-cocher la réactive. Évite qu'une alarme déjà planifiée
/// sonne après que la tâche a été validée.
Future<void> toggleCompletedWithAlarm(
  WidgetRef ref,
  Activity activity,
  DateTime day,
) async {
  final nowDone = !activity.isCompletedOn(day);
  await ref.read(activitiesProvider.notifier).toggleCompleted(activity.id, day);
  final notifications = ref.read(notificationServiceProvider);
  // Les réglages utilisateur (offset « X min avant », mode alarme, langue)
  // sont transmis aux DEUX chemins : sans cela, le réarmement après
  // annulation repartait avec un offset 0 et perdrait les rappels anticipés.
  final settings = ref.read(settingsProvider);
  if (!nowDone) {
    await notifications.reactivateOccurrence(
      activity,
      day,
      reminderOffsetMinutes: settings.reminderOffsetMinutes,
      s: appStringsFor(settings.locale),
      alarmMode: settings.alarmMode,
    );
    return;
  }
  await notifications.cancelOccurrence(
    activity,
    day,
    reminderOffsetMinutes: settings.reminderOffsetMinutes,
    s: appStringsFor(settings.locale),
    alarmMode: settings.alarmMode,
  );
}
