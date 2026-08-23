import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/activity.dart';
import '../models/activity_priority.dart';
import '../models/app_settings.dart';
import '../models/category.dart';
import '../models/lock_settings.dart';
import '../models/routine.dart';

class StorageService {
  StorageService();

  static const _boxName = 'rappel_plus';
  static const _activitiesKey = 'activities';
  static const _routinesKey = 'routines';
  static const _categoriesKey = 'categories';
  static const _settingsKey = 'settings';
  static const _lockKey = 'lock';
  static const _hiveKeyStorageKey = 'rappel_plus_hive_key';
  static const _schemaVersionKey = 'schemaVersion';

  /// Version courante du schéma Hive. À la moindre évolution des données
  /// stockées : bump + nouvelle entrée dans [_migrations].
  static const int schemaVersion = 4;

  static final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  Box? _box;

  /// Boîte obligatoire pour toute ÉCRITURE : si Hive n'a pas pu être ouvert,
  /// sauvegarder en silence reviendrait à perdre les données de la session
  /// sans prévenir. On journalise et on lève — l'échec doit être visible.
  Box get _db {
    final b = _box;
    if (b == null) {
      debugPrint('[Storage] ERREUR : boîte Hive indisponible, écriture refusée');
      throw StateError('StorageService.init() non terminé');
    }
    return b;
  }

  /// Vrai dès que le coffre est ouvert.
  bool get isReady => _box != null;

  /// Initialise Hive avec une boîte chiffrée (AES-256).
  /// La clé est générée une seule fois puis conservée de façon sécurisée
  /// dans le Keychain (iOS) / Keystore (Android) du système.
  Future<void> init() async {
    await Hive.initFlutter();
    final key = await _loadOrCreateEncryptionKey();
    final dir = await getApplicationDocumentsDirectory();
    _box = await openBoxWithRecovery(dir.path, _boxName, HiveAesCipher(key));
    await migrate(_box!);
  }

  /// Ouvre un coffre. En cas de fichier corrompu (écriture interrompue,
  /// restauration partielle, header détruit), `crashRecovery` de Hive
  /// tronque déjà au dernier frame valide ; si l'ouverture échoue malgré
  /// tout, le fichier fautif est écarté en `.corrupt` (conservé pour une
  /// éventuelle récupération manuelle) et un coffre neuf est créé, plutôt
  /// que de faire planter l'app au démarrage.
  /// Exposé publiquement pour être testé sans stockage sécurisé.
  ///
  /// La zone protégée absorbe l'erreur asynchrone « orpheline » que Hive
  /// laisse derrière lui lorsqu'un `openBox` échoue (le completer interne
  /// de `Hive._openBox` complète une future que personne n'écoute) : sans
  /// cela, l'app recevrait un uncaught error même quand la récupération
  /// réussit.
  static Future<Box> openBoxWithRecovery(
    String path,
    String name,
    HiveCipher cipher,
  ) {
    final completer = Completer<Box>();
    runZonedGuarded(
      () {
        _tryOpenBox(path, name, cipher).then(
          completer.complete,
          onError: (Object e, StackTrace s) => completer.completeError(e, s),
        );
      },
      // Erreur asynchrone non écoutée de Hive : ignorée.
      // ignore: avoid_types_on_closure_parameters
      (Object error, StackTrace stackTrace) {},
    );
    return completer.future;
  }

  static Future<Box> _tryOpenBox(
    String path,
    String name,
    HiveCipher cipher,
  ) async {
    try {
      return await Hive.openBox(name, path: path, encryptionCipher: cipher);
    } catch (_) {
      await _quarantineCorruptBox(path, name);
      return Hive.openBox(name, path: path, encryptionCipher: cipher);
    }
  }

  /// Écarte le fichier `.hive` corrompu en le renommant en `.corrupt`
  /// (écrase un éventuel backup précédent). Gère aussi le cas où le chemin
  /// fautif est un dossier (échec d'ouverture franc).
  static Future<void> _quarantineCorruptBox(String path, String name) async {
    final hivePath = '$path${Platform.pathSeparator}$name.hive';
    final type = await FileSystemEntity.type(hivePath);
    if (type == FileSystemEntityType.notFound) return;

    final backupPath = '$hivePath.corrupt';
    final backupType = await FileSystemEntity.type(backupPath);
    if (backupType == FileSystemEntityType.directory) {
      await Directory(backupPath).delete(recursive: true);
    } else if (backupType != FileSystemEntityType.notFound) {
      await File(backupPath).delete();
    }

    if (type == FileSystemEntityType.directory) {
      await Directory(hivePath).rename(backupPath);
    } else {
      await File(hivePath).rename(backupPath);
    }
  }

  /// Applique les migrations manquantes jusqu'à [schemaVersion].
  /// Idempotent : n'exécute jamais deux fois une même version et ne touche
  /// pas aux données quand le schéma est déjà à jour. Chaque étape préserve
  /// les données existantes (elle ne fait que compléter ou corriger).
  /// Exposé publiquement pour être testé sans stockage sécurisé.
  ///
  /// Défensif : si une étape échoue (données corrompues, types inattendus),
  /// l'erreur est enregistrée mais n'empêche jamais le démarrage — l'app
  /// reste utilisable et une tentative ultérieure (ou un futur schéma)
  /// pourra corriger.
  static Future<void> migrate(Box box, {void Function(String)? onError}) async {
    int stored;
    final rawVersion = box.get(_schemaVersionKey, defaultValue: 1);
    if (rawVersion is int) {
      stored = rawVersion;
    } else {
      stored = 1;
      if (onError != null) {
        onError('schemaVersion non int : ${rawVersion.runtimeType}');
      }
    }
    if (stored > schemaVersion) {
      // Version plus récente que connue (downgrade) : ne rien faire, ne pas
      // écraser les données d'une version future.
      return;
    }
    for (var v = stored + 1; v <= schemaVersion; v++) {
      final step = _migrations[v];
      if (step == null) continue;
      try {
        await step(box);
      } catch (e, st) {
        if (onError != null) onError('migration $v échouée : $e\n$st');
        // Ne pas bloquer le démarrage ; le schéma n'est pas incrémenté, une
        // prochaine tentative réessaiera.
        return;
      }
    }
    await box.put(_schemaVersionKey, schemaVersion);
  }

  /// Étapes de migration, indexées par version cible.
  /// Les versions antérieures non répertoriées ne sont pas réappliquées.
  static final Map<int, Future<void> Function(Box box)> _migrations = {
    2: _migrateV1ToV2,
    3: _migrateV2ToV3,
    4: _migrateV3ToV4,
  };

  /// v1 → v2 : garantit un `notificationId` à chaque activité enregistrée
  /// (les données anciennes, sans ce champ, restent lisibles). Les
  /// identifiants déjà présents ne sont jamais modifiés.
  static Future<void> _migrateV1ToV2(Box box) async {
    final raw = box.get(_activitiesKey);
    if (raw == null) return; // aucune donnée existante → rien à migrer
    final activities = <Map<String, dynamic>>[];
    for (final e in raw is List ? raw : const []) {
      if (e is! Map) continue; // entrée illisible : écartée, jamais un crash
      final map = Map<String, dynamic>.from(e);
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

  /// v3 → v4 : ajoute les catégories intégrées et complète chaque activité
  /// avec `priority` et `categoryId`. Purement additif et idempotent :
  /// les valeurs déjà présentes ne sont jamais modifiées.
  static Future<void> _migrateV3ToV4(Box box) async {
    if (box.get(_categoriesKey) == null) {
      await box.put(
        _categoriesKey,
        CategoryPresets.builtins.map((c) => c.toMap()).toList(),
      );
    }
    final raw = box.get(_activitiesKey);
    if (raw == null) return; // aucune donnée existante → rien à migrer
    var changed = false;
    final activities = <Map<String, dynamic>>[];
    for (final e in raw is List ? raw : const []) {
      if (e is! Map) continue; // entrée illisible : écartée, jamais un crash
      final map = Map<String, dynamic>.from(e);
      if (map['priority'] is! String) {
        map['priority'] = Priority.normal.name;
        changed = true;
      }
      if (map['categoryId'] is! String) {
        map['categoryId'] = CategoryPresets.otherId;
        changed = true;
      }
      activities.add(map);
    }
    if (changed) await box.put(_activitiesKey, activities);
  }

  Future<List<int>> _loadOrCreateEncryptionKey() async {
    final existing = await _secureStorage.read(key: _hiveKeyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      try {
        return base64Decode(existing);
      } catch (_) {
        // La clé stockée est illisible : on en régénère une. Attention, la
        // boîte chiffrée ne pourra pas être ouverte avec la nouvelle clé ;
        // openBoxWithRecovery part en quarantaine puis recrée un coffre neuf.
      }
    }
    final key = Hive.generateSecureKey();
    await _secureStorage.write(key: _hiveKeyStorageKey, value: base64Encode(key));
    return key;
  }

  List<Activity> loadActivities() {
    final raw = _box?.get(_activitiesKey);
    if (raw is! List) return const [];
    final activities = <Activity>[];
    for (final e in raw) {
      try {
        if (e is! Map) continue;
        activities.add(Activity.fromMap(Map<String, dynamic>.from(e)));
      } catch (_) {
        // Entrée illisible : écartée proprement plutôt que de faire crasher
        // toute l'app au démarrage. Elle reste présente dans la boîte.
      }
    }
    return activities;
  }

  Future<void> saveActivities(List<Activity> activities) async {
    await _db.put(
      _activitiesKey,
      activities.map((a) => a.toMap()).toList(),
    );
  }

  List<Routine> loadRoutines() {
    final raw = _box?.get(_routinesKey);
    if (raw is! List) return const [];
    final routines = <Routine>[];
    for (final e in raw) {
      try {
        if (e is! Map) continue;
        routines.add(Routine.fromMap(Map<String, dynamic>.from(e)));
      } catch (_) {
        // Entrée illisible : écartée sans bloquer le démarrage.
      }
    }
    return routines;
  }

  Future<void> saveRoutines(List<Routine> routines) async {
    await _db.put(
      _routinesKey,
      routines.map((r) => r.toMap()).toList(),
    );
  }

  List<Category> loadCategories() {
    final raw = _box?.get(_categoriesKey);
    if (raw is! List) return List.of(CategoryPresets.builtins);
    if (raw.isEmpty) return List.of(CategoryPresets.builtins);
    final categories = <Category>[];
    for (final e in raw) {
      try {
        if (e is! Map) continue;
        categories.add(Category.fromMap(Map<String, dynamic>.from(e)));
      } catch (_) {
        // Entrée illisible : écartée sans bloquer le démarrage.
      }
    }
    return categories.isEmpty ? List.of(CategoryPresets.builtins) : categories;
  }

  Future<void> saveCategories(List<Category> categories) async {
    await _db.put(
      _categoriesKey,
      categories.map((c) => c.toMap()).toList(),
    );
  }

  AppSettings loadSettings() {
    final raw = _box?.get(_settingsKey);
    if (raw == null) return const AppSettings();
    try {
      if (raw is! Map) return const AppSettings();
      return AppSettings.fromMap(Map<String, dynamic>.from(raw));
    } catch (_) {
      // Réglages illisibles : on repart sur les défauts sans bloquer.
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _db.put(_settingsKey, settings.toMap());
  }

  LockSettings loadLockSettings() {
    final raw = _box?.get(_lockKey);
    if (raw == null) return const LockSettings();
    try {
      if (raw is! Map) return const LockSettings();
      return LockSettings.fromMap(Map<String, dynamic>.from(raw));
    } catch (_) {
      // Verrou illisible : on retombe sur « désactivé » sans bloquer.
      return const LockSettings();
    }
  }

  Future<void> saveLockSettings(LockSettings lock) async {
    await _db.put(_lockKey, lock.toMap());
  }
}
