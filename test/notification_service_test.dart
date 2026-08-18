import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:rappel_plus/models/activity.dart';
import 'package:rappel_plus/services/notification_service.dart';

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  final service = NotificationService.instance;

  group('NotificationService - nextFireTime', () {
    final now = DateTime.utc(2024, 1, 1, 10, 0); // lundi 10:00

    test('activité unique : fire strictement dans le futur', () {
      final a = Activity.create(
        name: 'Une fois',
        hour: 10,
        minute: 0,
        date: DateTime(2024, 1, 1),
        repeat: RepeatRule.none,
      );
      final fire = service.nextFireTime(a, 0, 0, now);
      expect(fire, isNull); // déjà passée
    });

    test('activité unique : fire à 2 min dans le futur', () {
      final a = Activity.create(
        name: 'Bientôt',
        hour: 10,
        minute: 2,
        date: DateTime(2024, 1, 1),
        repeat: RepeatRule.none,
      );
      final fire = service.nextFireTime(a, 0, 0, now);
      expect(fire, isNotNull);
      expect(fire!.isAfter(tz.TZDateTime.from(now, tz.local)), isTrue);
      expect(fire.minute, 2);
    });

    test('quotidien : fire TOUJOURS dans le futur même avec gros offset', () {
      final a = Activity.create(
        name: 'Quotidien',
        hour: 10,
        minute: 0,
        date: DateTime(2024, 1, 1),
        repeat: RepeatRule.daily,
      );
      // offset 120 min : sans correction, fire serait 09:00 (passé).
      final fire = service.nextFireTime(a, 0, 120, now);
      expect(fire, isNotNull, reason: 'le fire ne doit jamais être null ici');
      expect(fire!.isAfter(tz.TZDateTime.from(now, tz.local)), isTrue,
          reason: 'fire doit être strictement dans le futur');
    });

    test('quotidien : offset 0 → occurrence suivante (lendemain)', () {
      final a = Activity.create(
        name: 'Quotidien',
        hour: 10,
        minute: 0,
        date: DateTime(2024, 1, 1),
        repeat: RepeatRule.daily,
      );
      final fire = service.nextFireTime(a, 0, 0, now);
      expect(fire, isNotNull);
      expect(fire!.day, 2); // lendemain 10:00
      expect(fire.hour, 10);
    });

    test('hebdomadaire : bon jour et fire dans le futur', () {
      final a = Activity.create(
        name: 'Hebdo',
        hour: 9,
        minute: 30,
        date: DateTime(2024, 1, 1),
        repeat: RepeatRule.weekly,
        weekdays: [4], // jeudi
      );
      final fire = service.nextFireTime(a, 4, 0, now);
      expect(fire, isNotNull);
      expect(fire!.weekday, 4);
      expect(fire.isAfter(tz.TZDateTime.from(now, tz.local)), isTrue);
    });

    test('hebdomadaire : gros offset → toujours dans le futur', () {
      final a = Activity.create(
        name: 'Hebdo',
        hour: 10,
        minute: 0,
        date: DateTime(2024, 1, 1),
        repeat: RepeatRule.weekly,
        weekdays: [1], // lundi
      );
      final fire = service.nextFireTime(a, 1, 24 * 60, now);
      expect(fire, isNotNull);
      expect(fire!.isAfter(tz.TZDateTime.from(now, tz.local)), isTrue);
    });

    test('mensuel : jour clampé fin de mois', () {
      final a = Activity.create(
        name: 'Mensuel',
        hour: 8,
        minute: 0,
        date: DateTime(2024, 1, 31),
        repeat: RepeatRule.monthly,
      );
      // 31 janvier → clampé au dernier jour du mois courant (31 janv. > now ?)
      final fire = service.nextFireTime(a, 0, 0, now);
      expect(fire, isNotNull);
      expect(fire!.isAfter(tz.TZDateTime.from(now, tz.local)), isTrue);
    });
  });
}
