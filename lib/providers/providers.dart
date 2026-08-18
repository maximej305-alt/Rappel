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
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final todayProvider =
    StateNotifierProvider<TodayNotifier, String>((ref) {
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
  }

  Future<void> update(Activity activity) async {
    state = [
      for (final a in state) a.id == activity.id ? activity : a,
    ];
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
    await _storage.saveActivities(state);
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
final dayActivitiesProvider =
    Provider.family<List<Activity>, String>((ref, dayKey) {
  final activities = ref.watch(activitiesProvider);
  final day = Activity.parseDateKey(dayKey);
  if (day == null) return const [];
  return activities.where((a) => a.isDueOn(day)).toList()
    ..sort(compareActivities);
});

/// Notifier des catégories. La catégorie de repli « Autre » est protégée :
/// [delete] ne l'écrase jamais (les activités la référençant doivent être
/// réassignées par l'appelant avant suppression).
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

final routinesProvider =
    StateNotifierProvider<RoutinesNotifier, List<Routine>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return RoutinesNotifier(storage)..load();
});

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
      r.id: [for (final id in r.activityIds) if (byId.containsKey(id)) byId[id]!],
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

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
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

  void load() => state = _storage.loadLockSettings();

  Future<void> update(LockSettings lock) async {
    state = lock;
    await _storage.saveLockSettings(lock);
  }
}

final lockSettingsProvider =
    StateNotifierProvider<LockNotifier, LockSettings>((ref) {
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

  /// La biométrie est utilisable : capteur présent ET au moins une empreinte
  /// enregistrée sur l'appareil.
  Future<bool> get isSupported async {
    try {
      return await _auth.isDeviceSupported() &&
          (await _auth.canCheckBiometrics) &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
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
        LocalAuthExceptionCode.biometricLockout => BiometricAuthResult.lockedOut,
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
  if (!nowDone) {
    final settings = ref.read(settingsProvider);
    await notifications.reactivateOccurrence(
      activity,
      day,
      reminderOffsetMinutes: settings.reminderOffsetMinutes,
      s: appStringsFor(settings.locale),
      alarmMode: settings.alarmMode,
    );
    return;
  }
  await notifications.cancelOccurrence(activity, day);
}
