import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/l10n/app_strings.dart';
import 'package:rappel_plus/models/activity.dart';
import 'package:rappel_plus/models/sound_option.dart';
import 'package:rappel_plus/services/notification_service.dart';
import 'package:rappel_plus/services/sound_preview_service.dart';

void main() {
  final monday = DateTime(2026, 8, 10);

  group('Pas de limite artificielle de 50 activités', () {
    test('50 activités sont créées sans aucune limite', () {
      final activities = [
        for (var i = 0; i < 50; i++)
          Activity.create(
            name: 'Activité $i',
            hour: 8 + i % 16,
            minute: (i * 5) % 60,
            date: DateTime(2026, 8, 10),
            repeat: RepeatRule.daily,
          ),
      ];
      expect(activities.length, 50);
      expect(activities.map((a) => a.id).toSet().length, 50,
          reason: 'chaque activité a un ID unique');
    });

    test('200 activités sont créées, chacune avec des IDs distincts', () {
      final activities = [
        for (var i = 0; i < 200; i++)
          Activity.create(
            name: 'Activité $i',
            hour: i % 24,
            minute: 0,
            date: DateTime(2026, 8, 10),
          ),
      ];
      expect(activities.length, 200);
      final ids = activities.map((a) => a.id).toSet();
      final notifIds = activities.map((a) => a.notificationId).toSet();
      expect(ids.length, 200);
      expect(notifIds.length, 200,
          reason: 'les identifiants de notification doivent rester uniques');
    });
  });

  group('Indépendance des activités', () {
    test('chaque activité conserve ses propres champs', () {
      final a = Activity.create(
        name: 'A',
        hour: 6,
        minute: 15,
        date: DateTime(2026, 8, 10),
        repeat: RepeatRule.none,
        sound: 'bell',
        enabled: false,
      );
      final b = Activity.create(
        name: 'B',
        hour: 23,
        minute: 45,
        date: DateTime(2026, 9, 1),
        repeat: RepeatRule.monthly,
        sound: 'chime1',
        enabled: true,
      );
      expect(a.name, 'A');
      expect(b.name, 'B');
      expect(a.hour, 6);
      expect(a.minute, 15);
      expect(b.hour, 23);
      expect(b.minute, 45);
      expect(a.date, DateTime(2026, 8, 10));
      expect(b.date, DateTime(2026, 9, 1));
      expect(a.repeat, RepeatRule.none);
      expect(b.repeat, RepeatRule.monthly);
      expect(a.sound, 'bell');
      expect(b.sound, 'chime1');
      expect(a.enabled, isFalse);
      expect(b.enabled, isTrue);
    });

    test('cocher une activité n\'affecte pas les autres', () {
      final a = Activity.create(name: 'A', hour: 6, minute: 0, date: monday);
      final b = Activity.create(name: 'B', hour: 7, minute: 0, date: monday);
      final aDone = a.withCompletedDay(monday, true);
      expect(aDone.isCompletedOn(monday), isTrue);
      expect(b.isCompletedOn(monday), isFalse);
    });
  });

  group('Heure et date libres', () {
    test('n\'importe quelle heure 00:00–23:59 est conservée', () {
      for (var h = 0; h < 24; h++) {
        for (final m in [0, 30, 59]) {
          final a = Activity.create(
            name: 'X',
            hour: h,
            minute: m,
            date: monday,
          );
          expect(a.hour, h);
          expect(a.minute, m);
        }
      }
    });

    test('la date choisie est bien enregistrée', () {
      final a = Activity.create(
        name: 'Rendez-vous',
        hour: 14,
        minute: 30,
        date: DateTime(2027, 3, 17),
      );
      expect(a.date, DateTime(2027, 3, 17));
      expect(a.isDueOn(DateTime(2027, 3, 17)), isTrue);
      expect(a.isDueOn(DateTime(2027, 3, 18)), isFalse);
    });
  });

  group('Répétitions', () {
    test('unique : due uniquement à sa date', () {
      final a = Activity.create(
        name: 'Once',
        hour: 9,
        minute: 0,
        date: monday,
        repeat: RepeatRule.none,
      );
      expect(a.isDueOn(monday), isTrue);
      expect(a.isDueOn(DateTime(2026, 8, 11)), isFalse);
    });

    test('quotidienne : due tous les jours après la date', () {
      final a = Activity.create(
        name: 'Daily',
        hour: 9,
        minute: 0,
        date: monday,
        repeat: RepeatRule.daily,
      );
      expect(a.isDueOn(DateTime(2026, 8, 10)), isTrue);
      expect(a.isDueOn(DateTime(2026, 8, 25)), isTrue);
      expect(a.isDueOn(DateTime(2026, 8, 9)), isFalse);
    });

    test('hebdomadaire : due les jours sélectionnés seulement', () {
      final a = Activity.create(
        name: 'Weekly',
        hour: 9,
        minute: 0,
        date: monday,
        repeat: RepeatRule.weekly,
        weekdays: [DateTime.monday, DateTime.thursday],
      );
      expect(a.isDueOn(DateTime(2026, 8, 13)), isTrue); // jeudi
      expect(a.isDueOn(DateTime(2026, 8, 16)), isFalse); // dimanche
    });

    test('mensuelle : due le même jour du mois', () {
      final a = Activity.create(
        name: 'Monthly',
        hour: 9,
        minute: 0,
        date: DateTime(2026, 8, 15),
        repeat: RepeatRule.monthly,
      );
      expect(a.isDueOn(DateTime(2026, 9, 15)), isTrue);
      expect(a.isDueOn(DateTime(2026, 9, 16)), isFalse);
    });
  });

  group('Stockage Hive : clés stables et uniques', () {
    test('les clés de date sont formatées et stables', () {
      expect(Activity.dateKey(DateTime(2026, 8, 5)), '2026-08-05');
      expect(Activity.dateKey(DateTime(2026, 12, 31)), '2026-12-31');
      expect(
        Activity.dateKey(DateTime(2026, 8, 5)),
        Activity.dateKey(DateTime(2026, 8, 5)),
      );
    });

    test('l\'ID UUID est conservé après sérialisation', () {
      final a = Activity.create(name: 'X', hour: 10, minute: 0, date: monday);
      final restored = Activity.fromMap(a.toMap());
      expect(restored.id, a.id);
      expect(restored.notificationId, a.notificationId);
      expect(restored.sound, a.sound);
      expect(restored.enabled, a.enabled);
    });

    test('deux activités sérialisées ne partagent pas leurs clés', () {
      final a = Activity.create(name: 'A', hour: 1, minute: 0, date: monday);
      final b = Activity.create(name: 'B', hour: 2, minute: 0, date: monday);
      expect(a.toMap()['id'], isNot(b.toMap()['id']));
      expect(a.toMap()['notificationId'], isNot(b.toMap()['notificationId']));
    });
  });

  group('Canal de notification : un canal par son', () {
    final s = AppStrings.fr;

    test('chaque son intégré a son propre canal', () {
      final service = NotificationService.instance;
      final channels = {
        for (final id in ['default', 'chime1', 'chime2', 'beep', 'bell',
            'whistle', 'alarm'])
          id: service.channelFor(id, s).$1,
      };
      expect(channels.values.toSet().length, 7);
    });

    test('un son personnalisé a un canal dédié à son chemin', () {
      final service = NotificationService.instance;
      const a = 'custom://file:///data/sounds/alarme.mp3';
      const b = 'custom://file:///data/sounds/carillon.mp3';
      final chA = service.customChannelIdFor(a);
      final chB = service.customChannelIdFor(b);
      expect(chA, isNot(chB));
      expect(service.customChannelIdFor(a), chA,
          reason: 'le canal doit être stable pour le même chemin');
    });

    test('le son custom utilise le fichier exact', () {
      final service = NotificationService.instance;
      const custom = 'custom://file:///data/sounds/mon_son.mp3';
      final sound = service.soundFor(custom);
      expect(sound, isA<UriAndroidNotificationSound>());
      expect(sound, isNot(isA<RawResourceAndroidNotificationSound>()));
    });
  });

  group('SoundPreviewService', () {
    test('les sons intégrés ont une source d\'aperçu', () {
      for (final id in ['default', 'chime1', 'chime2', 'beep', 'bell',
          'whistle', 'alarm']) {
        expect(SoundPreviewService.instance.sourceFor(id), isNotNull,
            reason: 'le son $id doit avoir une source');
      }
    });

    test('un son inconnu n\'a pas de source', () {
      expect(SoundPreviewService.instance.sourceFor('inconnu'), isNull);
    });

    test('un son personnalisé cible le fichier local', () {
      final src = SoundPreviewService.instance
          .sourceFor('custom://file:///tmp/audio/coucou.mp3');
      expect(src, isNotNull);
      expect(src, contains('coucou.mp3'));
    });

    test('un fichier personnalisé inexistant est détecté', () {
      expect(
        soundFileExists('custom://file:///nonexistent/xyz.wav'),
        isFalse,
      );
    });

    test('play retourne false pour un son inconnu (pas d\'erreur)', () async {
      final ok = await SoundPreviewService.instance.play('bogus');
      expect(ok, isFalse);
    });
  });

  group('SoundOption', () {
    test('fromId résout les sons custom sans planter', () {
      final opt = SoundOption.fromId('custom://file:///tmp/audio/a.wav');
      expect(opt.id, 'custom://file:///tmp/audio/a.wav');
      expect(opt.label, 'a');
    });

    test('fromId retombe sur le son par défaut pour un id inconnu', () {
      expect(SoundOption.fromId('nimp').id, 'default');
    });
  });

  group('Unicité des identifiants de notification', () {
    test('usedNotificationIds couvre la base et les dérivés hebdo', () {
      final a = Activity.create(
        name: 'A',
        hour: 9,
        minute: 0,
        date: monday,
        repeat: RepeatRule.weekly,
        weekdays: [DateTime.monday, DateTime.thursday],
        notificationId: 100,
      );
      final b = Activity.create(
        name: 'B',
        hour: 10,
        minute: 0,
        date: monday,
        notificationId: 801,
      );
      final used = NotificationService.usedNotificationIds([a, b]);
      expect(used.contains(100), isTrue);
      expect(used.contains(100 * 8 + DateTime.monday), isTrue);
      expect(used.contains(100 * 8 + DateTime.thursday), isTrue);
      expect(used.contains(801), isTrue);
    });

    test('allocateFreshId évite les collisions base et hebdo', () {
      final a = Activity.create(
        name: 'A',
        hour: 9,
        minute: 0,
        date: monday,
        repeat: RepeatRule.weekly,
        weekdays: [DateTime.monday],
        notificationId: 100,
      );
      final b = Activity.create(
        name: 'B',
        hour: 10,
        minute: 0,
        date: monday,
        notificationId: 100 * 8 + DateTime.monday, // 801
      );
      final used = NotificationService.usedNotificationIds([a, b]);
      for (var i = 0; i < 50; i++) {
        final fresh = NotificationService.allocateFreshId(used,
            repeat: RepeatRule.weekly, weekdays: [DateTime.monday]);
        expect(used.contains(fresh), isFalse,
            reason: 'la base $fresh ne doit pas être déjà prise');
        expect(
          used.contains(fresh * 8 + DateTime.monday),
          isFalse,
          reason: 'le dérivé hebdo de $fresh ne doit pas être déjà pris',
        );
      }
    });

    test('ensureUniqueNotificationId ne touche pas une activité saine', () {
      final a = Activity.create(
        name: 'A',
        hour: 9,
        minute: 0,
        date: monday,
        notificationId: 100,
      );
      final b = Activity.create(
        name: 'B',
        hour: 10,
        minute: 0,
        date: monday,
        notificationId: 200,
      );
      final kept =
          NotificationService.ensureUniqueNotificationId(a, [b]);
      expect(identical(kept, a), isTrue,
          reason: 'aucune copie ni changement d\'identifiant sans collision');
      expect(kept.notificationId, 100);
    });

    test('ensureUniqueNotificationId réattribue en cas de collision', () {
      final a = Activity.create(
        name: 'A',
        hour: 9,
        minute: 0,
        date: monday,
        repeat: RepeatRule.weekly,
        weekdays: [DateTime.monday],
        notificationId: 100,
      );
      final b = Activity.create(
        name: 'B',
        hour: 10,
        minute: 0,
        date: monday,
        notificationId: 100 * 8 + DateTime.monday, // dérivé hebdo de A
      );
      final fixed = NotificationService.ensureUniqueNotificationId(b, [a]);
      expect(fixed.notificationId, isNot(b.notificationId),
          reason: 'l\'identifiant doit être réattribué');
      final all = [a, fixed];
      final sets = all.map(NotificationService.idsSet).toList();
      for (var i = 0; i < sets.length; i++) {
        for (var j = i + 1; j < sets.length; j++) {
          expect(sets[i].intersection(sets[j]), isEmpty,
              reason: 'aucun identifiant partagé entre $i et $j');
        }
      }
    });

    test('une liste entière est planifiable sans collision ni ID cassé',
        () {
      final activities = [
        for (var i = 0; i < 50; i++)
          Activity.create(
            name: 'Activité $i',
            hour: 8 + i % 16,
            minute: (i * 5) % 60,
            date: DateTime(2026, 8, 10),
            repeat: i.isEven ? RepeatRule.weekly : RepeatRule.daily,
            weekdays: i.isEven
                ? [DateTime.monday + (i % 7)]
                : const [],
          ),
      ];
      // Simulation du chemin rescheduleAll : garantit l'unicité en place.
      final scheduled = List<Activity>.of(activities);
      for (var i = 0; i < scheduled.length; i++) {
        final others = [...scheduled]..removeAt(i);
        scheduled[i] =
            NotificationService.ensureUniqueNotificationId(scheduled[i], others);
      }
      final sets = scheduled.map(NotificationService.idsSet).toList();
      for (var i = 0; i < sets.length; i++) {
        for (var j = i + 1; j < sets.length; j++) {
          expect(sets[i].intersection(sets[j]), isEmpty,
              reason: 'les activités $i et $j partagent un identifiant');
        }
      }
    });
  });
}
