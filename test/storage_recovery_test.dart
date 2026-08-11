import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rappel_plus/services/storage_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rappel_recovery_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    try {
      await Hive.close();
      await Hive.deleteFromDisk();
    } catch (_) {}
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<HiveCipher> newCipher() async =>
      HiveAesCipher(Hive.generateSecureKey());

  test('un fichier corrompu ne fait pas planter l\'ouverture', () async {
    final boxPath =
        '${tempDir.path}${Platform.pathSeparator}rappel_plus.hive';
    await File(boxPath).writeAsBytes(List.filled(4096, 0xAB));

    final box = await StorageService.openBoxWithRecovery(
      tempDir.path,
      'rappel_plus',
      await newCipher(),
    );

    expect(box.isOpen, isTrue);
    await box.put('x', 1);
    expect(box.get('x'), 1);
  });

  test('un header tronqué ne fait pas planter l\'ouverture', () async {
    final boxPath =
        '${tempDir.path}${Platform.pathSeparator}rappel_plus.hive';
    await File(boxPath).writeAsBytes(List.filled(13, 0x42));

    final box = await StorageService.openBoxWithRecovery(
      tempDir.path,
      'rappel_plus',
      await newCipher(),
    );

    expect(box.isOpen, isTrue);
    await box.put('x', 2);
    expect(box.get('x'), 2);
  });

  test('un coffre sain s\'ouvre normalement', () async {
    final box = await StorageService.openBoxWithRecovery(
      tempDir.path,
      'rappel_plus',
      await newCipher(),
    );

    expect(box.isOpen, isTrue);
    await box.put('x', 3);
    expect(box.get('x'), 3);
  });

  test('un dossier à la place du fichier est écarté, pas d\'erreur orpheline',
      () async {
    final boxPath =
        '${tempDir.path}${Platform.pathSeparator}rappel_plus.hive';
    await Directory(boxPath).create(recursive: true);

    final box = await StorageService.openBoxWithRecovery(
      tempDir.path,
      'rappel_plus',
      await newCipher(),
    );

    expect(box.isOpen, isTrue);
    await box.put('x', 4);
    expect(box.get('x'), 4);
    expect(Directory('$boxPath.corrupt').existsSync(), isTrue);
  });
}
