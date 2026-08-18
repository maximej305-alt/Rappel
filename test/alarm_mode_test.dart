import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/l10n/app_strings.dart';
import 'package:rappel_plus/models/app_settings.dart';
import 'package:rappel_plus/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Alarm Mode & Settings Tests', () {
    test('AppSettings toggle alarmMode correctly', () {
      const settings = AppSettings();
      expect(settings.alarmMode, isTrue);

      final updated = settings.copyWith(alarmMode: false);
      expect(updated.alarmMode, isFalse);

      final map = updated.toMap();
      expect(map['alarmMode'], isFalse);

      final restored = AppSettings.fromMap(map);
      expect(restored.alarmMode, isFalse);
    });

    test('NotificationService detailsFor contains FLAG_INSISTENT when alarmMode is active', () {
      final service = NotificationService.instance;
      final details = service.detailsFor('default', null, true);

      expect(details.android, isNotNull);
      expect(details.android!.fullScreenIntent, isTrue);
      expect(details.android!.additionalFlags, isNotNull);
      expect(details.android!.additionalFlags!.contains(4), isTrue); // FLAG_INSISTENT
    });

    test('NotificationService detailsFor disables FLAG_INSISTENT when alarmMode is false and sound is not alarm', () {
      final service = NotificationService.instance;
      final details = service.detailsFor('default', null, false);

      expect(details.android, isNotNull);
      expect(details.android!.fullScreenIntent, isFalse);
      expect(details.android!.additionalFlags, isNull);
    });

    test('son « défaut » en mode alarme : canal et son d\'alarme système', () {
      final service = NotificationService.instance;
      final (alarmChannel, _) = service.channelFor('default', AppStrings.fr,
          isAlarm: true);
      final (reminderChannel, _) = service.channelFor('default', AppStrings.fr,
          isAlarm: false);
      expect(alarmChannel, 'rappel_v5_default_alarm');
      expect(reminderChannel, 'rappel_v5_default');
      expect(alarmChannel, isNot(reminderChannel),
          reason: 'le son d\'un canal est figé : canal séparé en mode alarme');

      final alarmSound = service.soundFor('default', isAlarm: true);
      expect(
        alarmSound,
        isA<UriAndroidNotificationSound>(),
        reason: 'le défaut en mode alarme doit sonner réellement',
      );
      final reminderSound = service.soundFor('default', isAlarm: false);
      expect(reminderSound, isA<UriAndroidNotificationSound>());
    });
  });
}
