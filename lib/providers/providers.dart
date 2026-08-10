import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../l10n/app_strings.dart';
import '../models/activity.dart';
import '../models/app_settings.dart';
import '../models/lock_settings.dart';
import '../models/routine.dart';
import '../services/custom_sound_service.dart';
import '../services/notification_service.dart';
import '../services/stats_service.dart';
import '../services/storage_service.dart';

/// Provider remplacé dans `main.dart` après initialisation du stockage.
final storageServiceProvider = Provider<StorageService>(
  (ref) => throw UnimplementedError('storageServiceProvider doit être injecté'),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService.instance,
);

class ActivitiesNotifier extends StateNotifier<List<Activity>> {
  ActivitiesNotifier(this._storage) : super(const []);

  final StorageService _storage;

  /// Charge les activités, remplace les sons custom dont le fichier a disparu
  /// par le son par défaut, et persiste la correction si nécessaire.
  Future<void> load() async {
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
  return ActivitiesNotifier(storage)..load();
});

/// Statistiques de la routine, recalculées uniquement quand les activités
/// changent (jamais de calcul lourd dans `build()`).
final habitStatsProvider = Provider<HabitStats>((ref) {
  final activities = ref.watch(activitiesProvider);
  return StatsCalculator.compute(activities, DateTime.now());
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

/// Chaînes traduites selon la langue choisie.
final stringsProvider = Provider<AppStrings>(
  (ref) => ref.watch(localeProvider).startsWith('fr')
      ? AppStrings.fr
      : AppStrings.en,
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

/// Service d'authentification par empreinte / Face ID.
final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> get isSupported async {
    try {
      return await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({String? localizedReason}) async {
    try {
      return await _auth.authenticate(
        localizedReason:
            localizedReason ?? 'Unlock Rappel + with your fingerprint',
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }
}
