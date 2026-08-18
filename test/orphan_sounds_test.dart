import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rappel_plus/l10n/app_strings.dart';
import 'package:rappel_plus/services/custom_sound_service.dart';
import 'package:rappel_plus/services/notification_service.dart';
import 'package:rappel_plus/services/sound_preview_service.dart';

void main() {
  late Directory tempDir;
  late File existingFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rappel_sound_test');
    existingFile = File('${tempDir.path}/present.wav');
    await existingFile.writeAsBytes([1, 2, 3]);
  });

  tearDown(() async {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// Son custom dont le fichier existe vraiment.
  String customId(File file) => 'custom://${Uri.file(file.path)}';

  group('CustomSoundService â€” fichiers orphelins', () {
    test('fileExists dÃ©tecte un fichier prÃ©sent', () {
      expect(CustomSoundService.fileExists(customId(existingFile)), isTrue);
    });

    test('fileExists dÃ©tecte un fichier manquant', () {
      final missing = '${tempDir.path}/absent.wav';
      expect(
        CustomSoundService.fileExists('custom://${Uri.file(missing)}'),
        isFalse,
      );
    });

    test('fileExists est faux hors sons custom', () {
      expect(CustomSoundService.fileExists('chime1'), isFalse);
      expect(CustomSoundService.fileExists('default'), isFalse);
    });

    test('fallbackSoundId garde un son custom existant', () {
      final id = customId(existingFile);
      expect(CustomSoundService.fallbackSoundId(id), id);
    });

    test('fallbackSoundId retombe sur default si le fichier a disparu', () {
      final missing = '${tempDir.path}/supprime.wav';
      final id = 'custom://${Uri.file(missing)}';
      expect(CustomSoundService.fallbackSoundId(id), 'default');
    });

    test('fallbackSoundId laisse les sons intÃ©grÃ©s intacts', () {
      expect(CustomSoundService.fallbackSoundId('alarm'), 'alarm');
      expect(CustomSoundService.fallbackSoundId('chime2'), 'chime2');
    });
  });

  group('NotificationService â€” jamais de notification silencieuse', () {
    final s = AppStrings.fr;

    test('un son custom manquant utilise le canal et le son par dÃ©faut',
        () {
      final service = NotificationService.instance;
      final missing = 'custom://${Uri.file('${tempDir.path}/orphelin.mp3')}';
      final (channelId, _) = service.channelFor(missing, s);
      expect(channelId, 'rappel_v6_default',
          reason: 'canal par dÃ©faut au lieu d\'un canal custom mort');
      final sound = service.soundFor(missing);
      expect(sound, isA<UriAndroidNotificationSound>());
    });

    test('un son custom existant garde son canal dÃ©diÃ©', () {
      final service = NotificationService.instance;
      final (channelId, _) = service.channelFor(customId(existingFile), s);
      expect(channelId, isNot('rappel_v6_default'),
          reason: 'le fichier existe : canal custom conservÃ©');
      expect(channelId, startsWith('rappel_v6_custom_'));
    });

    test('les sons intÃ©grÃ©s sont inchangÃ©s', () {
      final service = NotificationService.instance;
      expect(service.channelFor('bell', s).$1, 'rappel_v6_bell');
      expect(service.soundFor('bell'),
          isA<RawResourceAndroidNotificationSound>());
    });
  });

  group('SoundPreviewService â€” aperÃ§u orphelin', () {
    test('play retourne false pour un fichier custom manquant', () async {
      final ok = await SoundPreviewService.instance
          .play('custom://${Uri.file('${tempDir.path}/absent.wav')}');
      expect(ok, isFalse);
    });

    test('play retourne false pour un son inconnu (pas d\'erreur)',
        () async {
      final ok = await SoundPreviewService.instance.play('nimporte');
      expect(ok, isFalse);
    });

    test('stop et dispose restent sÃ»rs sans lecture en cours', () async {
      final svc = SoundPreviewService.instance;
      await svc.stop();
      expect(svc.isPlaying, isFalse);
      await svc.dispose();
      await svc.dispose(); // idempotent, aucune fuite
      expect(svc.isPlaying, isFalse);
    });
  });

  test('soundFileExists (API publique) reste fonctionnel', () {
    expect(soundFileExists(customId(existingFile)), isTrue);
    expect(soundFileExists('custom://file:///nope/xyz.wav'), isFalse);
  });
}
