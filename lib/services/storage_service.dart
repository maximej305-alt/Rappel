import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/activity.dart';
import '../models/app_settings.dart';
import '../models/lock_settings.dart';
import '../models/routine.dart';

class StorageService {
  StorageService();

  static const _boxName = 'rappel_plus';
  static const _activitiesKey = 'activities';
  static const _routinesKey = 'routines';
  static const _settingsKey = 'settings';
  static const _lockKey = 'lock';
  static const _hiveKeyStorageKey = 'rappel_plus_hive_key';
  static const _schemaVersionKey = 'schemaVersion';

  /// Version courante du schéma Hive. À la moindre évolution des données
  /// stockées : bump + nouvelle entrée dans [_migrations].
  static const int schemaVersion = 3;

  static final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  Box? _box;

  /// Initialise Hive avec une boîte chiffrée (AES-256).
  /// La clé est générée une seule fois puis conservée de façon sécurisée
  /// dans le Keychain (iOS) / Keystore (Android) du système.
  Future<void> init() async {
    await Hive.initFlutter();
    final key = await _loadOrCreateEncryptionKey();
    _box = await Hive.openBox(
      _boxName,
      encryptionCipher: HiveAesCipher(key),
    );
    await migrate(_box!);
  }

  /// Applique les migrations manquantes jusqu'à [schemaVersion].
  /// Idempotent : n'exécute jamais deux fois une même version et ne touche
  /// pas aux données quand le schéma est déjà à jour. Chaque étape préserve
  /// les données existantes (elle ne fait que compléter ou corriger).
  /// Exposé publiquement pour être testé sans stockage sécurisé.
  static Future<void> migrate(Box box) async {
    final stored = box.get(_schemaVersionKey, defaultValue: 1) as int;
    if (stored >= schemaVersion) return;
    for (var v = stored + 1; v <= schemaVersion; v++) {
      final step = _migrations[v];
      if (step != null) await step(box);
    }
    await box.put(_schemaVersionKey, schemaVersion);
  }

  /// Étapes de migration, indexées par version cible.
  /// Les versions antérieures non répertoriées ne sont pas réappliquées.
  static final Map<int, Future<void> Function(Box box)> _migrations = {
    2: _migrateV1ToV2,
    3: _migrateV2ToV3,
  };

  /// v1 → v2 : garantit un `notificationId` à chaque activité enregistrée
  /// (les données anciennes, sans ce champ, restent lisibles). Les
  /// identifiants déjà présents ne sont jamais modifiés.
  static Future<void> _migrateV1ToV2(Box box) async {
    final raw = box.get(_activitiesKey);
    if (raw == null) return; // aucune donnée existante → rien à migrer
    final activities = <Map<String, dynamic>>[];
    for (final e in raw as List) {
      final map = Map<String, dynamic>.from(e as Map);
      if (map['notificationId'] is! int) {
        map['notificationId'] = Activity.newNotificationId();
      }
      activities.add(map);
    }
    await box.put(_activitiesKey, activities);
  }

  /// v2 → v3 : ajoute la clé `routines` (liste vide) pour le nouveau système
  /// de routines. Purement additif : les activités et réglages existants ne
  /// sont jamais modifiés.
  static Future<void> _migrateV2ToV3(Box box) async {
    if (box.get(_routinesKey) != null) return; // déjà en place → rien à faire
    await box.put(_routinesKey, <Map<String, dynamic>>[]);
  }

  Future<List<int>> _loadOrCreateEncryptionKey() async {
    final existing = await _secureStorage.read(key: _hiveKeyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      return base64Decode(existing);
    }
    final key = Hive.generateSecureKey();
    await _secureStorage.write(key: _hiveKeyStorageKey, value: base64Encode(key));
    return key;
  }

  List<Activity> loadActivities() {
    final raw = _box?.get(_activitiesKey) as List? ?? const [];
    return raw
        .map((e) => Activity.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveActivities(List<Activity> activities) async {
    await _box?.put(
      _activitiesKey,
      activities.map((a) => a.toMap()).toList(),
    );
  }

  List<Routine> loadRoutines() {
    final raw = _box?.get(_routinesKey) as List? ?? const [];
    return raw
        .map((e) => Routine.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveRoutines(List<Routine> routines) async {
    await _box?.put(
      _routinesKey,
      routines.map((r) => r.toMap()).toList(),
    );
  }

  AppSettings loadSettings() {
    final raw = _box?.get(_settingsKey);
    if (raw == null) return const AppSettings();
    return AppSettings.fromMap(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _box?.put(_settingsKey, settings.toMap());
  }

  LockSettings loadLockSettings() {
    final raw = _box?.get(_lockKey);
    if (raw == null) return const LockSettings();
    return LockSettings.fromMap(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> saveLockSettings(LockSettings lock) async {
    await _box?.put(_lockKey, lock.toMap());
  }
}
