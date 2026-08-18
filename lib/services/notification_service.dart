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

  /// Nombre de mois planifiés à l'avance pour une activité mensuelle.
  /// `dayOfMonthAndTime` de Android épinglerait la récurrence au jour du
  /// premier son (dérive 31 → 28 définitif) ; on programme donc chaque
  /// occurrence ponctuellement sur un horizon glissant.
  static const int _monthlyHorizonMonths = 12;

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
        // Monochrome drawable required by Android's notification status bar.
        android: AndroidInitializationSettings('@drawable/ic_notification'),
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
          AndroidFlutterLocalNotificationsPlugin
        >();
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
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosImpl?.requestPermissions(alert: true, sound: true, badge: true);

    await _initJournalDir();

    _initialized = true;
  }

  /// Initialise uniquement le répertoire du journal des actions rapides.
  /// Légère (aucun plugin, aucune permission) : suffisant pour appliquer les
  /// marquages « Terminé » différés avant le démarrage complet des
  /// notifications.
  Future<void> initJournalDir() async {
    await _initJournalDir();
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

  /// Tous les identifiants de notification liés à une activité.
  /// - hebdo : un ID par jour (`n*8+w`, w ∈ 1..7) ;
  /// - mensuel : un ID par occurrence de l'horizon (`n*8+8+i`, i ∈ 0..11) ;
  /// - sinon (unique, quotidien) : l'ID de base `n`.
  /// Ne jamais annuler trop (ce serait tuer les rappels) ni trop peu (ce
  /// serait laisser sonner des rappels orphelins).
  List<int> idsFor(Activity activity) {
    if (activity.repeat == RepeatRule.weekly) {
      return [
        for (final w in activity.weekdays) activity.notificationId * 8 + w,
      ];
    }
    if (activity.repeat == RepeatRule.monthly) {
      return [
        for (var i = 0; i < _monthlyHorizonMonths; i++)
          _monthlySlotId(activity, i),
      ];
    }
    return [activity.notificationId];
  }

  /// Ensemble des identifiants de notification déjà utilisés par [activities].
  /// Inclut le `notificationId` de chaque activité, ses dérivés hebdo
  /// (`n*8+w`) et ses slots mensuels (`n*8+8+i`), pour garantir l'unicité au
  /// niveau du scheduler Android.
  /// [extraUsed] permet d'exclure aussi les reports en vol du journal.
  static Set<int> usedNotificationIds(
    Iterable<Activity> activities, {
    Set<int> extraUsed = const {},
  }) {
    final used = {...extraUsed};
    for (final a in activities) {
      used.add(a.notificationId);
      if (a.notificationId > 0) {
        // Plage complète commune aux dérivés hebdo (w 1..7) ET mensuels
        // (i 0..11) : on marque tout pour qu'aucun slot ne se chevauche
        // entre deux activités différentes.
        for (var s = 1; s < 8 + _monthlyHorizonMonths; s++) {
          used.add(a.notificationId * 8 + s);
        }
      }
    }
    return used;
  }

  /// Retourne un `notificationId` absent de [used], en vérifiant aussi les
  /// dérivés hebdo (`n*8+w`) et les slots mensuels (`n*8+8+i`) quand la
  /// famille de l'activité les utilise. Ne touche jamais aux identifiants
  /// déjà enregistrés.
  static int allocateFreshId(
    Set<int> used, {
    RepeatRule repeat = RepeatRule.none,
    List<int> weekdays = const [],
  }) {
    while (true) {
      final candidate = Activity.newNotificationId();
      if (used.contains(candidate)) continue;
      // Plage de dérivés que cette activité occupera (w 1..7 et/ou i 0..11).
      final slotCount = repeat == RepeatRule.monthly
          ? 1 + _monthlyHorizonMonths
          : (repeat == RepeatRule.weekly ? 8 : 1);
      var blocked = false;
      for (var s = 1; s < slotCount; s++) {
        if (used.contains(candidate * 8 + s)) {
          blocked = true;
          break;
        }
      }
      if (blocked) continue;
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
      notificationId: allocateFreshId(
        used,
        repeat: activity.repeat,
        weekdays: activity.weekdays,
      ),
    );
  }

  /// Ensemble des identifiants qu'une activité utilisera une fois planifiée.
  static Set<int> idsSet(Activity activity) {
    if (activity.repeat == RepeatRule.weekly) {
      return {for (final w in activity.weekdays) activity.notificationId * 8 + w};
    }
    if (activity.repeat == RepeatRule.monthly) {
      return {
        for (var i = 0; i < _monthlyHorizonMonths; i++)
          _monthlySlotId(activity, i),
      };
    }
    return {activity.notificationId};
  }

  /// Planifie les rappels d'une activité (unique ou récurrente).
  Future<void> scheduleActivity(
    Activity activity, {
    int reminderOffsetMinutes = 0,
    AppStrings? s,
    bool alarmMode = true,
  }) async {
    if (!_initialized || !activity.enabled) return;

    switch (activity.repeat) {
      case RepeatRule.none:
        await _scheduleOne(
          activity,
          activity.notificationId,
          null,
          0,
          reminderOffsetMinutes,
          s,
          alarmMode,
        );
      case RepeatRule.daily:
        await _scheduleOne(
          activity,
          activity.notificationId,
          DateTimeComponents.time,
          0,
          reminderOffsetMinutes,
          s,
          alarmMode,
        );
      case RepeatRule.weekly:
        for (final w in activity.weekdays) {
          await _scheduleOne(
            activity,
            activity.notificationId * 8 + w,
            DateTimeComponents.dayOfWeekAndTime,
            w,
            reminderOffsetMinutes,
            s,
            alarmMode,
          );
        }
      case RepeatRule.monthly:
        // Les jours 29-31 n'existent pas tous les mois : `dayOfMonthAndTime`
        // épinglerait la récurrence au jour du premier son (dérive
        // définitive, ex. 31 → 28). On programme plutôt l'horizon des
        // prochaines occurrences, chacune avec son propre jour calculé
        // (31 → 28 févr. → 31 mars).
        for (final (id, fire) in _monthlyOccurrences(
          activity,
          reminderOffsetMinutes,
        )) {
          await _scheduleMonthlyOne(
            activity,
            id,
            fire,
            reminderOffsetMinutes,
            s,
            alarmMode,
          );
        }
    }
  }

  /// Liste des prochaines occurrences mensuelles d'une activité, indexées par
  /// un identifiant de notification fixe (le slot i de l'activité est TOUJOURS
  /// `n*8+8+i`, stable quel que soit le mois : [idsFor] peut ainsi tout
  /// annuler). Chaque occurrence est programmée ponctuellement (jamais de
  /// répétition native Android) pour préserver le jour de base
  /// (31 → 28 févr. → 31 mars).
  List<(int, tz.TZDateTime)> _monthlyOccurrences(
    Activity activity,
    int reminderOffsetMinutes, [
    DateTime? now,
  ]) {
    final clock = now ?? DateTime.now();
    final result = <(int, tz.TZDateTime)>[];
    var from = clock;
    for (var i = 0; i < _monthlyHorizonMonths; i++) {
      final fire = _nextFireTime(activity, 0, reminderOffsetMinutes, from);
      if (fire == null) break;
      result.add((_monthlySlotId(activity, i), fire));
      // Avancer `from` après le fire pour que l'itération suivante calcule
      // l'occurrence du mois d'après (jamais deux fire dans le même mois).
      from = DateTime(
        fire.year,
        fire.month + 1,
        1,
        fire.hour,
        fire.minute,
      );
    }
    return result;
  }

  /// Identifiant fixe de l'occurrence mensuelle i de l'activité.
  /// Plage `n*8+8 .. n*8+8+(_monthlyHorizonMonths-1)`, disjointe des slots
  /// hebdo `n*8+1 .. n*8+7` et de l'ID de base `n` : stable dans le temps
  /// (les annulations de [cancelActivity]/[cancelOccurrence] restent simples).
  static int _monthlySlotId(Activity activity, int i) =>
      activity.notificationId * 8 + 8 + i;

  /// Programme une occurrence mensuelle ponctuelle (avec décalage de rappel
  /// appliqué, comme [_scheduleOne]).
  Future<void> _scheduleMonthlyOne(
    Activity activity,
    int id,
    tz.TZDateTime fire,
    int offsetMinutes,
    AppStrings? s,
    bool alarmMode,
  ) async {
    if (activity.isCompletedOn(fire.toLocal())) return;
    final timeLabel =
        '${activity.hour.toString().padLeft(2, '0')}:'
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
      notificationDetails: detailsFor(activity.sound, strings, alarmMode),
      androidScheduleMode: _canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: null, // ponctuel : le jour varie chaque mois
      payload: _buildPayload(activity, id, fire, alarmMode: alarmMode),
    );
  }

  Future<void> _scheduleOne(
    Activity activity,
    int id,
    DateTimeComponents? components,
    int weekday,
    int offsetMinutes,
    AppStrings? s,
    bool alarmMode, [
    DateTime? from,
  ]) async {
    final fire = _nextFireTime(activity, weekday, offsetMinutes, from);
    if (fire == null) return;

    // Ne pas rappeler un jour déjà marqué « terminé » (via l'app ou une
    // action rapide différée), même si l'heure n'est pas encore passée.
    if (activity.isCompletedOn(fire.toLocal())) return;

    final timeLabel =
        '${activity.hour.toString().padLeft(2, '0')}:'
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
      notificationDetails: detailsFor(activity.sound, strings, alarmMode),
      androidScheduleMode: _canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: components,
      payload: _buildPayload(activity, id, fire, alarmMode: alarmMode),
    );
  }

/// Payload embarqué dans la notification : l'isolate d'arrière-plan s'en
  /// sert pour reconstruire l'activité et connaître l'occurrence touchée.
  /// Le mode alarme est embarqué pour que les reports (snoozes) respectent
  /// le réglage de l'utilisateur au lieu de repartir en alarme par défaut.
  String _buildPayload(Activity activity, int id, tz.TZDateTime fire,
      {bool alarmMode = false}) {
    return NotificationPayload.fromActivity(
      activity,
      occurrence: Activity.dateKey(fire.toLocal()),
      notificationId: id,
      journalDir: journalDir,
      timezone: localTimeZoneName(),
      locale: _locale,
      alarmMode: alarmMode,
    ).encode();
  }

  /// Détails de notification avec le canal dédié à chaque son et les actions
  /// rapides (Terminé, +5, +10, +30, Demain) sur Android.
  /// Quand [alarmMode] est actif (ou son "alarm"), le drapeau natif
  /// `FLAG_INSISTENT` (0x00000004) fait répéter la sonnerie en boucle jusqu'à
  /// l'intervention de l'utilisateur.
  NotificationDetails detailsFor(
    String soundId, [
    AppStrings? s,
    bool alarmMode = true,
  ]) {
    final strings = s ?? AppStrings.fr;
    final id = CustomSoundService.fallbackSoundId(soundId);
    final isAlarm = id == 'alarm' || alarmMode;
    final (channelId, channelName) = _channelFor(
      soundId,
      strings,
      isAlarm: isAlarm,
    );
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: strings.notifChannelDesc,
        importance: isAlarm ? Importance.max : Importance.high,
        priority: isAlarm ? Priority.max : Priority.high,
        channelBypassDnd: isAlarm,
        sound: _soundFor(soundId, isAlarm: isAlarm),
        category: isAlarm
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.reminder,
        audioAttributesUsage: isAlarm
            ? AudioAttributesUsage.alarm
            : AudioAttributesUsage.notification,
        fullScreenIntent: isAlarm,
        additionalFlags: isAlarm
            ? Int32List.fromList([4])
            : null, // 0x4 = FLAG_INSISTENT
        onlyAlertOnce: false,
        actions: actionButtons(strings),
      ),
      iOS: DarwinNotificationDetails(
        sound: _iosSoundFor(soundId),
        presentSound: true,
        presentAlert: true,
        presentBadge: true,
        interruptionLevel: isAlarm
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
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

  /// Annule toutes les alarmes d'une activité, y compris les reports
  /// (+5, +10, +30 min, Demain) encore en vol. Nettoie aussi le journal des
  /// actions rapides pour ne laisser aucun rappel orphelin sonner après la
  /// suppression.
  Future<void> cancelActivity(Activity activity) async {
    if (!_initialized) return;
    for (final id in idsFor(activity)) {
      await _plugin.cancel(id: id);
    }
    // Reports d'occurrences de cette activité (snoozes en vol).
    final journal = await _loadJournal();
    for (final s in journal.snoozes) {
      if (s.activityId == activity.id) {
        await _plugin.cancel(
          id: QuickActionJournal.deferIdFor(s.activityId, s.occurrence),
        );
      }
    }
    if (journal.snoozes.any((s) => s.activityId == activity.id) ||
        journal.pending.any((p) => p.activityId == activity.id)) {
      final cleaned = QuickActionJournal(
        pending: journal.pending
            .where((p) => p.activityId != activity.id)
            .toList(),
        snoozes: journal.snoozes
            .where((s) => s.activityId != activity.id)
            .toList(),
      );
      await QuickActionJournalStore.save(journalDir, cleaned);
    }
  }

  /// Annule l'alarme d'une occurrence précise : le jour [day].
  ///
  /// Pour une activité hebdomadaire, seule l'alarme du jour concerné est
  /// annulée (chaque jour a son propre identifiant). Quotidien partage une
  /// seule alarme récurrente : on annule la série PUIS on la réarme à partir
  /// du lendemain du jour marqué « terminé ». Mensuel : les occurrences sont
  /// ponctuelles (un slot par mois), donc seules les occurrences du jour et de
  /// la suite sont réarmées.
  Future<void> cancelOccurrence(
    Activity activity,
    DateTime day, {
    int reminderOffsetMinutes = 0,
    AppStrings? s,
    bool alarmMode = true,
  }) async {
    if (!_initialized || !activity.enabled) return;
    switch (activity.repeat) {
      case RepeatRule.weekly:
        await _plugin.cancel(id: activity.notificationId * 8 + day.weekday);
      case RepeatRule.daily:
        await _plugin.cancel(id: activity.notificationId);
        await _rearmSeriesFrom(
          activity,
          DateTime(day.year, day.month, day.day).add(const Duration(days: 1)),
          reminderOffsetMinutes: reminderOffsetMinutes,
          s: s,
          alarmMode: alarmMode,
        );
      case RepeatRule.monthly:
        await _rearmMonthlyFrom(
          activity,
          DateTime(day.year, day.month, day.day).add(const Duration(days: 1)),
          reminderOffsetMinutes: reminderOffsetMinutes,
          s: s,
          alarmMode: alarmMode,
        );
      case RepeatRule.none:
        await _plugin.cancel(id: activity.notificationId);
    }
  }

  /// Une occurrence marquée « terminée » est re-cochée : restaure son
  /// alarme (et la série des récurrents) sans toucher aux autres jours.
  Future<void> reactivateOccurrence(
    Activity activity,
    DateTime day, {
    int reminderOffsetMinutes = 0,
    AppStrings? s,
    bool alarmMode = true,
  }) async {
    if (!_initialized || !activity.enabled) return;
    final weekly = activity.repeat == RepeatRule.weekly;
    await _scheduleOne(
      activity,
      weekly ? activity.notificationId * 8 + day.weekday : activity.notificationId,
      switch (activity.repeat) {
        RepeatRule.weekly => DateTimeComponents.dayOfWeekAndTime,
        RepeatRule.daily => DateTimeComponents.time,
        RepeatRule.monthly => DateTimeComponents.dayOfMonthAndTime,
        RepeatRule.none => null,
      },
      weekly ? day.weekday : 0,
      reminderOffsetMinutes,
      s,
      alarmMode,
      DateTime(day.year, day.month, day.day),
    );
  }

  /// Réarme une série récurrente (quotidienne, un seul identifiant) à partir
  /// du jour [startDay] pour exclure le jour marqué « terminé ».
  Future<void> _rearmSeriesFrom(
    Activity activity,
    DateTime startDay, {
    required int reminderOffsetMinutes,
    required AppStrings? s,
    required bool alarmMode,
  }) async {
    await _scheduleOne(
      activity,
      activity.notificationId,
      DateTimeComponents.time,
      0,
      reminderOffsetMinutes,
      s,
      alarmMode,
      startDay,
    );
  }

  /// Réarme les occurrences mensuelles ponctuelles à partir de [startDay]
  /// (voir [_monthlyOccurrences]). Annule d'abord l'horizon existant pour
  /// éviter des doublons.
  Future<void> _rearmMonthlyFrom(
    Activity activity,
    DateTime startDay, {
    required int reminderOffsetMinutes,
    required AppStrings? s,
    required bool alarmMode,
  }) async {
    await _plugin.cancel(id: activity.notificationId);
    for (final id in idsFor(activity)) {
      await _plugin.cancel(id: id);
    }
    for (final (id, fire) in _monthlyOccurrences(
      activity,
      reminderOffsetMinutes,
      startDay,
    )) {
      await _scheduleMonthlyOne(
        activity,
        id,
        fire,
        reminderOffsetMinutes,
        s,
        alarmMode,
      );
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
    bool alarmMode = true,
  }) async {
    if (!_initialized) return;
    // Langue portée par l'instance passée (repli : celle déjà en mémoire).
    _locale = (s != null && s.code.isNotEmpty) ? s.code : _locale;
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
      await scheduleActivity(
        scheduled[i],
        reminderOffsetMinutes: reminderOffsetMinutes,
        s: s,
        alarmMode: alarmMode,
      );
    }

    await _rearmDeferred(journal, scheduled, s, alarmMode);
  }

  /// Replanifie les reports en vol du journal (un `cancelAll` les a annulés).
  /// Les reports d'activités supprimées sont abandonnés.
  Future<void> _rearmDeferred(
    QuickActionJournal journal,
    List<Activity> activities,
    AppStrings? s,
    bool alarmMode,
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
          entry.activityId,
          entry.occurrence,
        ),
        journalDir: journalDir,
        timezone: localTimeZoneName(),
        locale: _locale,
        alarmMode: alarmMode,
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
        notificationDetails: detailsFor(payload.sound, strings, payload.alarmMode),
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
        notificationDetails: NotificationService.instance.detailsFor(
          payload.sound,
          strings,
          payload.alarmMode,
        ),
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
    final time =
        '${fireAt.hour.toString().padLeft(2, '0')}:'
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
        if (day == null) continue; // occurrence illisible : écartée
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
  static const _channelPrefix = 'rappel_v6';

  /// Le son « par défaut » utilise le son système par défaut (rappel).
  static const _systemDefaultSound = UriAndroidNotificationSound(
    'content://settings/system/notification_sound',
  );

  /// En mode alarme, le son « par défaut » doit sonner réellement : le son de
  /// notification peut être silencieux ou réglé en vibreur seul sur certains
  /// appareils. Le son d'alarme système, lui, sonne toujours.
  static const _systemAlarmSound = UriAndroidNotificationSound(
    'content://settings/system/alarm_alert',
  );

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

  (String, String) _channelFor(String soundId, AppStrings s,
      {bool isAlarm = false}) {
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
    // Le canal du son « par défaut » dépend du mode : le son d'un canal est
    // figé par Android, un canal séparé en mode alarme garantit un vrai son.
    if (id == 'default') {
      return isAlarm
          ? ('${_channelPrefix}_default_alarm', s.channelName(soundName))
          : ('${_channelPrefix}_default', s.channelName(soundName));
    }
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

  AndroidNotificationSound? _soundFor(String soundId,
      {bool isAlarm = false}) {
    final id = CustomSoundService.fallbackSoundId(soundId);
    if (id.startsWith('custom://')) {
      return UriAndroidNotificationSound(_customSoundPath(id));
    }
    return switch (id) {
      // En mode alarme le « défaut » doit sonner : on prend le son d'alarme
      // système plutôt que le son de notification (souvent silencieux).
      'default' => isAlarm ? _systemAlarmSound : _systemDefaultSound,
      'chime1' => const RawResourceAndroidNotificationSound('chime1'),
      'chime2' => const RawResourceAndroidNotificationSound('chime2'),
      'beep' => const RawResourceAndroidNotificationSound('beep'),
      'bell' => const RawResourceAndroidNotificationSound('bell'),
      'whistle' => const RawResourceAndroidNotificationSound('whistle'),
      'alarm' => const UriAndroidNotificationSound(
        'content://settings/system/alarm_alert',
      ),
      _ => isAlarm ? _systemAlarmSound : _systemDefaultSound,
    };
  }

  /// Prochaine occurrence future (décallée de [offsetMinutes]), ou `null`
  /// si une activité « une fois » est déjà passée.
  tz.TZDateTime? _nextFireTime(
    Activity activity,
    int weekday,
    int offsetMinutes, [
    DateTime? now,
  ]) {
    final clock = now ?? DateTime.now();

    // 1. Occurrence de base selon la règle de répétition.
    DateTime occ;
    switch (activity.repeat) {
      case RepeatRule.none:
        occ = DateTime(
          activity.date.year,
          activity.date.month,
          activity.date.day,
          activity.hour,
          activity.minute,
        );
        break;
      case RepeatRule.daily:
        occ = DateTime(clock.year, clock.month, clock.day, activity.hour, activity.minute);
        break;
      case RepeatRule.weekly:
        var daysAhead = weekday - clock.weekday;
        if (daysAhead < 0) daysAhead += 7;
        occ = DateTime(clock.year, clock.month, clock.day, activity.hour, activity.minute).add(Duration(days: daysAhead));
        break;
      case RepeatRule.monthly:
        occ = _nextMonthlyOccurrence(
          DateTime(
            activity.date.year,
            activity.date.month,
            activity.date.day,
            activity.hour,
            activity.minute,
          ),
          clock,
        );
        break;
    }

    // Ne pas rappeler avant la date de création de l'activité.
    while (activity.repeat != RepeatRule.none &&
        DateTime(occ.year, occ.month, occ.day).isBefore(activity.date)) {
      occ = switch (activity.repeat) {
        RepeatRule.weekly => occ.add(const Duration(days: 7)),
        RepeatRule.monthly => _advanceMonthly(activity.date, occ),
        _ => occ,
      };
    }

    // 2. Avancer l'occurrence jusqu'à ce que (occurrence - offset) soit
    //    strictement dans le futur. C'est le calcul décisif : un `fire` dans
    //    le passé fait échouer le scheduling et annule la notification.
    var cycleCount = 0;
    while (true) {
      final fire = occ.subtract(Duration(minutes: offsetMinutes));
      if (fire.isAfter(clock)) {
        return tz.TZDateTime(
          tz.local,
          fire.year,
          fire.month,
          fire.day,
          fire.hour,
          fire.minute,
        );
      }

      // Activité « une fois » déjà passée → aucune notification possible.
      if (activity.repeat == RepeatRule.none) return null;

      occ = switch (activity.repeat) {
        RepeatRule.daily => occ.add(const Duration(days: 1)),
        RepeatRule.weekly => occ.add(const Duration(days: 7)),
        RepeatRule.monthly => _advanceMonthly(activity.date, occ),
        _ => occ,
      };

      // Garde-fou : jamais de boucle infinie (offset déraisonnable, etc.).
      if (++cycleCount > 120) return null;
    }
  }

  DateTime _nextMonthlyOccurrence(DateTime base, DateTime now) {
    final lastDay = _daysInMonth(now.year, now.month);
    final day = base.day > lastDay ? lastDay : base.day;
    var occ = DateTime(now.year, now.month, day, base.hour, base.minute);
    if (occ.isBefore(now)) {
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      final nextLast = _daysInMonth(nextMonth.year, nextMonth.month);
      final nextDay = base.day > nextLast ? nextLast : base.day;
      return DateTime(
        nextMonth.year,
        nextMonth.month,
        nextDay,
        base.hour,
        base.minute,
      );
    }
    return occ;
  }

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  /// Avance d'un mois une occurrence en gardant le jour de [base] (et non
  /// celui de [occ], déjà clampé) pour éviter la dérive : 31 janv. → 28 févr.
  /// → 31 mars, jamais 28 mars.
  DateTime _advanceMonthly(DateTime base, DateTime occ) {
    final nextMonth = DateTime(
      occ.year,
      occ.month + 1,
      1,
      occ.hour,
      occ.minute,
    );
    final lastDay = _daysInMonth(nextMonth.year, nextMonth.month);
    final day = base.day > lastDay ? lastDay : base.day;
    return DateTime(nextMonth.year, nextMonth.month, day, occ.hour, occ.minute);
  }

  /// Identifiant de canal utilisé pour un son personnalisé (test).
  @visibleForTesting
  String customChannelIdFor(String soundId) => _customChannelId(soundId);

  /// Prochaine occurrence future pour la règle de l'activité (test).
  @visibleForTesting
  tz.TZDateTime? nextFireTime(
    Activity a,
    int weekday,
    int offsetMinutes, [
    DateTime? now,
  ]) => _nextFireTime(a, weekday, offsetMinutes, now);

  /// Canal + son effectifs pour un identifiant de son (test).
  @visibleForTesting
  (String, String) channelFor(String soundId, AppStrings s,
          {bool isAlarm = false}) =>
      _channelFor(soundId, s, isAlarm: isAlarm);

  @visibleForTesting
  AndroidNotificationSound? soundFor(String soundId,
          {bool isAlarm = false}) =>
      _soundFor(soundId, isAlarm: isAlarm);
}
