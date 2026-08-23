import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_strings_ext.dart';
import '../models/activity.dart';
import '../models/notification_payload.dart';
import '../models/snooze_action.dart';
import 'notification_service.dart';
import 'quick_action_journal.dart';

/// Point d'entrée de l'isolate d'arrière-plan Android.
///
/// Une action rapide ne rouvre pas l'application : ce callback s'exécute dans
/// un isolate dédié qui n'a accès qu'aux canaux de flutter_local_notifications
/// et au journal JSON. Les marquages « Terminé » sont donc différés puis
/// appliqués au prochain démarrage de l'application.
@pragma('vm:entry-point')
Future<void> notificationActionCallback(NotificationResponse response) async {
  await QuickActionHandler.handleBackground(response);
}

abstract final class QuickActionHandler {
  /// Traite une action dans l'isolate d'arrière-plan (Android).
  static Future<void> handleBackground(NotificationResponse response) async {
    final payload = NotificationPayload.decode(response.payload);
    final action = QuickAction.fromId(response.actionId);
    if (payload == null || action == null) return;

    final plugin = FlutterLocalNotificationsPlugin();
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(payload.timezone));
    } catch (_) {}

    var journal = (await QuickActionJournalStore.load(payload.journalDir))
        .prune(DateTime.now());
    final activity = payload.toActivity();

    switch (action) {
      case QuickAction.done:
        // Le « Terminé » est différé : appliqué au prochain démarrage.
        journal = journal
            .addPending(PendingAction(
              activityId: payload.activityId,
              occurrence: payload.occurrence,
              action: action,
            ))
            .removeSnooze(payload.activityId, payload.occurrence);
        await QuickActionJournalStore.save(payload.journalDir, journal);

      case QuickAction.snooze5:
      case QuickAction.snooze10:
      case QuickAction.snooze30:
      case QuickAction.tomorrow:
        final plan = QuickActionPlanner.plan(
          activity: activity,
          action: action,
          now: DateTime.now(),
        ) as DeferPlan;

        // La règle de répétition couvre déjà le jour cible : rien à planifier.
        if (plan.coveredByRule) {
          journal = journal.removeSnooze(payload.activityId, payload.occurrence);
          await QuickActionJournalStore.save(payload.journalDir, journal);
          return;
        }

        final occurrence = Activity.dateKey(plan.fireAt);
        final deferPayload = payload.copyWith(
          occurrence: occurrence,
          notificationId:
              QuickActionJournal.deferIdFor(payload.activityId, occurrence),
        );
        final strings = appStringsFor(payload.locale);

        // Alarme exacte si l'OS l'autorise encore depuis cet isolate
        // (Android 12+ : la permission SCHEDULE_EXACT_ALARM peut être
        // révocable). Un report d'alarme inexact peut sonner avec 15 min
        // de retard en Doze — on tente donc l'exact d'abord.
        var exact = true;
        try {
          final androidImpl =
              plugin.resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();
          exact =
              await androidImpl?.canScheduleExactNotifications() ?? false;
        } catch (_) {}

        final scheduled = await NotificationService.scheduleDefer(
          plugin: plugin,
          payload: deferPayload,
          fireAt: plan.fireAt,
          exact: exact,
          strings: strings,
        );

        if (scheduled) {
          journal = journal
              .addSnooze(SnoozeEntry(
                activityId: payload.activityId,
                occurrence: occurrence,
                fireAt: plan.fireAt,
              ))
              .removeSnooze(payload.activityId, payload.occurrence);
          await QuickActionJournalStore.save(payload.journalDir, journal);
        }
    }
  }
}
