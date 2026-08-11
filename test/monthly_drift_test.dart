import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/models/activity.dart';
import 'package:rappel_plus/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Paris'));
  final service = NotificationService.instance;

  group('Récurrence mensuelle sans dérive du jour', () {
    Activity monthly(int day, int hour, int minute) => Activity.create(
          name: 'Mensuel $day',
          hour: hour,
          minute: minute,
          date: DateTime(2026, 1, day, hour, minute),
          repeat: RepeatRule.monthly,
        );

    test('le jour de base est conservé d un mois à l autre (31 → 28 → 31)',
        () {
      final a = monthly(31, 9, 0);

      // Fin janvier : la prochaine occurrence est le 31 janv.
      final jan = service.nextFireTime(a, 0, 0, DateTime(2026, 1, 20, 12, 0));
      expect(jan!.day, 31);
      expect(jan.month, 1);

      // Fin février (mois court) : clamp au 28, jamais 31.
      final feb = service.nextFireTime(a, 0, 0, DateTime(2026, 2, 10, 12, 0));
      expect(feb!.day, 28);
      expect(feb.month, 2);

      // Début mars : l occurrence déjà passée du 28 févr. doit avancer
      // vers le 31 mars (pas le 28 mars) : c est le bug de dérive.
      final mar = service.nextFireTime(a, 0, 0, DateTime(2026, 3, 1, 12, 0));
      expect(mar!.day, 31);
      expect(mar.month, 3);
    });

    test('un décalage de rappel ne déborde pas d un mois (31 avril → 31 mai)',
        () {
      final a = monthly(31, 9, 0);

      // 31 mars, rappel 30 min avant : le 31 mars 08:30.
      final mar =
          service.nextFireTime(a, 0, 30, DateTime(2026, 3, 20, 12, 0));
      expect(mar!.day, 31);
      expect(mar.month, 3);
      expect(mar.hour, 8);
      expect(mar.minute, 30);

      // Début mai : l occurrence du 30 avril est passée, la suivante doit
      // être le 31 mai — pas un débordement en juin (DateTime auto-normalise).
      final may =
          service.nextFireTime(a, 0, 30, DateTime(2026, 5, 1, 12, 0));
      expect(may!.month, 5);
      expect(may.day, 31);
    });

    test('une activité du 30 garde le 30, puis le 28 en février', () {
      final a = monthly(30, 9, 0);

      final feb = service.nextFireTime(a, 0, 0, DateTime(2026, 2, 1, 12, 0));
      expect(feb!.day, 28);
      expect(feb.month, 2);

      final mar = service.nextFireTime(a, 0, 0, DateTime(2026, 3, 1, 12, 0));
      expect(mar!.day, 30);
      expect(mar.month, 3);
    });
  });
}
