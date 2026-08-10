import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rappel_plus/models/routine.dart';
import 'package:rappel_plus/services/storage_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rappel_hive_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await Hive.deleteFromDisk();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<Box> openBox() => Hive.openBox('rappel_plus');

  /// Activité « ancien format » : sans champ `notificationId`.
  Map<String, dynamic> legacyActivity({String? id}) => {
        'id': id ?? 'legacy-1',
        'name': 'Ancienne',
        'hour': 7,
        'minute': 30,
        'date': '2026-08-10',
        'repeat': 'daily',
        'weekdays': <int>[],
        'sound': 'chime1',
        'enabled': true,
        'completedDays': <String>[],
      };

  test('une boîte vide atteint la version courante sans données', () async {
    final box = await openBox();
    await StorageService.migrate(box);
    expect(box.get('schemaVersion'), StorageService.schemaVersion);
    expect(box.get('activities'), isNull);
  });

  test('v1 → v2 : les anciennes activités sans notificationId restent lisibles',
      () async {
    final box = await openBox();
    await box.put('activities', [
      legacyActivity(),
      {...legacyActivity(id: 'legacy-2'), 'notificationId': 42},
    ]);
    await StorageService.migrate(box);
    expect(box.get('schemaVersion'), StorageService.schemaVersion);

    final list = box.get('activities') as List;
    final a1 = Map<String, dynamic>.from(list[0] as Map);
    final a2 = Map<String, dynamic>.from(list[1] as Map);
    expect(a1['notificationId'], isA<int>(),
        reason: 'le champ manquant doit être ajouté');
    expect(a2['notificationId'], 42,
        reason: 'un identifiant existant ne doit jamais être modifié');
    expect(a1['name'], 'Ancienne');
    expect(a1['hour'], 7);
    expect(a1['minute'], 30);
    expect(a1['completedDays'], isEmpty);
    expect(a1['sound'], 'chime1');
  });

  test('une boîte déjà à jour n\'est ni réécrite ni modifiée', () async {
    final box = await openBox();
    await box.put('schemaVersion', StorageService.schemaVersion);
    await box.put('activities', [
      {...legacyActivity(), 'notificationId': 7},
    ]);
    await StorageService.migrate(box);
    final list = box.get('activities') as List;
    final a = Map<String, dynamic>.from(list[0] as Map);
    expect(a['notificationId'], 7);
    expect(box.get('schemaVersion'), StorageService.schemaVersion);
  });

  test('une boîte de version future n\'est pas rétrogradée', () async {
    final box = await openBox();
    await box.put('schemaVersion', 99);
    await box.put('activities', [
      {...legacyActivity(), 'notificationId': 5},
    ]);
    await StorageService.migrate(box);
    expect(box.get('schemaVersion'), 99);
    final list = box.get('activities') as List;
    expect((list[0] as Map)['notificationId'], 5);
  });

  test('la migration est idempotente (deux exécutions, un seul ajout)',
      () async {
    final box = await openBox();
    await box.put('activities', [legacyActivity()]);
    await StorageService.migrate(box);
    final first = box.get('activities') as List;
    final firstId = (first[0] as Map)['notificationId'];

    await StorageService.migrate(box);
    final second = box.get('activities') as List;
    expect(second.length, 1);
    expect((second[0] as Map)['notificationId'], firstId,
        reason: 'un identifiant déjà présent ne doit pas être régénéré');
  });

  test('v2 → v3 : la clé routines est créée vide sans toucher aux activités',
      () async {
    final box = await openBox();
    await box.put('schemaVersion', 2);
    await box.put('activities', [
      {...legacyActivity(), 'notificationId': 7},
    ]);
    await StorageService.migrate(box);
    expect(box.get('schemaVersion'), StorageService.schemaVersion);
    expect(box.get('routines'), isEmpty,
        reason: 'une nouvelle installation n\'a aucune routine');
    final list = box.get('activities') as List;
    expect(list, hasLength(1));
    expect((list[0] as Map)['notificationId'], 7,
        reason: 'les activités existantes ne sont pas modifiées');
  });

  test('v2 → v3 : les routines déjà présentes sont conservées telles quelles',
      () async {
    final box = await openBox();
    await box.put('schemaVersion', 2);
    await box.put('activities', [
      {...legacyActivity(), 'notificationId': 7},
    ]);
    await box.put('routines', [
      {'id': 'r1', 'name': 'Matin', 'activityIds': <String>[]},
    ]);
    await StorageService.migrate(box);
    final routines = box.get('routines') as List;
    expect(routines, hasLength(1));
    expect((routines[0] as Map)['name'], 'Matin');
    expect((routines[0] as Map)['id'], 'r1');
  });

  test('v2 → v3 : aller-retour une routine → Hive → Routine', () async {
    final box = await openBox();
    await box.put('schemaVersion', 2);
    await StorageService.migrate(box);

    final original = {
      'id': 'r1',
      'name': 'Matin',
      'icon': '🌅',
      'description': 'Réveil',
      'activityIds': <String>['a1', 'a2'],
      'createdAt': DateTime(2026, 8, 1).toIso8601String(),
      'active': false,
    };
    await box.put('routines', [original]);

    final raw = box.get('routines') as List;
    final restored = Routine.fromMap(Map<String, dynamic>.from(raw[0] as Map));
    expect(restored.id, 'r1');
    expect(restored.name, 'Matin');
    expect(restored.icon, '🌅');
    expect(restored.description, 'Réveil');
    expect(restored.activityIds, ['a1', 'a2']);
    expect(restored.active, isFalse);
  });

  test('v2 → v3 : une boîte de v1 atteint v3 avec les deux clés', () async {
    final box = await openBox();
    await box.put('activities', [legacyActivity()]);
    await StorageService.migrate(box);
    expect(box.get('schemaVersion'), StorageService.schemaVersion);
    expect(box.get('routines'), isNotNull);
    expect(box.get('routines'), isEmpty);
    final list = box.get('activities') as List;
    expect((list[0] as Map)['notificationId'], isA<int>());
  });
}
