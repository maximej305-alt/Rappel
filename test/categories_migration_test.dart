import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rappel_plus/models/category.dart';
import 'package:rappel_plus/services/storage_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rappel_cat_test');
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

  /// Activité « format v3 » : sans `priority` ni `categoryId`.
  Map<String, dynamic> v3Activity({String? id}) => {
        'id': id ?? 'a1',
        'name': 'Réveil',
        'hour': 7,
        'minute': 30,
        'date': '2026-08-10',
        'repeat': 'daily',
        'weekdays': <int>[],
        'sound': 'chime1',
        'enabled': true,
        'notificationId': 12,
        'completedDays': <String>[],
      };

  test('v3 → v4 : les catégories intégrées sont créées', () async {
    final box = await openBox();
    await box.put('schemaVersion', 3);
    await StorageService.migrate(box);
    expect(box.get('schemaVersion'), StorageService.schemaVersion);

    final raw = box.get('categories') as List;
    expect(raw, hasLength(5));
    final cats = raw
        .map((e) => Category.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    expect(
      cats.map((c) => c.id).toSet(),
      {
        'builtin_perso',
        'builtin_work',
        'builtin_study',
        'builtin_sport',
        'builtin_other',
      },
    );
    expect(cats.where((c) => c.isFallback).single.id, CategoryPresets.otherId);
  });

  test('v3 → v4 : les activités reçoivent priority + categoryId par défaut',
      () async {
    final box = await openBox();
    await box.put('schemaVersion', 3);
    await box.put('activities', [v3Activity()]);
    await StorageService.migrate(box);

    final a =
        Map<String, dynamic>.from((box.get('activities') as List)[0] as Map);
    expect(a['priority'], 'normal');
    expect(a['categoryId'], CategoryPresets.otherId);
    expect(a['notificationId'], 12,
        reason: 'les champs existants ne sont jamais modifiés');
    expect(a['name'], 'Réveil');
  });

  test('v3 → v4 : les valeurs déjà présentes sont conservées', () async {
    final box = await openBox();
    await box.put('schemaVersion', 3);
    await box.put('activities', [
      {...v3Activity(), 'priority': 'urgent', 'categoryId': 'builtin_work'},
    ]);
    await StorageService.migrate(box);

    final a =
        Map<String, dynamic>.from((box.get('activities') as List)[0] as Map);
    expect(a['priority'], 'urgent');
    expect(a['categoryId'], 'builtin_work');
  });

  test('v3 → v4 : les catégories existantes sont conservées telles quelles',
      () async {
    final box = await openBox();
    await box.put('schemaVersion', 3);
    await box.put('categories', [
      {'id': 'custom-1', 'name': 'Santé', 'icon': '💊', 'colorIndex': 5},
    ]);
    await StorageService.migrate(box);

    final raw = box.get('categories') as List;
    expect(raw, hasLength(1));
    final c = Category.fromMap(Map<String, dynamic>.from(raw[0] as Map));
    expect(c.id, 'custom-1');
    expect(c.name, 'Santé');
    expect(c.icon, '💊');
  });

  test('v3 → v4 : sans activité, la migration reste additive', () async {
    final box = await openBox();
    await box.put('schemaVersion', 3);
    await StorageService.migrate(box);
    expect(box.get('activities'), isNull);
    expect(box.get('categories'), isNotNull);
  });

  test('la migration v4 est idempotente', () async {
    final box = await openBox();
    await box.put('schemaVersion', 3);
    await box.put('activities', [v3Activity()]);
    await StorageService.migrate(box);
    await StorageService.migrate(box);

    final list = box.get('activities') as List;
    expect(list, hasLength(1));
    expect(box.get('categories') as List, hasLength(5));
  });

  test('une boîte de v1 atteint v4 avec toutes les clés', () async {
    final box = await openBox();
    await box.put('activities', [v3Activity()]);
    await StorageService.migrate(box);

    expect(box.get('schemaVersion'), StorageService.schemaVersion);
    expect(box.get('routines'), isEmpty);
    expect(box.get('categories'), hasLength(5));
    final a =
        Map<String, dynamic>.from((box.get('activities') as List)[0] as Map);
    expect(a['priority'], 'normal');
    expect(a['categoryId'], CategoryPresets.otherId);
  });
}
