import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_strings.dart';
import '../models/activity.dart';
import '../models/notification_payload.dart';
import '../models/snooze_action.dart';
import 'custom_sound_service.dart';
import 'quick_action_journal.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _canScheduleExact = false;

  /// Répertoire du journal des actions rapides, accessible aussi bien par
  /// l'application que par l'isolate d'arrière-plan Android.
  String? _journalDir;
  String _locale = 'fr';

  bool get isInitialized => _initialized;

  String get journalDir => _journalDir ?? '';

  /// Langue courante (embarquée dans chaque payload de notification).
  String get locale => _locale;

  /// Nom du fuseau horaire local (embarqué dans chaque payload).
  String localTimeZoneName() {
    try {
      return tz.local.name;
    } catch (_) {
      return 'UTC';
    }
  }

  Future<void> init({
    DidReceiveBackgroundNotificationResponseCallback? onBackgroundAction,
  }) async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Paris'));
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
      onDidReceiveBackgroundNotificationResponse: onBackgroundAction,
    );

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    _canScheduleExact =
        await androidImpl?.canScheduleExactNotifications() ?? false;
    if (!_canScheduleExact) {
      await androidImpl?.requestExactAlarmsPermission();
      _canScheduleExact =
          await androidImpl?.canScheduleExactNotifications() ?? false;
    }

    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    await iosImpl?.requestPermissions(alert: true, sound: true, badge: true);

    await _initJournalDir();

    _initialized = true;
  }

  /// Crée le répertoire du journal des actions rapides sous le dossier de
  /// support de l'application (hors boîte Hive chiffrée, pour rester lisible
  /// par l'isolate d'arrière-plan).
  Future<void> _initJournalDir() async {
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory('${support.path}/quick_actions');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _journalDir = dir.path;
    } catch (_) {
      _journalDir = null;
    }
  }

  Future<QuickActionJournal> _loadJournal() async {
    final dir = _journalDir;
    if (dir == null || dir.isEmpty) return const QuickActionJournal();
    return QuickActionJournalStore.load(dir);
  }

  /// Tous les identifiants de notification liés à une activité
  /// (plusieurs quand les jours de la semaine sont choisis).
  List<int> idsFor(Activity activity) {
    if (activity.repeat == RepeatRule.weekly) {
      return [for (final w in activity.weekdays) activity.notificationId * 8 + w];
    }
    return [activity.notificationId];
  }

  /// Ensemble des identifiants de notification déjà utilisés par [activities].
  /// Inclut le `notificationId` de chaque activité ET ses dérivés hebdo
  /// (`n*8+w`), pour garantir l'unicité au niveau du scheduler Android.
  /// [extraUsed] permet d'exclure aussi les reports en vol du journal.
  static Set<int> usedNotificationIds(
    Iterable<Activity> activities, {
    Set<int> extraUsed = const {},
  }) {
    final used = {...extraUsed};
    for (final a in activities) {
      used.add(a.notificationId);
      if (a.repeat == RepeatRule.weekly) {
        for (final w in a.weekdays) {
          used.add(a.notificationId * 8 + w);
        }
      }
    }
    return used;
  }

  /// Retourne un `notificationId` absent de [used], en vérifiant aussi les
  /// dérivés hebdo (`n*8+w`) quand la semaine est choisie. Ne touche jamais
  /// aux identifiants déjà enregistrés.
  static int allocateFreshId(
    Set<int> used, {
    RepeatRule repeat = RepeatRule.none,
    List<int> weekdays = const [],
  }) {
    while (true) {
      final candidate = Activity.newNotificationId();
      if (used.contains(candidate)) continue;
      if (repeat == RepeatRule.weekly &&
          weekdays.any((w) => used.contains(candidate * 8 + w))) {
        continue;
      }
      return candidate;
    }
  }

  /// Vérifie que [activity] n'entre pas en collision avec [existing].
  /// Retourne une copie avec un `notificationId` garanti unique si nécessaire,
  /// sinon l'activité inchangée. Ne modifie jamais une activité existante.
  static Activity ensureUniqueNotificationId(
    Activity activity,
    List<Activity> existing, {
    Set<int> extraUsed = const {},
  }) {
    final used = usedNotificationIds(existing, extraUsed: extraUsed);
    if (!used.contains(activity.notificationId) &&
        !used.any(idsSet(activity).contains)) {
      return activity;
    }
    return activity.copyWith(
      notificationId: allocateFreshId(used,
          repeat: activity.repeat, weekdays: activity.weekdays),
    );
  }

  /// Ensemble des identifiants qu'une activité utilisera une fois planifiée.
  static Set<int> idsSet(Activity activity) {
    if (activity.repeat != RepeatRule.weekly) return {activity.notificationId};
    return {
      for (final w in activity.weekdays) activity.notificationId * 8 + w,
    };
  }

  /// Planifie les rappels d'une activité (unique ou récurrente).
  Future<void> scheduleActivity(
    Activity activity, {
    int reminderOffsetMinutes = 0,
    AppStrings? s,
  }) async {
    if (!_initialized || !activity.enabled) return;

    switch (activity.repeat) {
      case RepeatRule.none:
        await _scheduleOne(activity, activity.notificationId, null, 0,
            reminderOffsetMinutes, s);
      case RepeatRule.daily:
        await _scheduleOne(activity, activity.notificationId,
            DateTimeComponents.time, 0, reminderOffsetMinutes, s);
      case RepeatRule.weekly:
        for (final w in activity.weekdays) {
          await _scheduleOne(activity, activity.notificationId * 8 + w,
              DateTimeComponents.dayOfWeekAndTime, w, reminderOffsetMinutes, s);
        }
      case RepeatRule.monthly:
        await _scheduleOne(activity, activity.notificationId,
            DateTimeComponents.dayOfMonthAndTime, 0, reminderOffsetMinutes, s);
    }
  }

  Future<void> _scheduleOne(
    Activity activity,
    int id,
    DateTimeComponents? components,
    int weekday,
    int offsetMinutes,
    AppStrings? s,
  ) async {
    final fire = _nextFireTime(activity, weekday, offsetMinutes);
    if (fire == null) return;

    // Ne pas rappeler un jour déjà marqué « terminé » (via l'app ou une
    // action rapide différée), même si l'heure n'est pas encore passée.
    if (activity.isCompletedOn(fire.toLocal())) return;

    final timeLabel = '${activity.hour.toString().padLeft(2, '0')}:'
        '${activity.minute.toString().padLeft(2, '0')}';
    final strings = s ?? AppStrings.fr;
    final body = offsetMinutes > 0
        ? strings.notifReminder(activity.name, offsetMinutes, timeLabel)
        : strings.notifNow(activity.name);

    await _plugin.zonedSchedule(
      id: id,
      title: strings.appName,
      body: body,
      scheduledDate: fire,
      notificationDetails: detailsFor(activity.sound, strings),
      androidScheduleMode: _canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: components,
      payload: _buildPayload(activity, id, fire),
    );
  }

  /// Payload embarqué dans la notification : l'isolate d'arrière-plan s'en
  /// sert pour reconstruire l'activité et connaître l'occurrence touchée.
  String _buildPayload(Activity activity, int id, tz.TZDateTime fire) {
    return NotificationPayload.fromActivity(
      activity,
      occurrence: Activity.dateKey(fire.toLocal()),
      notificationId: id,
      journalDir: journalDir,
      timezone: localTimeZoneName(),
      locale: _locale,
    ).encode();
  }

  /// Détails de notification avec le canal dédié à chaque son et les actions
  /// rapides (Terminé, +5, +10, +30, Demain) sur Android.
  NotificationDetails detailsFor(String soundId, [AppStrings? s]) {
    final strings = s ?? AppStrings.fr;
    final (channelId, channelName) = _channelFor(soundId, strings);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: strings.notifChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        sound: _soundFor(soundId),
        category: AndroidNotificationCategory.reminder,
        onlyAlertOnce: true,
        actions: actionButtons(strings),
      ),
      iOS: DarwinNotificationDetails(
        sound: _iosSoundFor(soundId),
      ),
    );
  }

  String? _iosSoundFor(String soundId) {
    final id = CustomSoundService.fallbackSoundId(soundId);
    if (id.startsWith('custom://')) {
      return null;
    }
    return switch (id) {
      'chime1' => 'chime1.wav',
      'chime2' => 'chime2.wav',
      'beep' => 'beep.wav',
      'bell' => 'bell.wav',
      'whistle' => 'whistle.wav',
      _ => null,
    };
  }

  /// Boutons d'actions rapides affichés sur chaque notification.
  /// L'ordre suit la logique d'usage : Terminé d'abord, puis les reports.
  static List<AndroidNotificationAction> actionButtons(AppStrings s) => [
        AndroidNotificationAction(
          QuickAction.done.id,
          s.actionDone,
          icon: const DrawableResourceAndroidBitmap('ic_action_done'),
        ),
        AndroidNotificationAction(
          QuickAction.snooze5.id,
          s.actionSnooze5,
          icon: const DrawableResourceAndroidBitmap('ic_action_snooze'),
        ),
        AndroidNotificationAction(
          QuickAction.snooze10.id,
          s.actionSnooze10,
          icon: const DrawableResourceAndroidBitmap('ic_action_snooze'),
        ),
        AndroidNotificationAction(
          QuickAction.snooze30.id,
          s.actionSnooze30,
          icon: const DrawableResourceAndroidBitmap('ic_action_snooze'),
        ),
        AndroidNotificationAction(
          QuickAction.tomorrow.id,
          s.actionTomorrow,
          icon: const DrawableResourceAndroidBitmap('ic_action_tomorrow'),
        ),
      ];

  Future<void> cancelActivity(Activity activity) async {
    if (!_initialized) return;
    for (final id in idsFor(activity)) {
      await _plugin.cancel(id: id);
    }
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  /// Repart de zéro : annule tout puis replanifie depuis la liste.
  /// Garantit l'unicité des identifiants sans modifier les activités
  /// déjà enregistrées : seules les activités en collision reçoivent un
  /// identifiant frais. Les reports en vol du journal sont purgés (échus)
  /// puis replanifiés.
  Future<void> rescheduleAll(
    List<Activity> activities, {
    int reminderOffsetMinutes = 0,
    AppStrings? s,
  }) async {
    if (!_initialized) return;
    _locale = identical(s, AppStrings.en) ? 'en' : 'fr';
    await _plugin.cancelAll();

    final journal = (await _loadJournal()).prune(DateTime.now());
    await QuickActionJournalStore.save(journalDir, journal);
    final deferIds = {
      for (final e in journal.snoozes)
        QuickActionJournal.deferIdFor(e.activityId, e.occurrence),
    };

    final scheduled = List<Activity>.of(activities);
    for (var i = 0; i < scheduled.length; i++) {
      final others = [...scheduled]..removeAt(i);
      scheduled[i] = ensureUniqueNotificationId(
        scheduled[i],
        others,
        extraUsed: deferIds,
      );
      await scheduleActivity(scheduled[i],
          reminderOffsetMinutes: reminderOffsetMinutes, s: s);
    }

    await _rearmDeferred(journal, scheduled, s);
  }

  /// Replanifie les reports en vol du journal (un `cancelAll` les a annulés).
  /// Les reports d'activités supprimées sont abandonnés.
  Future<void> _rearmDeferred(
    QuickActionJournal journal,
    List<Activity> activities,
    AppStrings? s,
  ) async {
    final strings = s ?? AppStrings.fr;
    final byId = {for (final a in activities) a.id: a};
    final now = DateTime.now();
    for (final entry in journal.snoozes) {
      final activity = byId[entry.activityId];
      if (activity == null || !entry.fireAt.isAfter(now)) continue;
      final payload = NotificationPayload.fromActivity(
        activity,
        occurrence: entry.occurrence,
        notificationId: QuickActionJournal.deferIdFor(
            entry.activityId, entry.occurrence),
        journalDir: journalDir,
        timezone: localTimeZoneName(),
        locale: _locale,
      );
      await _scheduleDeferOne(payload, entry.fireAt, strings);
    }
  }

  /// Planifie une notification ponctuelle de report via le plugin de
  /// l'application (après [init]).
  Future<bool> _scheduleDeferOne(
    NotificationPayload payload,
    DateTime fireAt,
    AppStrings strings,
  ) async {
    try {
      await _plugin.zonedSchedule(
        id: payload.notificationId,
        title: strings.appName,
        body: deferBody(strings, payload.name, fireAt),
        scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
        notificationDetails: detailsFor(payload.sound, strings),
        androidScheduleMode: _canScheduleExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload.encode(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Planifie un report via un plugin passé en paramètre — utilisé par
  /// l'isolate d'arrière-plan Android (aucune initialisation requise).
  static Future<bool> scheduleDefer({
    required FlutterLocalNotificationsPlugin plugin,
    required NotificationPayload payload,
    required DateTime fireAt,
    required bool exact,
    required AppStrings strings,
  }) async {
    try {
      await plugin.zonedSchedule(
        id: payload.notificationId,
        title: strings.appName,
        body: deferBody(strings, payload.name, fireAt),
        scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
        notificationDetails:
            NotificationService.instance.detailsFor(payload.sound, strings),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload.encode(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Corps du texte d'un report : « reporté à HH:MM » (snooze) ou
  /// « demain à HH:MM ».
  static String deferBody(AppStrings strings, String name, DateTime fireAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final time = '${fireAt.hour.toString().padLeft(2, '0')}:'
        '${fireAt.minute.toString().padLeft(2, '0')}';
    return Activity.dateKey(fireAt) == Activity.dateKey(tomorrow)
        ? strings.notifTomorrow(name, time)
        : strings.notifDeferred(name, time);
  }

  /// Applique les marquages « Terminé » différés (actions rapides Android) :
  /// marque chaque occurrence comme faite dans la liste renvoyée, puis vide le
  /// journal. La persistance de la liste incombe à l'appelant.
  Future<List<Activity>> applyQueuedCompletion(
    List<Activity> activities,
  ) async {
    final journal = await _loadJournal();
    if (journal.pending.isEmpty) return activities;

    final updated = <Activity>[];
    for (final a in activities) {
      var next = a;
      for (final ticket in journal.pending) {
        if (ticket.activityId != a.id) continue;
        final day = Activity.parseDateKey(ticket.occurrence);
        if (!next.isCompletedOn(day)) {
          next = next.withCompletedDay(day, true);
        }
      }
      updated.add(next);
    }

    await QuickActionJournalStore.save(
      journalDir,
      QuickActionJournal(pending: const [], snoozes: journal.snoozes),
    );
    return updated;
  }

  /// Version des canaux : la bump de ce préfixe force Android à recréer
  /// les canaux (le son d'un canal ne peut pas être modifié après création).
  static const _channelPrefix = 'rappel_v3';

  /// Le son « par défaut » utilise le son système par défaut.
  static const _systemDefaultSound =
      UriAndroidNotificationSound('content://settings/system/notification_sound');

  /// Un son personnalisé est référencé par son chemin (`custom://<path>`).
  static String _customSoundPath(String soundId) =>
      soundId.replaceFirst('custom://', '');

  /// Canal stable dédié à un son personnalisé. Android fige un canal une fois
  /// créé : il faut donc UN canal par fichier, sinon changer de son custom
  /// garderait l'ancien. Le hash (md5 court) identifie le chemin exact.
  static String _customChannelId(String soundId) {
    final path = _customSoundPath(soundId);
    final digest = md5.convert(utf8.encode(path)).toString().substring(0, 8);
    return '${_channelPrefix}_custom_$digest';
  }

  (String, String) _channelFor(String soundId, AppStrings s) {
    final id = CustomSoundService.fallbackSoundId(soundId);
    if (id.startsWith('custom://')) {
      return (_customChannelId(id), s.channelName(s.soundCustom));
    }
    final soundName = switch (id) {
      'default' => s.soundDefault,
      'chime1' => s.soundChime1,
      'chime2' => s.soundChime2,
      'beep' => s.soundBeep,
      'bell' => s.soundBell,
      'whistle' => s.soundWhistle,
      'alarm' => s.soundAlarm,
      _ => s.soundDefault,
    };
    return switch (id) {
      'chime1' => ('${_channelPrefix}_chime1', s.channelName(soundName)),
      'chime2' => ('${_channelPrefix}_chime2', s.channelName(soundName)),
      'beep' => ('${_channelPrefix}_beep', s.channelName(soundName)),
      'bell' => ('${_channelPrefix}_bell', s.channelName(soundName)),
      'whistle' => ('${_channelPrefix}_whistle', s.channelName(soundName)),
      'alarm' => ('${_channelPrefix}_alarm', s.channelName(soundName)),
      _ => ('${_channelPrefix}_default', s.channelName(soundName)),
    };
  }

  AndroidNotificationSound? _soundFor(String soundId) {
    final id = CustomSoundService.fallbackSoundId(soundId);
    if (id.startsWith('custom://')) {
      return UriAndroidNotificationSound(_customSoundPath(id));
    }
    return switch (id) {
      'default' => _systemDefaultSound,
      'chime1' => const RawResourceAndroidNotificationSound('chime1'),
      'chime2' => const RawResourceAndroidNotificationSound('chime2'),
      'beep' => const RawResourceAndroidNotificationSound('beep'),
      'bell' => const RawResourceAndroidNotificationSound('bell'),
      'whistle' => const RawResourceAndroidNotificationSound('whistle'),
      'alarm' => const UriAndroidNotificationSound(
          'content://settings/system/alarm_alert'),
      _ => _systemDefaultSound,
    };
  }

  /// Prochaine occurrence future (décallée de [offsetMinutes]), ou `null`
  /// si une activité « une fois » est déjà passée.
  tz.TZDateTime? _nextFireTime(Activity a, int weekday, int offsetMinutes) {
    final now = DateTime.now();
    final base =
        DateTime(a.date.year, a.date.month, a.date.day, a.hour, a.minute);

    DateTime occ;
    switch (a.repeat) {
      case RepeatRule.none:
        occ = base;
        break;
      case RepeatRule.daily:
        occ = DateTime(now.year, now.month, now.day, a.hour, a.minute);
        break;
      case RepeatRule.weekly:
        var daysAhead = weekday - now.weekday;
        if (daysAhead < 0) daysAhead += 7;
        occ = DateTime(now.year, now.month, now.day, a.hour, a.minute)
            .add(Duration(days: daysAhead));
        break;
      case RepeatRule.monthly:
        occ = _nextMonthlyOccurrence(base, now);
        break;
    }

    if (a.repeat == RepeatRule.none && occ.isBefore(now)) return null;

    // Ne pas rappeler avant la date de création de l'activité.
    while (a.repeat != RepeatRule.none &&
        DateTime(occ.year, occ.month, occ.day).isBefore(a.date)) {
      occ = switch (a.repeat) {
        RepeatRule.weekly => occ.add(const Duration(days: 7)),
        RepeatRule.monthly =>
          DateTime(occ.year, occ.month + 1, occ.day, occ.hour, occ.minute),
        _ => occ,
      };
    }

    final withOffset = occ.subtract(Duration(minutes: offsetMinutes));
    if (!withOffset.isAfter(now)) {
      // La prochaine occurrence est déjà passée → on avance d'un cycle.
      occ = switch (a.repeat) {
        RepeatRule.daily => occ.add(const Duration(days: 1)),
        RepeatRule.weekly => occ.add(const Duration(days: 7)),
        RepeatRule.monthly =>
          DateTime(occ.year, occ.month + 1, occ.day, occ.hour, occ.minute),
        RepeatRule.none => occ,
      };
      if (!occ.add(Duration(minutes: -offsetMinutes)).isAfter(now)) return null;
    }

    return tz.TZDateTime.from(
        occ.subtract(Duration(minutes: offsetMinutes)), tz.local);
  }

  DateTime _nextMonthlyOccurrence(DateTime base, DateTime now) {
    var occ =
        DateTime(now.year, now.month, base.day, base.hour, base.minute);
    final lastDay = _daysInMonth(occ.year, occ.month);
    if (occ.day > lastDay) {
      occ = DateTime(occ.year, occ.month, lastDay, occ.hour, occ.minute);
    }
    if (occ.isBefore(now)) {
      final next = DateTime(occ.year, occ.month + 1, base.day,
          base.hour, base.minute);
      final last = _daysInMonth(next.year, next.month);
      return DateTime(next.year, next.month,
          next.day > last ? last : next.day, next.hour, next.minute);
    }
    return occ;
  }

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  /// Identifiant de canal utilisé pour un son personnalisé (test).
  @visibleForTesting
  String customChannelIdFor(String soundId) => _customChannelId(soundId);

  /// Canal + son effectifs pour un identifiant de son (test).
  @visibleForTesting
  (String, String) channelFor(String soundId, AppStrings s) =>
      _channelFor(soundId, s);

  @visibleForTesting
  AndroidNotificationSound? soundFor(String soundId) => _soundFor(soundId);
}
