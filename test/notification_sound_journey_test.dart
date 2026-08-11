import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/l10n/app_strings.dart';
import 'package:rappel_plus/models/activity.dart';
import 'package:rappel_plus/models/notification_payload.dart';
import 'package:rappel_plus/services/notification_service.dart';
import 'package:rappel_plus/services/custom_sound_service.dart';

void main() {
  group('Notification Sound Journey Test', () {
    final service = NotificationService.instance;

    test('Chaque son intégré utilise un canal Android distinct et un fichier son dédié', () {
      final chime1Details = service.detailsFor('chime1', AppStrings.fr);
      final beepDetails = service.detailsFor('beep', AppStrings.fr);
      final bellDetails = service.detailsFor('bell', AppStrings.fr);
      final whistleDetails = service.detailsFor('whistle', AppStrings.fr);

      final androidChime1 = chime1Details.android!;
      final androidBeep = beepDetails.android!;
      final androidBell = bellDetails.android!;
      final androidWhistle = whistleDetails.android!;

      // Canaux Android distincts
      expect(androidChime1.channelId, contains('chime1'));
      expect(androidBeep.channelId, contains('beep'));
      expect(androidBell.channelId, contains('bell'));
      expect(androidWhistle.channelId, contains('whistle'));

      expect(androidChime1.channelId, isNot(equals(androidBeep.channelId)));

      // Sons Android sous RawResourceAndroidNotificationSound
      expect(androidChime1.sound, isA<RawResourceAndroidNotificationSound>());
      expect((androidChime1.sound as RawResourceAndroidNotificationSound).sound, 'chime1');

      expect(androidBeep.sound, isA<RawResourceAndroidNotificationSound>());
      expect((androidBeep.sound as RawResourceAndroidNotificationSound).sound, 'beep');

      // Sons iOS sous DarwinNotificationDetails
      final iosChime1 = chime1Details.iOS!;
      final iosBeep = beepDetails.iOS!;

      expect(iosChime1.sound, 'chime1.wav');
      expect(iosBeep.sound, 'beep.wav');
    });

    test('Activité A (chime1) et Activité B (beep) ont des configurations de son strictement isolées', () {
      final actA = Activity.create(
        name: 'Travail',
        hour: 18,
        minute: 0,
        date: DateTime(2026, 8, 10),
        sound: 'chime1',
      );

      final actB = Activity.create(
        name: 'Sport',
        hour: 19,
        minute: 0,
        date: DateTime(2026, 8, 10),
        sound: 'beep',
      );

      final detailsA = service.detailsFor(actA.sound, AppStrings.fr);
      final detailsB = service.detailsFor(actB.sound, AppStrings.fr);

      expect(detailsA.android!.channelId, contains('chime1'));
      expect(detailsB.android!.channelId, contains('beep'));

      expect((detailsA.android!.sound as RawResourceAndroidNotificationSound).sound, 'chime1');
      expect((detailsB.android!.sound as RawResourceAndroidNotificationSound).sound, 'beep');
    });

    test('Modification du son d une activité (chime1 -> beep) met à jour le canal et le son', () {
      final initialAct = Activity.create(
        name: 'Méditation',
        hour: 8,
        minute: 0,
        date: DateTime(2026, 8, 10),
        sound: 'chime1',
      );

      final updatedAct = initialAct.copyWith(sound: 'beep');

      final oldDetails = service.detailsFor(initialAct.sound, AppStrings.fr);
      final newDetails = service.detailsFor(updatedAct.sound, AppStrings.fr);

      expect(oldDetails.android!.channelId, contains('chime1'));
      expect(newDetails.android!.channelId, contains('beep'));
      expect(oldDetails.android!.channelId, isNot(equals(newDetails.android!.channelId)));
    });

    test('Son custom inexistant retombe automatiquement sur le son par défaut (fallback)', () {
      const missingSoundId = 'custom://file:///tmp/non_existent_sound_12345.mp3';

      expect(CustomSoundService.fileExists(missingSoundId), isFalse);
      expect(CustomSoundService.fallbackSoundId(missingSoundId), 'default');

      final details = service.detailsFor(missingSoundId, AppStrings.fr);

      // Devrait utiliser le canal par défaut
      expect(details.android!.channelId, contains('default'));
      expect(details.iOS!.sound, isNull);
    });

    test('Le NotificationPayload préserve fidèlement le son de l activité pour les isolates et le snooze', () {
      final act = Activity.create(
        name: 'Lecture',
        hour: 21,
        minute: 30,
        date: DateTime(2026, 8, 10),
        sound: 'bell',
      );

      final payload = NotificationPayload.fromActivity(
        act,
        occurrence: '2026-08-10',
        notificationId: 101,
        journalDir: '/tmp',
        timezone: 'Europe/Paris',
        locale: 'fr',
      );

      expect(payload.sound, 'bell');

      final encoded = payload.encode();
      final decoded = NotificationPayload.decode(encoded)!;

      expect(decoded.sound, 'bell');

      final detailsFromDecoded = service.detailsFor(decoded.sound, AppStrings.fr);
      expect(detailsFromDecoded.android!.channelId, contains('bell'));
    });
  });
}
