import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/l10n/app_strings.dart';
import 'package:rappel_plus/models/activity.dart';
import 'package:rappel_plus/models/notification_payload.dart';
import 'package:rappel_plus/models/snooze_action.dart';
import 'package:rappel_plus/services/notification_service.dart';
import 'package:rappel_plus/services/quick_action_journal.dart';

void main() {
  final monday = DateTime(2026, 8, 10);
  final base = DateTime(2026, 8, 10, 9, 0);

  Activity activity({RepeatRule repeat = RepeatRule.none}) => Activity.create(
        name: 'Méditation',
        hour: 9,
        minute: 0,
        date: monday,
        repeat: repeat,
        weekdays: repeat == RepeatRule.weekly ? [DateTime.monday] : const [],
        sound: 'bell',
        notificationId: 42,
      );

  group('QuickAction', () {
    test('les ids sont stables et lisibles par fromId', () {
      expect(QuickAction.done.id, 'done');
      expect(QuickAction.snooze5.id, 'snooze5');
      expect(QuickAction.snooze10.id, 'snooze10');
      expect(QuickAction.snooze30.id, 'snooze30');
      expect(QuickAction.tomorrow.id, 'tomorrow');
      expect(QuickAction.fromId('snooze10'), QuickAction.snooze10);
      expect(QuickAction.fromId('inconnu'), isNull);
      expect(QuickAction.fromId(null), isNull);
    });

    test('seules les actions de report exposent des minutes', () {
      expect(QuickAction.snooze5.snoozeMinutes, 5);
      expect(QuickAction.snooze10.snoozeMinutes, 10);
      expect(QuickAction.snooze30.snoozeMinutes, 30);
      expect(QuickAction.done.snoozeMinutes, isNull);
      expect(QuickAction.tomorrow.snoozeMinutes, isNull);
    });
  });

  group('QuickActionPlanner', () {
    test('Terminé produit un DonePlan', () {
      final plan = QuickActionPlanner.plan(
        activity: activity(),
        action: QuickAction.done,
        now: base,
      );
      expect(plan, isA<DonePlan>());
    });

    test('+5 / +10 / +30 reportent à maintenant + minutes', () {
      final now = DateTime(2026, 8, 10, 12, 0);
      expect(
        (QuickActionPlanner.plan(
          activity: activity(),
          action: QuickAction.snooze5,
          now: now,
        ) as DeferPlan).fireAt,
        now.add(const Duration(minutes: 5)),
      );
      expect(
        (QuickActionPlanner.plan(
          activity: activity(),
          action: QuickAction.snooze30,
          now: now,
        ) as DeferPlan).fireAt,
        now.add(const Duration(minutes: 30)),
      );
    });

    test('Demain vise demain à l\'heure de l\'activité', () {
      final now = DateTime(2026, 8, 10, 21, 0); // un lundi 21h
      final plan = QuickActionPlanner.plan(
        activity: activity(),
        action: QuickAction.tomorrow,
        now: now,
      ) as DeferPlan;
      expect(plan.fireAt, DateTime(2026, 8, 11, 9, 0));
    });

    test('Demain est couvert par une activité quotidienne', () {
      final plan = QuickActionPlanner.plan(
        activity: activity(repeat: RepeatRule.daily),
        action: QuickAction.tomorrow,
        now: DateTime(2026, 8, 10, 21, 0),
      ) as DeferPlan;
      expect(plan.coveredByRule, isTrue);
    });

    test('Demain est couvert quand le lendemain est un jour choisi', () {
      // Lendemain = mardi (11/08/2026) → pas dans [lundi].
      final plan = QuickActionPlanner.plan(
        activity: activity(repeat: RepeatRule.weekly),
        action: QuickAction.tomorrow,
        now: DateTime(2026, 8, 10, 21, 0),
      ) as DeferPlan;
      expect(plan.coveredByRule, isFalse);
    });

    test('Demain est couvert pour le jour du mois exact', () {
      final a = activity(repeat: RepeatRule.monthly)
          .copyWith(date: DateTime(2026, 8, 11));
      // Lendemain = 11/08/2026 → jour du mois exact.
      final plan = QuickActionPlanner.plan(
        activity: a,
        action: QuickAction.tomorrow,
        now: DateTime(2026, 8, 10, 21, 0),
      ) as DeferPlan;
      expect(plan.coveredByRule, isTrue);
    });

    test('Demain n\'est jamais couvert par une activité unique', () {
      final plan = QuickActionPlanner.plan(
        activity: activity(repeat: RepeatRule.none),
        action: QuickAction.tomorrow,
        now: DateTime(2026, 8, 10, 21, 0),
      ) as DeferPlan;
      expect(plan.coveredByRule, isFalse);
    });
  });

  group('NotificationPayload', () {
    test('encode puis decode conserve toutes les données', () {
      final p = NotificationPayload.fromActivity(
        activity(repeat: RepeatRule.weekly),
        occurrence: '2026-08-10',
        notificationId: 42,
        journalDir: '/tmp/journal',
        timezone: 'Europe/Paris',
        locale: 'fr',
      );
      final restored = NotificationPayload.decode(p.encode())!;
      expect(restored.activityId, p.activityId);
      expect(restored.name, 'Méditation');
      expect(restored.sound, 'bell');
      expect(restored.hour, 9);
      expect(restored.minute, 0);
      expect(restored.repeat, RepeatRule.weekly);
      expect(restored.weekdays, [DateTime.monday]);
      expect(restored.occurrence, '2026-08-10');
      expect(restored.notificationId, 42);
      expect(restored.journalDir, '/tmp/journal');
      expect(restored.timezone, 'Europe/Paris');
      expect(restored.locale, 'fr');
    });

    test('decode retourne null pour un payload invalide', () {
      expect(NotificationPayload.decode(null), isNull);
      expect(NotificationPayload.decode(''), isNull);
      expect(NotificationPayload.decode('{pas du json'), isNull);
    });

    test('toActivity reconstruit une activité fidèle', () {
      final p = NotificationPayload.fromActivity(
        activity(repeat: RepeatRule.monthly),
        occurrence: '2026-08-10',
        notificationId: 42,
        journalDir: '',
        timezone: 'UTC',
      );
      final a = p.toActivity();
      expect(a.id, p.activityId);
      expect(a.name, p.name);
      expect(a.hour, 9);
      expect(a.minute, 0);
      expect(a.repeat, RepeatRule.monthly);
      expect(a.sound, 'bell');
      expect(a.notificationId, 42);
    });

    test('copyWith remplace l\'occurrence et l\'id', () {
      final p = NotificationPayload.fromActivity(
        activity(),
        occurrence: '2026-08-10',
        notificationId: 42,
        journalDir: '',
        timezone: 'UTC',
      );
      final d = p.copyWith(occurrence: '2026-08-11', notificationId: 99);
      expect(d.occurrence, '2026-08-11');
      expect(d.notificationId, 99);
      expect(d.activityId, p.activityId);
    });
  });

  group('QuickActionJournal', () {
    test('addPending déduplique le même ticket', () {
      const ticket = PendingAction(
        activityId: 'a1',
        occurrence: '2026-08-10',
        action: QuickAction.done,
      );
      final j = const QuickActionJournal()
          .addPending(ticket)
          .addPending(ticket);
      expect(j.pending.length, 1);
    });

    test('addSnooze remplace un report de la même occurrence', () {
      final j = const QuickActionJournal()
          .addSnooze(SnoozeEntry(
            activityId: 'a1',
            occurrence: '2026-08-10',
            fireAt: DateTime(2026, 8, 10, 9, 5),
          ))
          .addSnooze(SnoozeEntry(
            activityId: 'a1',
            occurrence: '2026-08-10',
            fireAt: DateTime(2026, 8, 10, 9, 10),
          ));
      expect(j.snoozes.length, 1);
      expect(j.snoozes.single.fireAt, DateTime(2026, 8, 10, 9, 10));
    });

    test('removeSnooze et removePending ciblent une occurrence', () {
      var j = const QuickActionJournal()
          .addSnooze(SnoozeEntry(
            activityId: 'a1',
            occurrence: '2026-08-10',
            fireAt: DateTime(2026, 8, 10, 9, 5),
          ))
          .addPending(const PendingAction(
            activityId: 'a1',
            occurrence: '2026-08-10',
            action: QuickAction.done,
          ));
      j = j.removeSnooze('a1', '2026-08-10').removePending('a1', '2026-08-10');
      expect(j.isEmpty, isTrue);
    });

    test('prune retire les reports échus', () {
      final j = const QuickActionJournal()
          .addSnooze(SnoozeEntry(
            activityId: 'a1',
            occurrence: '2026-08-10',
            fireAt: DateTime(2026, 8, 10, 8, 0), // passé
          ))
          .addSnooze(SnoozeEntry(
            activityId: 'a1',
            occurrence: '2026-08-11',
            fireAt: DateTime(2026, 8, 11, 8, 0), // futur
          ));
      final pruned = j.prune(DateTime(2026, 8, 10, 9, 0));
      expect(pruned.snoozes.length, 1);
      expect(pruned.snoozes.single.occurrence, '2026-08-11');
    });

    test('sérialisation JSON aller-retour', () {
      final j = const QuickActionJournal()
          .addSnooze(SnoozeEntry(
            activityId: 'a1',
            occurrence: '2026-08-11',
            fireAt: DateTime(2026, 8, 11, 8, 0),
          ))
          .addPending(const PendingAction(
            activityId: 'a1',
            occurrence: '2026-08-10',
            action: QuickAction.done,
          ));
      final restored = QuickActionJournal.fromJson(j.toJson());
      expect(restored.snoozes.length, 1);
      expect(restored.pending.length, 1);
      expect(restored.snoozes.single.fireAt, DateTime(2026, 8, 11, 8, 0));
      expect(restored.pending.single.action, QuickAction.done);
    });

    test('fromJson tolère un format inconnu', () {
      expect(QuickActionJournal.fromJson(null).isEmpty, isTrue);
      expect(QuickActionJournal.fromJson('nimp').isEmpty, isTrue);
    });

    test('deferIdFor est déterministe et différencié par occurrence', () {
      final a = QuickActionJournal.deferIdFor('a1', '2026-08-10');
      final b = QuickActionJournal.deferIdFor('a1', '2026-08-11');
      final c = QuickActionJournal.deferIdFor('a2', '2026-08-10');
      expect(a, QuickActionJournal.deferIdFor('a1', '2026-08-10'));
      expect(a, isNot(b));
      expect(a, isNot(c));
      expect(a, inInclusiveRange(0, 0x7FFFFFFF));
    });
  });

  group('NotificationService — actions rapides', () {
    test('actionButtons expose les 5 actions dans l\'ordre attendu', () {
      final buttons = NotificationService.actionButtons(AppStrings.fr);
      expect(buttons.length, 5);
      expect(
        buttons.map((b) => b.id).toList(),
        ['done', 'snooze5', 'snooze10', 'snooze30', 'tomorrow'],
      );
      expect(buttons.first.title, AppStrings.fr.actionDone);
      expect(buttons[3].title, AppStrings.fr.actionSnooze30);
    });

    test('detailsFor embarque les actions rapides (catégorie alarme par défaut)', () {
      final details =
          NotificationService.instance.detailsFor('bell', AppStrings.fr);
      final android = details.android!;
      expect(android.actions, isNotNull);
      expect(android.actions!.length, 5);
      // Mode alarme (défaut) : catégorie alarme, comme un réveil.
      expect(android.category, AndroidNotificationCategory.alarm);
    });

    test('detailsFor en mode non-alarme utilise la catégorie rappel', () {
      final details =
          NotificationService.instance.detailsFor('bell', AppStrings.fr, false);
      expect(details.android!.category, AndroidNotificationCategory.reminder);
    });

    test('deferBody : report à aujourd\'hui vs demain', () {
      final today = DateTime.now();
      final morning = DateTime(today.year, today.month, today.day, 0, 5);
      final bodyDeferred =
          NotificationService.deferBody(AppStrings.fr, 'Méditation', morning);
      expect(bodyDeferred, AppStrings.fr.notifDeferred('Méditation', '00:05'));

      final tomorrow = DateTime(today.year, today.month, today.day + 1, 7, 30);
      final bodyTomorrow =
          NotificationService.deferBody(AppStrings.fr, 'Méditation', tomorrow);
      expect(
        bodyTomorrow,
        AppStrings.fr.notifTomorrow('Méditation', '07:30'),
      );
    });

    test('usedNotificationIds tient compte de extraUsed', () {
      final a = activity();
      final used = NotificationService.usedNotificationIds(
        [a],
        extraUsed: {123},
      );
      expect(used.contains(42), isTrue);
      expect(used.contains(123), isTrue);
    });

    test('ensureUniqueNotificationId évite aussi les ids extra', () {
      final a = activity();
      final fixed = NotificationService.ensureUniqueNotificationId(
        a,
        const [],
        extraUsed: {42},
      );
      expect(fixed.notificationId, isNot(42));
    });
  });
}
