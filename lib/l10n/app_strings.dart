/// Fichier de traduction : toutes les chaînes de l'application.
/// Le provider [AppStrings.fr] / [AppStrings.en] est choisi selon la langue.
class AppStrings {
  const AppStrings(this._t, [this.code = '']);

  final Map<String, String> _t;

  /// Code de langue (« fr », « en », « es », …) porté par cette instance.
  final String code;

  /// Vrai si la langue s'écrit de droite à gauche (ex. Arabe).
  bool get isRtl => code == 'ar';

  /// Nombre de clés traduites (utile pour les tests et diagnostics).
  int get length => _t.length;

  /// Clés présentes dans ce dictionnaire.
  Set<String> get keys => _t.keys.toSet();

  /// Traduction exacte, sinon la valeur anglophone (référence), sinon la clé.
  String _(String key) => _t[key] ?? en._t[key] ?? key;

  /// Accès générique à une clé (utile pour les jours et les sons).
  String tr(String key) => _t[key] ?? en._t[key] ?? key;




  // ————— Général —————
  String get appName => _('appName');
  String get splashTagline => _('splashTagline');
  String get ok => _('ok');
  String get cancel => _('cancel');
  String get save => _('save');
  String get delete => _('delete');
  String get edit => _('edit');
  String get add => _('add');
  String get today => _('today');
  String get tomorrow => _('tomorrow');
  String get enabled => _('enabled');
  String get disabled => _('disabled');
  String get monday => _('monday');
  String get tuesday => _('tuesday');
  String get wednesday => _('wednesday');
  String get thursday => _('thursday');
  String get friday => _('friday');
  String get saturday => _('saturday');
  String get sunday => _('sunday');
  String get mon => _('mon');
  String get tue => _('tue');
  String get wed => _('wed');
  String get thu => _('thu');
  String get fri => _('fri');
  String get sat => _('sat');
  String get sun => _('sun');

  // ————— Accueil —————
  String get greetingNight => _('greetingNight');
  String get greetingMorning => _('greetingMorning');
  String get greetingAfternoon => _('greetingAfternoon');
  String get greetingEvening => _('greetingEvening');
  String get statusNothing => _('statusNothing');
  String get statusAllDone => _('statusAllDone');
  String statusLeft(int count) => _('statusLeft').replaceAll('{count}', '$count');
  String statusLeftPlural(int count) =>
      _('statusLeftPlural').replaceAll('{count}', '$count');
  String get homeTitle => _('homeTitle');
  String get addActivity => _('addActivity');
  String get done => _('done');
  String get emptyTodayTitle => _('emptyTodayTitle');
  String get emptyTodayHint => _('emptyTodayHint');
  String get activityAdded => _('activityAdded');
  String get streakUnit => _('streakUnit');
  String get habitTitle => _('habitTitle');
  String get habitStreak => _('habitStreak');
  String get habitEmpty => _('habitEmpty');
  String get habitLast7 => _('habitLast7');
  String get habitProgress => _('habitProgress');
  String get deleteConfirmTitle => _('deleteConfirmTitle');
  String deleteConfirmBody(String name) =>
      _('deleteConfirmBody').replaceAll('{name}', name);
  String get weeklyFull => _('weeklyFull');
  String get weeklyDone => _('weeklyDone');
  String get weeklyEmpty => _('weeklyEmpty');
  String get myWeek => _('myWeek');
  String get prevWeek => _('prevWeek');
  String get nextWeek => _('nextWeek');
  String get calendar => _('calendar');
  String get homeTab => _('homeTab');
  String get weeklyTab => _('weeklyTab');

  // ————— Nouvelle activité —————
  String get newActivity => _('newActivity');
  String get editActivity => _('editActivity');
  String get nameLabel => _('nameLabel');
  String get nameHint => _('nameHint');
  String get nameError => _('nameError');
  String get time => _('time');
  String get date => _('date');
  String get notificationSound => _('notificationSound');
  String get repeat => _('repeat');
  String get once => _('once');
  String get day => _('day');
  String get days => _('days');
  String get month => _('month');
  String get monthly => _('monthly');
  String get repeatDaily => _('repeatDaily');
  String get remindersEnabled => _('remindersEnabled');
  String get remindersOn => _('remindersOn');
  String get remindersOff => _('remindersOff');
  String get chooseOneWeekday => _('chooseOneWeekday');
  String get saveChanges => _('saveChanges');

  // ————— Sons —————
  String get soundChime1 => _('soundChime1');
  String get soundChime2 => _('soundChime2');
  String get soundBeep => _('soundBeep');
  String get soundBell => _('soundBell');
  String get soundWhistle => _('soundWhistle');
  String get soundAlarm => _('soundAlarm');
  String get soundDefault => _('soundDefault');
  String get soundCustom => _('soundCustom');
  String get chooseCustomSound => _('chooseCustomSound');
  String get chooseCustomSoundHint => _('chooseCustomSoundHint');
  String get customSoundAdded => _('customSoundAdded');
  String get pickerError => _('pickerError');

  // ————— Réglages —————
  String get settings => _('settings');
  String get appearance => _('appearance');
  String get theme => _('theme');
  String get themeLight => _('themeLight');
  String get themeDark => _('themeDark');
  String get themeSystem => _('themeSystem');
  String get amoled => _('amoled');
  String get amoledHint => _('amoledHint');
  String get textScale => _('textScale');
  String get fontFamily => _('fontFamily');
  String get systemFont => _('systemFont');
  String get interFont => _('interFont');
  String get language => _('language');
  String get french => _('french');
  String get english => _('english');
  String get palette => _('palette');
  String paletteLabel(String id) => _('palette_$id');
  String get accent => _('accent');
  String accentLabel(String id) => _('accent_$id');
  String get notifications => _('notifications');
  String get defaultSound => _('defaultSound');
  String get defaultSoundTitle => _('defaultSoundTitle');
  String get reminderBefore => _('reminderBefore');
  String get reminderAtExact => _('reminderAtExact');
  String reminderMinutes(int n) =>
      _('reminderMinutes').replaceAll('{n}', '$n');
  String get trySound => _('trySound');
  String get trySoundHint => _('trySoundHint');
  String get test => _('test');
  String get previewPlay => _('previewPlay');
  String get previewStop => _('previewStop');
  String get security => _('security');
  String get lockApp => _('lockApp');
  String get lockDisabled => _('lockDisabled');
  String lockMethod(String method) =>
      _('lockMethod').replaceAll('{method}', method);
  String get changeMethod => _('changeMethod');
  String get modifyCode => _('modifyCode');
  String get unlockFingerprint => _('unlockFingerprint');
  String get unlockFingerprintHint => _('unlockFingerprintHint');
  String get privacy => _('privacy');
  String get about => _('about');
  String get aboutBody => _('aboutBody');
  String get whatsNewTitle => _('whatsNewTitle');
  String get offline => _('offline');
  String get offlineHint => _('offlineHint');
  String get lockMethodTitle => _('lockMethodTitle');
  String get pinLabel => _('pinLabel');
  String get passwordLabel => _('passwordLabel');
  String get patternLabel => _('patternLabel');
  String get biometricLabel => _('biometricLabel');
  String get pinHint => _('pinHint');
  String get passwordHint => _('passwordHint');
  String get patternHint => _('patternHint');
  String get biometricHint => _('biometricHint');
  String get lockActivated => _('lockActivated');
  String get methodChanged => _('methodChanged');
  String get codeUpdated => _('codeUpdated');
  String get noBiometric => _('noBiometric');
  String get useDeviceFingerprintTitle => _('useDeviceFingerprintTitle');
  String get useDeviceFingerprintHint => _('useDeviceFingerprintHint');
  String get noFingerprintEnrolled => _('noFingerprintEnrolled');
  String get moveUp => _('moveUp');
  String get moveDown => _('moveDown');
  String get soundImportError => _('soundImportError');

  // ————— Réglages additionnels (nouveaux écrans) —————
  /// Alias lisibles utilisés dans les pages de réglages modernes.
  String get fontSystem => _t['fontSystem'] ?? systemFont;
  String get fontInter => _t['fontInter'] ?? interFont;
  String get amoledMode => _t['amoledMode'] ?? amoled;
  String get textSize => _t['textSize'] ?? textScale;
  String get textSizeHint => _('textSizeHint');
  String get alarmMode => _('alarmMode');
  String get alarmModeHint => _('alarmModeHint');
  String get dndIgnore => _('dndIgnore');
  String get dndIgnoreHint => _('dndIgnoreHint');
  String get dataManagement => _('dataManagement');
  String get aboutApp => _('aboutApp');
  String get versionInfo => _('versionInfo');
  String get changelogTitle => _('changelogTitle');
  String get aboutChangelog => _('aboutChangelog');
  String get securitySettings => _('securitySettings');
  String get notificationSettings => _('notificationSettings');
  String get appearanceSettings => _('appearanceSettings');
  String get languageSettings => _('languageSettings');
  String get exactTime => _('exactTime');
  String get manageCategories => _('manageCategories');

  // ————— Verrouillage —————
  String get lockAppTitle => _('lockAppTitle');
  String get choosePin => _('choosePin');
  String get confirmPin => _('confirmPin');
  String get choosePassword => _('choosePassword');
  String get confirmPassword => _('confirmPassword');
  String get passwordMin => _('passwordMin');
  String get passwordPlaceholder => _('passwordPlaceholder');
  String get min4Chars => _('min4Chars');
  String get drawPattern => _('drawPattern');
  String get drawPatternAgain => _('drawPatternAgain');
  String get patternMin => _('patternMin');
  String get mismatch => _('mismatch');
  String get secret => _('secret');
  String get continueLabel => _('continueLabel');
  String get verification => _('verification');
  String get enterToContinue => _('enterToContinue');
  String get verifying => _('verifying');
  String get currentPassword => _('currentPassword');
  String get unlockPin => _('unlockPin');
  String get unlockPassword => _('unlockPassword');
  String get unlockPattern => _('unlockPattern');
  String get unlockBiometric => _('unlockBiometric');
  String get wrongPin => _('wrongPin');
  String get wrongPassword => _('wrongPassword');
  String get wrongPattern => _('wrongPattern');
  String get passwordField => _('passwordField');
  String get unlockBtn => _('unlockBtn');
  String get checking => _('checking');
  String get touchSensor => _('touchSensor');
  String get useFingerprint => _('useFingerprint');
  String get verifyBiometric => _('verifyBiometric');
  String get tryAgain => _('tryAgain');
  String get fallbackTitle => _('fallbackTitle');
  String get useFallbackPin => _('useFallbackPin');
  String get useFallbackPassword => _('useFallbackPassword');
  String get useFallbackPattern => _('useFallbackPattern');
  String get retryBiometric => _('retryBiometric');
  String get forgotCode => _('forgotCode');
  String get forgotCodeTitle => _('forgotCodeTitle');
  String get forgotCodeBody => _('forgotCodeBody');
  String get forgotCodeOk => _('forgotCodeOk');
  String get fallbackSubtitle => _('fallbackSubtitle');
  String get keypadDelete => _('keypadDelete');
  String get keypadError => _('keypadError');

  // ————— Notifications natives —————
  String notifReminder(String name, int minutes, String time) =>
      _('notifReminder')
          .replaceAll('{name}', name)
          .replaceAll('{minutes}', '$minutes')
          .replaceAll('{time}', time);
  String notifNow(String name) =>
      _('notifNow').replaceAll('{name}', name);
  String get notifTest => _('notifTest');
  String get notifChannelDesc => _('notifChannelDesc');
  String channelName(String name) =>
      _('channelName').replaceAll('{name}', name);

  // ————— Actions rapides —————
  String get actionDone => _('actionDone');
  String get actionSnooze5 => _('actionSnooze5');
  String get actionSnooze10 => _('actionSnooze10');
  String get actionSnooze30 => _('actionSnooze30');
  String get actionTomorrow => _('actionTomorrow');
  String notifDeferred(String name, String time) =>
      _('notifDeferred').replaceAll('{name}', name).replaceAll('{time}', time);
  String notifTomorrow(String name, String time) =>
      _('notifTomorrow').replaceAll('{name}', name).replaceAll('{time}', time);

  // ————— Stats —————
  String get stats => _('stats');  String get currentStreak => _('currentStreak');
  String get bestRecord => _('bestRecord');
  String get daysUnit => _('daysUnit');
  String get consecutiveDaysUnit => _('consecutiveDaysUnit');
  String get thisWeek => _('thisWeek');
  String get routineRespected => _('routineRespected');
  String get activitiesDone => _('activitiesDone');
  String get activitiesMissed => _('activitiesMissed');
  String get weeklyProgress => _('weeklyProgress');
  String get history => _('history');
  String get monthlyView => _('monthlyView');
  String get noHistory => _('noHistory');
  String get statusRespected => _('statusRespected');
  String get statusPartial => _('statusPartial');
  String get statusMissed => _('statusMissed');
  String get statusNeutral => _('statusNeutral');
  String get statsEmptyTitle => _('statsEmptyTitle');
  String get statsEmptyHint => _('statsEmptyHint');

  // ————— Routines —————
  String get routines => _('routines');
  String get createRoutine => _('createRoutine');
  String get routineName => _('routineName');
  String get routineNameHint => _('routineNameHint');
  String get routineNameError => _('routineNameError');
  String get routineDescription => _('routineDescription');
  String get routineDescriptionHint => _('routineDescriptionHint');
  String get routineIcon => _('routineIcon');
  String get routineActivities => _('routineActivities');
  String get chooseTemplate => _('chooseTemplate');
  String get addRoutineActivity => _('addRoutineActivity');
  String get routineActivityTitle => _('routineActivityTitle');
  String get routineActivityNameHint => _('routineActivityNameHint');
  String get chooseActivityTime => _('chooseActivityTime');
  String get activityAddedToRoutine => _('activityAddedToRoutine');
  String get routineCreated => _('routineCreated');
  String get routineUpdated => _('routineUpdated');
  String get routineActive => _('routineActive');
  String get routineInactive => _('routineInactive');
  String get pauseRoutine => _('pauseRoutine');
  String get resumeRoutine => _('resumeRoutine');
  String get noRoutines => _('noRoutines');
  String get noRoutinesHint => _('noRoutinesHint');
  String get routineCreationError => _('routineCreationError');
  String get routineActivityRequired => _('routineActivityRequired');
  String get deleteRoutineTitle => _('deleteRoutineTitle');
  String deleteRoutineBody(String name, int count) =>
      _('deleteRoutineBody')
          .replaceAll('{name}', name)
          .replaceAll('{count}', '$count');
  String get removeActivityTitle => _('removeActivityTitle');
  String activitiesLabel(int count) {
    final key = switch (count) {
      0 => 'activitiesZero',
      1 => 'activityOne',
      _ => 'activitiesLabel',
    };
    return _(key).replaceAll('{count}', '$count');
  }
  String get editRoutine => _('editRoutine');

  // Modèles prédéfinis.
  String get tmplMorning => _('tmplMorning');
  String get tmplEvening => _('tmplEvening');
  String get tmplWork => _('tmplWork');
  String get tmplStudy => _('tmplStudy');
  String get tmplSport => _('tmplSport');
  String get tmplCustom => _('tmplCustom');
  String get tmplWakeUp => _('tmplWakeUp');
  String get tmplWater => _('tmplWater');
  String get tmplWorkout => _('tmplWorkout');
  String get tmplShower => _('tmplShower');
  String get tmplBreakfast => _('tmplBreakfast');
  String get tmplDinner => _('tmplDinner');
  String get tmplRelax => _('tmplRelax');
  String get tmplReading => _('tmplReading');
  String get tmplBedtime => _('tmplBedtime');
  String get tmplEmails => _('tmplEmails');
  String get tmplMeeting => _('tmplMeeting');
  String get tmplLunchBreak => _('tmplLunchBreak');
  String get tmplReports => _('tmplReports');
  String get tmplWrapUp => _('tmplWrapUp');
  String get tmplReview => _('tmplReview');
  String get tmplExercises => _('tmplExercises');
  String get tmplStudyBreak => _('tmplStudyBreak');
  String get tmplWarmup => _('tmplWarmup');
  String get tmplRun => _('tmplRun');
  String get tmplStretch => _('tmplStretch');

  // ————— Priorités & Catégories —————
  String get priority => _('priority');
  String get priorityNormal => _('priorityNormal');
  String get priorityImportant => _('priorityImportant');
  String get priorityUrgent => _('priorityUrgent');
  String get category => _('category');
  String get categories => _('categories');
  String get createCategory => _('createCategory');
  String get newCategory => _('newCategory');
  String get editCategory => _('editCategory');
  String get categoryName => _('categoryName');
  String get categoryNameHint => _('categoryNameHint');
  String get categoryNameError => _('categoryNameError');
  String get categoryIcon => _('categoryIcon');
  String get categoryColor => _('categoryColor');
  String get deleteCategoryTitle => _('deleteCategoryTitle');
  String deleteCategoryBody(String name, int count) => _('deleteCategoryBody')
      .replaceAll('{name}', name)
      .replaceAll('{count}', '$count');
  String get categoryPersonal => _('categoryPersonal');
  String get categoryWork => _('categoryWork');
  String get categoryStudy => _('categoryStudy');
  String get categorySport => _('categorySport');
  String get categoryOther => _('categoryOther');

  // ————— Recherche & filtres —————
  String get search => _('search');
  String get searchTitle => _('searchTitle');
  String get searchHint => _('searchHint');
  String get filters => _('filters');
  String get filterDate => _('filterDate');
  String get filterStatus => _('filterStatus');
  String get filterPriority => _('filterPriority');
  String get filterCategory => _('filterCategory');
  String get all => _('all');
  String get statusTodo => _('statusTodo');
  String get statusDone => _('statusDone');
  String get statusDoneHint => _('statusDoneHint');
  String get noResults => _('noResults');
  String get noResultsHint => _('noResultsHint');
  String get clearAll => _('clearAll');
  String get clearSearch => _('clearSearch');
  String get clearSearchFilters => _('clearSearchFilters');

  // ————— Sélection de langue —————
  /// Codes de langue supportés (en plus de `fr` et `en`, les fichiers
  /// dédiés `lib/l10n/app_strings_ext.dart` apportent « es », « de »,
  /// « it », « pt » avec repli automatique sur l'anglais).
  static const List<String> supportedLocales = [
    'fr',
    'en',
    'es',
    'de',
    'it',
    'pt',
    'zh',
    'ar',
  ];

  static const fr = AppStrings({
    'appName': 'Rappel+',
    'ok': 'OK',
    'cancel': 'Annuler',
    'save': 'Enregistrer',
    'splashTagline': 'Ne ratez plus rien.',
    'delete': 'Supprimer',
    'edit': 'Modifier',
    'add': 'Ajouter',
    'today': 'Aujourd\'hui',
    'tomorrow': 'Demain',
    'enabled': 'Activé',
    'disabled': 'Désactivé',
    'monday': 'Le lundi',
    'tuesday': 'Le mardi',
    'wednesday': 'Le mercredi',
    'thursday': 'Le jeudi',
    'friday': 'Le vendredi',
    'saturday': 'Le samedi',
    'sunday': 'Le dimanche',
    'mon': 'Lun',
    'tue': 'Mar',
    'wed': 'Mer',
    'thu': 'Jeu',
    'fri': 'Ven',
    'sat': 'Sam',
    'sun': 'Dim',

    'greetingNight': 'Bonne nuit',
    'greetingMorning': 'Bonjour',
    'greetingAfternoon': 'Bon après-midi',
    'greetingEvening': 'Bonsoir',
    'statusNothing': 'Rien de prévu, profite de ta journée',
    'statusAllDone': 'Tout est terminé, bravo !',
    'statusLeft': 'Il te reste {count} activité à faire',
    'statusLeftPlural': 'Il te reste {count} activités à faire',
    'homeTitle': 'Rappel+',
    'addActivity': 'Nouvelle activité',
    'done': 'faites',
    'emptyTodayTitle': 'Aucune activité aujourd\'hui',
    'emptyTodayHint': 'Touche « Nouvelle activité » pour programmer une activité',
    'activityAdded': 'Activité ajoutée ✓',
    'streakUnit': 'j',
    'habitTitle': 'Suivi des habitudes',
    'habitStreak': 'Jours de routine respectée',
    'habitEmpty': 'Commence à cocher tes activités quotidiennes !',
    'habitLast7': '7 derniers jours — progression',
    'habitProgress': 'progression',
    'deleteConfirmTitle': 'Supprimer ?',
    'deleteConfirmBody': 'Supprimer « {name} » et son rappel ?',
    'weeklyFull': 'jours complétés',
    'weeklyDone': 'activités cochées',
    'weeklyEmpty': 'Aucune activité ce jour-là',
    'myWeek': 'Ma semaine',
    'prevWeek': 'Semaine précédente',
    'nextWeek': 'Semaine suivante',
    'calendar': 'Calendrier',
    'homeTab': 'Accueil',
    'weeklyTab': 'Hebdo',

    'newActivity': 'Nouvelle activité',
    'editActivity': 'Modifier l\'activité',
    'nameLabel': 'Nom de l\'activité',
    'nameHint': 'Ex. : Réveil, Ménage…',
    'nameError': 'Donne un nom',
    'time': 'Heure',
    'date': 'Date',
    'notificationSound': 'Son de notification',
    'repeat': 'Répétition',
    'once': 'Une fois',
    'day': 'Jour',
    'days': 'Jours',
    'month': 'Mois',
    'monthly': 'Chaque mois',
    'repeatDaily': 'Tous les jours',
    'remindersEnabled': 'Rappels activés',
    'remindersOn': 'Tu recevras une notification à l\'heure choisie',
    'remindersOff': 'L\'activité reste listée mais ne sonnera pas',
    'chooseOneWeekday': 'Choisis au moins un jour de la semaine',
    'saveChanges': 'Enregistrer les modifications',

    'soundChime1': 'Carillon',
    'soundChime2': 'Arpège',
    'soundBeep': 'Bip',
    'soundBell': 'Cloche',
    'soundWhistle': 'Sifflet',
    'soundAlarm': 'Alarme',
    'soundDefault': 'Par défaut',
    'soundCustom': 'Son personnalisé',
    'chooseCustomSound': 'Choisir un son…',
    'chooseCustomSoundHint': 'Importe un fichier audio (mp3, wav…)',
    'customSoundAdded': 'Son personnalisé ajouté ✓',
    'pickerError': 'Impossible de lire ce fichier audio',

    'settings': 'Paramètres',
    'appearance': 'Apparence',
    'theme': 'Thème',
    'themeLight': 'Clair',
    'themeDark': 'Sombre',
    'themeSystem': 'Auto',
    'amoled': 'Mode AMOLED',
    'amoledHint': 'Noirs profonds en thème sombre (économie OLED)',
    'textScale': 'Taille du texte',
    'fontFamily': 'Police de l\'interface',
    'systemFont': 'Système',
    'interFont': 'Inter',
    'language': 'Langue',
    'french': 'Français',
    'english': 'Anglais',
    'palette': 'Palette de couleurs',
    'palette_classic': 'Classique',
    'palette_ocean': 'Océan',
    'palette_purple': 'Violet',
    'palette_forest': 'Forêt',
    'palette_sunset': 'Coucher de soleil',
    'palette_rose': 'Rose',
    'palette_azure': 'Azur',
    'palette_slate': 'Ardoise',
    'accent': 'Couleur d\'accent',
    'accent_indigo': 'Indigo',
    'accent_teal': 'Turquoise',
    'accent_rose': 'Rose',
    'accent_amber': 'Ambre',
    'accent_emerald': 'Émeraude',
    'accent_purple': 'Violet',
    'notifications': 'Notifications',
    'defaultSound': 'Son par défaut',
    'defaultSoundTitle': 'Son par défaut des nouvelles activités',
    'reminderBefore': 'Rappel avant l\'activité',
    'reminderAtExact': 'À l\'heure exacte',
    'reminderMinutes': '{n} min avant',
    'trySound': 'Essayer le son',
    'trySoundHint': 'Joue l\'aperçu immédiatement',
    'test': 'Tester',
    'previewPlay': 'Écouter l\'aperçu',
    'previewStop': 'Arrêter l\'aperçu',
    'security': 'Sécurité',
    'lockApp': 'Verrouiller l\'application',
    'lockDisabled': 'Désactivé',
    'lockMethod': 'Méthode : {method}',
    'changeMethod': 'Changer de méthode',
    'modifyCode': 'Modifier le code',
    'unlockFingerprint': 'Déverrouillage par empreinte',
    'unlockFingerprintHint': 'En plus du code',
    'privacy': 'Vie privée',
    'about': 'À propos',
    'aboutBody': 'Rappel+ — rappels et habitudes, 100 % hors ligne. '
        'Vos données restent chiffrées sur votre appareil.',
    'whatsNewTitle': 'Nouveautés',
    'offline': '100 % hors-ligne',
    'offlineHint': 'Tes données restent sur ton appareil, chiffrées. '
        'Aucune donnée n\'est collectée, aucun service tiers.',
    'lockMethodTitle': 'Méthode de verrouillage',
    'pinLabel': 'Code PIN',
    'passwordLabel': 'Mot de passe',
    'patternLabel': 'Motif',
    'biometricLabel': 'Empreinte digitale',
    'pinHint': 'Code à 4 chiffres',
    'passwordHint': 'Mot de passe secret',
    'patternHint': 'Motif à dessiner',
    'biometricHint': 'Empreinte ou Face ID',
    'lockActivated': 'Verrouillage activé',
    'methodChanged': 'Méthode changée',
    'codeUpdated': 'Code mis à jour',
    'noBiometric': 'Ton téléphone ne prend pas en charge '
        'l\'empreinte digitale. Choisis un code PIN.',
    'useDeviceFingerprintTitle':
        'Déverrouiller avec l\'empreinte du téléphone',
    'useDeviceFingerprintHint':
        'Utilise l\'empreinte déjà enregistrée dans les paramètres Android — '
            'aucune nouvelle inscription nécessaire.',
    'noFingerprintEnrolled':
        'Aucune empreinte enregistrée sur ce téléphone. Ajoute-en une dans '
            'Réglages Android > Sécurité > Empreinte digitale.',
    'moveUp': 'Monter',
    'moveDown': 'Descendre',
    'soundImportError':
        'Impossible d\'importer ce son. Vérifie le format du fichier.',

    'lockAppTitle': 'Application verrouillée',
    'choosePin': 'Choisissez un code PIN',
    'confirmPin': 'Confirmez le code PIN',
    'choosePassword': 'Choisissez un mot de passe',
    'confirmPassword': 'Confirmez le mot de passe',
    'passwordMin': 'Mot de passe (min. 4 caractères)',
    'passwordPlaceholder': 'Secret',
    'min4Chars': 'Minimum 4 caractères',
    'drawPattern': 'Dessinez votre motif',
    'drawPatternAgain': 'Dessinez-le à nouveau',
    'patternMin': 'Motif d\'au moins 4 points',
    'mismatch': 'Les deux saisies doivent correspondre',
    'secret': 'Secret',
    'continueLabel': 'Continuer',
    'verification': 'Vérification',
    'enterToContinue': 'Identifiez-vous pour continuer',
    'verifying': 'Vérification en cours…',
    'currentPassword': 'Mot de passe actuel',
    'unlockPin': 'Entrez votre code PIN',
    'unlockPassword': 'Entrez votre mot de passe',
    'unlockPattern': 'Dessinez votre motif',
    'unlockBiometric': 'Déverrouillez avec votre empreinte',
    'wrongPin': 'Code incorrect, réessayez',
    'wrongPassword': 'Mot de passe incorrect',
    'wrongPattern': 'Motif incorrect, réessayez',
    'passwordField': 'Mot de passe',
    'unlockBtn': 'Déverrouiller',
    'checking': 'Vérification en cours…',
    'touchSensor': 'Touchez le capteur',
    'useFingerprint': 'Utiliser l\'empreinte',
    'verifyBiometric': 'Déverrouillez Rappel+ avec votre empreinte',
    'tryAgain': 'Réessayer',
    'fallbackTitle': 'Méthode de secours',
    'useFallbackPin': 'Utiliser le code PIN',
    'useFallbackPassword': 'Utiliser le mot de passe',
    'useFallbackPattern': 'Utiliser le motif',
    'retryBiometric': 'Réessayer la biométrie',
    'forgotCode': 'Code oublié ?',
    'forgotCodeTitle': 'Code oublié ?',
    'forgotCodeBody':
        'Votre application est protégée : seul le code enregistré permet de '
        'la déverrouiller. Il n\'existe volontairement aucun moyen de '
        'récupération externe — vos données restent ainsi 100 % privées.',
    'forgotCodeOk': 'Compris',
    'fallbackSubtitle': 'Si la biométrie échoue, cette méthode '
        'permettra de déverrouiller l\'application.',
    'keypadDelete': 'Supprimer',
    'keypadError': 'Code incorrect',

    'notifReminder': '« {name} » dans {minutes} min (à {time})',
    'notifNow': 'C\'est le moment de « {name} »',
    'notifTest': 'C\'est une notification de test 🎉',
    'notifChannelDesc': 'Rappels de vos activités',
    'channelName': 'Rappels - {name}',
    'actionDone': 'Terminé',
    'actionSnooze5': '+5 min',
    'actionSnooze10': '+10 min',
    'actionSnooze30': '+30 min',
    'actionTomorrow': 'Demain',
    'notifDeferred': '« {name} » reporté à {time}',
    'notifTomorrow': '« {name} » — demain à {time}',

    'stats': 'Stats',
    'currentStreak': 'Série actuelle',
    'bestRecord': 'Meilleure série',
    'daysUnit': 'jours',
    'consecutiveDaysUnit': 'j. consécutifs',
    'thisWeek': 'Cette semaine',
    'routineRespected': 'routine respectée',
    'activitiesDone': 'terminées',
    'activitiesMissed': 'manquées',
    'weeklyProgress': 'Progression hebdo',
    'history': 'Historique',
    'monthlyView': 'Vue mensuelle',
    'noHistory': 'Aucun historique pour l\'instant',
    'statusRespected': 'Respecté',
    'statusPartial': 'Partiel',
    'statusMissed': 'Manqué',
    'statusNeutral': 'Hors routine',
    'statsEmptyTitle': 'Pas encore de routine',
    'statsEmptyHint': 'Crée des activités, puis coche-les chaque jour pour voir ta progression.',

    'routines': 'Routines',
    'createRoutine': 'Créer une routine',
    'routineName': 'Nom de la routine',
    'routineNameHint': 'Ex. : Routine du matin',
    'routineNameError': 'Donne un nom',
    'routineDescription': 'Description',
    'routineDescriptionHint': 'Optionnel',
    'routineIcon': 'Icône',
    'routineActivities': 'Activités',
    'chooseTemplate': 'Choisir un modèle',
    'addRoutineActivity': 'Ajouter une activité',
    'routineActivityTitle': 'Activité de la routine',
    'routineActivityNameHint': 'Ex. : Réveil, Étirements…',
    'chooseActivityTime': 'Choisir l\'heure',
    'activityAddedToRoutine': 'Activité ajoutée',
    'routineCreated': 'Routine créée ✓',
    'routineUpdated': 'Routine mise à jour ✓',
    'routineActive': 'Active',
    'routineInactive': 'En pause',
    'pauseRoutine': 'Mettre en pause',
    'resumeRoutine': 'Relancer',
    'noRoutines': 'Aucune routine',
    'noRoutinesHint': 'Crée une routine pour lancer plusieurs activités en une fois.',
    'routineCreationError': 'Impossible d\'enregistrer la routine. Aucune donnée n\'a été modifiée.',
    'routineActivityRequired': 'Ajoute au moins une activité',
    'deleteRoutineTitle': 'Supprimer la routine ?',
    'deleteRoutineBody': '« {name} » et ses {count} activités seront supprimés. Les rappels seront annulés.',
    'removeActivityTitle': 'Supprimer cette activité ?',
    'activitiesLabel': '{count} activités',
    'activityOne': '1 activité',
    'activitiesZero': '0 activité',
    'editRoutine': 'Modifier la routine',

    'tmplMorning': 'Routine du matin',
    'tmplEvening': 'Routine du soir',
    'tmplWork': 'Routine de travail',
    'tmplStudy': 'Routine d\'étude',
    'tmplSport': 'Routine sport',
    'tmplCustom': 'Routine personnalisée',
    'tmplWakeUp': 'Réveil',
    'tmplWater': 'Boire de l\'eau',
    'tmplWorkout': 'Sport',
    'tmplShower': 'Douche',
    'tmplBreakfast': 'Petit-déjeuner',
    'tmplDinner': 'Dîner',
    'tmplRelax': 'Se détendre',
    'tmplReading': 'Lire',
    'tmplBedtime': 'Se coucher',
    'tmplEmails': 'Emails',
    'tmplMeeting': 'Réunion',
    'tmplLunchBreak': 'Pause déjeuner',
    'tmplReports': 'Rapports',
    'tmplWrapUp': 'Fin de journée',
    'tmplReview': 'Réviser',
    'tmplExercises': 'Exercices',
    'tmplStudyBreak': 'Pause',
    'tmplWarmup': 'Échauffement',
    'tmplRun': 'Course',
    'tmplStretch': 'Étirements',

    'priority': 'Priorité',
    'priorityNormal': 'Normal',
    'priorityImportant': 'Important',
    'priorityUrgent': 'Urgent',
    'category': 'Catégorie',
    'categories': 'Catégories',
    'createCategory': 'Créer une catégorie',
    'newCategory': 'Nouvelle catégorie',
    'editCategory': 'Modifier la catégorie',
    'categoryName': 'Nom de la catégorie',
    'categoryNameHint': 'Ex. : Santé, Famille…',
    'categoryNameError': 'Donne un nom',
    'categoryIcon': 'Icône',
    'categoryColor': 'Couleur',
    'deleteCategoryTitle': 'Supprimer la catégorie ?',
    'deleteCategoryBody':
        '« {name} » et ses {count} activités seront déplacés vers « Autre ».',
    'categoryPersonal': 'Personnel',
    'categoryWork': 'Travail',
    'categoryStudy': 'Études',
    'categorySport': 'Sport',
    'categoryOther': 'Autre',

    'search': 'Rechercher',
    'searchTitle': 'Recherche',
    'searchHint': 'Rechercher une activité…',
    'filters': 'Filtres',
    'filterDate': 'Date',
    'filterStatus': 'Statut',
    'filterPriority': 'Priorité',
    'filterCategory': 'Catégorie',
    'all': 'Toutes',
    'statusTodo': 'À faire',
    'statusDone': 'Terminées',
    'statusDoneHint': 'Terminées aujourd\'hui',
    'noResults': 'Aucune activité trouvée',
    'noResultsHint': 'Modifie ta recherche ou tes filtres',
    'clearAll': 'Tout effacer',
    'clearSearch': 'Effacer la recherche',
    'clearSearchFilters': 'Effacer la recherche et les filtres',
    'appearanceSettings': 'Apparence',
    'securitySettings': 'Sécurité',
    'notificationSettings': 'Notifications',
    'languageSettings': 'Langue',
    'dataManagement': 'Données',
    'aboutApp': 'À propos',
    'versionInfo': 'Version {version}',
    'changelogTitle': 'Nouveautés',
    'textSizeHint':
        'S\'applique à toute l\'interface, en plus de l\'accessibilité système.',
    'alarmMode': 'Mode alarme',
    'alarmModeHint':
        'La sonnerie se répète jusqu\'à ce que tu agisses (Android).',
    'dndIgnore': 'Ignorer « Ne pas déranger »',
    'dndIgnoreHint':
        'Permettre aux alarmes de sonner même en mode silencieux / NPD.',
    'exactTime': 'À l\'heure exacte',
    'manageCategories': 'Gérer les catégories',
    'aboutChangelog': '• Sécurité optionnelle PBKDF2-HMAC-SHA256 '
        '(PIN, mot de passe, motif, biométrie).\n'
        '• Mode alarme natif avec sonnerie continue (Android).\n'
        '• Polices système et Inter sélectionnables.\n'
        '• Mode sombre AMOLED avec noirs profonds.\n'
        '• Multilingue complet avec RTL (arabe) et chinois.\n'
        '• Rappel en avance et report (5, 10, 30 min, demain).',
  }, 'fr');

  static const en = AppStrings({
    'appName': 'Rappel+',
    'cancel': 'Cancel',
    'save': 'Save',
    'splashTagline': 'Never miss a thing.',
    'delete': 'Delete',
    'edit': 'Edit',
    'add': 'Add',
    'today': 'Today',
    'tomorrow': 'Tomorrow',
    'enabled': 'Enabled',
    'disabled': 'Disabled',
    'monday': 'On Monday',
    'tuesday': 'On Tuesday',
    'wednesday': 'On Wednesday',
    'thursday': 'On Thursday',
    'friday': 'On Friday',
    'saturday': 'On Saturday',
    'sunday': 'On Sunday',
    'mon': 'Mon',
    'tue': 'Tue',
    'wed': 'Wed',
    'thu': 'Thu',
    'fri': 'Fri',
    'sat': 'Sat',
    'sun': 'Sun',

    'greetingNight': 'Good night',
    'greetingMorning': 'Good morning',
    'greetingAfternoon': 'Good afternoon',
    'greetingEvening': 'Good evening',
    'statusNothing': 'Nothing planned, enjoy your day',
    'statusAllDone': 'All done, well done!',
    'statusLeft': '{count} activity left',
    'statusLeftPlural': '{count} activities left',
    'homeTitle': 'Rappel+',
    'addActivity': 'New activity',
    'done': 'done',
    'emptyTodayTitle': 'No activity today',
    'emptyTodayHint': 'Tap « New activity » to schedule one',
    'activityAdded': 'Activity added ✓',
    'streakUnit': 'd',
    'habitTitle': 'Habit tracking',
    'habitStreak': 'Days you respected the routine',
    'habitEmpty': 'Start checking your daily activities!',
    'habitLast7': 'Last 7 days — progress',
    'habitProgress': 'progress',
    'deleteConfirmTitle': 'Delete?',
    'deleteConfirmBody': 'Delete « {name} » and its reminder?',
    'weeklyFull': 'days completed',
    'weeklyDone': 'activities checked',
    'weeklyEmpty': 'No activity on that day',
    'myWeek': 'My week',
    'prevWeek': 'Previous week',
    'nextWeek': 'Next week',
    'calendar': 'Calendar',
    'homeTab': 'Home',
    'weeklyTab': 'Weekly',

    'newActivity': 'New activity',
    'editActivity': 'Edit activity',
    'nameLabel': 'Activity name',
    'nameHint': 'Ex.: Wake up, Cleaning…',
    'nameError': 'Enter a name',
    'time': 'Time',
    'date': 'Date',
    'notificationSound': 'Notification sound',
    'repeat': 'Repeat',
    'once': 'Once',
    'day': 'Day',
    'days': 'Days',
    'month': 'Month',
    'monthly': 'Every month',
    'repeatDaily': 'Every day',
    'remindersEnabled': 'Reminders enabled',
    'remindersOn': 'You will get a notification at the chosen time',
    'remindersOff': 'The activity stays listed but won\'t ring',
    'chooseOneWeekday': 'Choose at least one weekday',
    'saveChanges': 'Save changes',

    'soundChime1': 'Chime',
    'soundChime2': 'Arpeggio',
    'soundBeep': 'Beep',
    'soundBell': 'Bell',
    'soundWhistle': 'Whistle',
    'soundAlarm': 'Alarm',
    'soundDefault': 'Default',
    'soundCustom': 'Custom sound',
    'chooseCustomSound': 'Choose a sound…',
    'chooseCustomSoundHint': 'Import an audio file (mp3, wav…)',
    'customSoundAdded': 'Custom sound added ✓',
    'pickerError': 'Cannot read this audio file',

    'settings': 'Settings',
    'appearance': 'Appearance',
    'theme': 'Theme',
    'themeLight': 'Light',
    'themeDark': 'Dark',
    'themeSystem': 'Auto',
    'amoled': 'AMOLED mode',
    'amoledHint': 'Deep blacks in dark theme (OLED savings)',
    'textScale': 'Text size',
    'fontFamily': 'Interface font',
    'systemFont': 'System',
    'interFont': 'Inter',
    'language': 'Language',
    'french': 'French',
    'english': 'English',
    'palette': 'Color palette',
    'palette_classic': 'Classic',
    'palette_ocean': 'Ocean',
    'palette_purple': 'Purple',
    'palette_forest': 'Forest',
    'palette_sunset': 'Sunset',
    'palette_rose': 'Rose',
    'palette_azure': 'Azure',
    'palette_slate': 'Slate',
    'accent': 'Accent color',
    'accent_indigo': 'Indigo',
    'accent_teal': 'Teal',
    'accent_rose': 'Rose',
    'accent_amber': 'Amber',
    'accent_emerald': 'Emerald',
    'accent_purple': 'Purple',
    'notifications': 'Notifications',
    'defaultSound': 'Default sound',
    'defaultSoundTitle': 'Default sound for new activities',
    'reminderBefore': 'Remind before activity',
    'reminderAtExact': 'At the exact time',
    'reminderMinutes': '{n} min before',
    'trySound': 'Try the sound',
    'trySoundHint': 'Plays the preview immediately',
    'test': 'Test',
    'previewPlay': 'Play preview',
    'previewStop': 'Stop preview',
    'security': 'Security',
    'lockApp': 'Lock the app',
    'lockDisabled': 'Disabled',
    'lockMethod': 'Method: {method}',
    'changeMethod': 'Change method',
    'modifyCode': 'Change the code',
    'unlockFingerprint': 'Unlock with fingerprint',
    'unlockFingerprintHint': 'In addition to the code',
    'privacy': 'Privacy',
    'about': 'About',
    'aboutBody': 'Rappel+ — reminders & habits, 100% offline. '
        'Your data stays encrypted on your device.',
    'whatsNewTitle': 'What\'s new',
    'offline': '100% offline',
    'offlineHint': 'Your data stays on your device, encrypted. '
        'No data is collected, no third-party services.',
    'lockMethodTitle': 'Lock method',
    'pinLabel': 'PIN code',
    'passwordLabel': 'Password',
    'patternLabel': 'Pattern',
    'biometricLabel': 'Fingerprint',
    'pinHint': '4-digit code',
    'passwordHint': 'Secret password',
    'patternHint': 'Draw a pattern',
    'biometricHint': 'Fingerprint or Face ID',
    'lockActivated': 'Lock enabled',
    'methodChanged': 'Method changed',
    'codeUpdated': 'Code updated',
    'noBiometric': 'Your phone does not support fingerprint. '
        'Choose a PIN code instead.',
    'useDeviceFingerprintTitle': 'Unlock with phone fingerprint',
    'useDeviceFingerprintHint':
        'Uses the fingerprint already registered in Android settings — '
            'no new enrollment needed.',
    'noFingerprintEnrolled':
        'No fingerprint enrolled on this phone. Add one in Android '
            'Settings > Security > Fingerprint.',
    'moveUp': 'Move up',
    'moveDown': 'Move down',
    'soundImportError': 'Could not import this sound. Check the file format.',

    'lockAppTitle': 'App locked',
    'choosePin': 'Choose a PIN code',
    'confirmPin': 'Confirm PIN code',
    'choosePassword': 'Choose a password',
    'confirmPassword': 'Confirm password',
    'passwordMin': 'Password (min. 4 characters)',
    'passwordPlaceholder': 'Secret',
    'min4Chars': 'Minimum 4 characters',
    'drawPattern': 'Draw your pattern',
    'drawPatternAgain': 'Draw it again',
    'patternMin': 'Pattern of at least 4 dots',
    'mismatch': 'Both entries must match',
    'secret': 'Secret',
    'continueLabel': 'Continue',
    'verification': 'Verification',
    'enterToContinue': 'Identify yourself to continue',
    'verifying': 'Verifying…',
    'currentPassword': 'Current password',
    'unlockPin': 'Enter your PIN code',
    'unlockPassword': 'Enter your password',
    'unlockPattern': 'Draw your pattern',
    'unlockBiometric': 'Unlock with your fingerprint',
    'wrongPin': 'Wrong code, try again',
    'wrongPassword': 'Wrong password',
    'wrongPattern': 'Wrong pattern, try again',
    'passwordField': 'Password',
    'unlockBtn': 'Unlock',
    'checking': 'Checking…',
    'touchSensor': 'Touch the sensor',
    'useFingerprint': 'Use fingerprint',
    'verifyBiometric': 'Unlock Rappel+ with your fingerprint',
    'tryAgain': 'Try again',
    'fallbackTitle': 'Fallback method',
    'useFallbackPin': 'Use the PIN code',
    'useFallbackPassword': 'Use the password',
    'useFallbackPattern': 'Use the pattern',
    'retryBiometric': 'Retry biometrics',
    'forgotCode': 'Forgot your code?',
    'forgotCodeTitle': 'Forgot your code?',
    'forgotCodeBody':
        'Your app is protected: only the registered code can unlock it. '
        'There is deliberately no external recovery method — your data '
        'stays 100% private.',
    'forgotCodeOk': 'Got it',
    'fallbackSubtitle': 'If biometrics fail, this method will let you '
        'unlock the app.',
    'keypadDelete': 'Delete',
    'keypadError': 'Wrong code',

    'notifReminder': '« {name} » in {minutes} min (at {time})',
    'notifNow': 'Time for « {name} »',
    'notifTest': 'This is a test notification 🎉',
    'notifChannelDesc': 'Reminders for your activities',
    'channelName': 'Reminders - {name}',
    'actionDone': 'Done',
    'actionSnooze5': '+5 min',
    'actionSnooze10': '+10 min',
    'actionSnooze30': '+30 min',
    'actionTomorrow': 'Tomorrow',
    'notifDeferred': '« {name} » deferred to {time}',
    'notifTomorrow': '« {name} » — tomorrow at {time}',

    'stats': 'Stats',
    'currentStreak': 'Current streak',
    'bestRecord': 'Best streak',
    'daysUnit': 'days',
    'consecutiveDaysUnit': 'days in a row',
    'thisWeek': 'This week',
    'routineRespected': 'routine respected',
    'activitiesDone': 'done',
    'activitiesMissed': 'missed',
    'weeklyProgress': 'Weekly progress',
    'history': 'History',
    'monthlyView': 'Monthly view',
    'noHistory': 'No history yet',
    'statusRespected': 'Respected',
    'statusPartial': 'Partial',
    'statusMissed': 'Missed',
    'statusNeutral': 'No routine',
    'statsEmptyTitle': 'No routine yet',
    'statsEmptyHint': 'Create activities, then check them off every day to see your progress.',

    'routines': 'Routines',
    'createRoutine': 'Create a routine',
    'routineName': 'Routine name',
    'routineNameHint': 'Ex.: Morning routine',
    'routineNameError': 'Enter a name',
    'routineDescription': 'Description',
    'routineDescriptionHint': 'Optional',
    'routineIcon': 'Icon',
    'routineActivities': 'Activities',
    'chooseTemplate': 'Choose a template',
    'addRoutineActivity': 'Add an activity',
    'routineActivityTitle': 'Routine activity',
    'routineActivityNameHint': 'Ex.: Wake up, Stretching…',
    'chooseActivityTime': 'Choose the time',
    'activityAddedToRoutine': 'Activity added',
    'routineCreated': 'Routine created ✓',
    'routineUpdated': 'Routine updated ✓',
    'routineActive': 'Active',
    'routineInactive': 'Paused',
    'pauseRoutine': 'Pause',
    'resumeRoutine': 'Resume',
    'noRoutines': 'No routines',
    'noRoutinesHint': 'Create a routine to launch several activities at once.',
    'routineCreationError': 'Could not save the routine. No data was modified.',
    'routineActivityRequired': 'Add at least one activity',
    'deleteRoutineTitle': 'Delete the routine?',
    'deleteRoutineBody': '« {name} » and its {count} activities will be deleted. The reminders will be cancelled.',
    'removeActivityTitle': 'Delete this activity?',
    'activitiesLabel': '{count} activities',
    'activityOne': '1 activity',
    'activitiesZero': '0 activities',
    'editRoutine': 'Edit the routine',

    'tmplMorning': 'Morning routine',
    'tmplEvening': 'Evening routine',
    'tmplWork': 'Work routine',
    'tmplStudy': 'Study routine',
    'tmplSport': 'Workout routine',
    'tmplCustom': 'Custom routine',
    'tmplWakeUp': 'Wake up',
    'tmplWater': 'Drink water',
    'tmplWorkout': 'Workout',
    'tmplShower': 'Shower',
    'tmplBreakfast': 'Breakfast',
    'tmplDinner': 'Dinner',
    'tmplRelax': 'Relax',
    'tmplReading': 'Read',
    'tmplBedtime': 'Go to bed',
    'tmplEmails': 'Emails',
    'tmplMeeting': 'Meeting',
    'tmplLunchBreak': 'Lunch break',
    'tmplReports': 'Reports',
    'tmplWrapUp': 'End of day',
    'tmplReview': 'Review',
    'tmplExercises': 'Exercises',
    'tmplStudyBreak': 'Break',
    'tmplWarmup': 'Warm-up',
    'tmplRun': 'Run',
    'tmplStretch': 'Stretching',

    'priority': 'Priority',
    'priorityNormal': 'Normal',
    'priorityImportant': 'Important',
    'priorityUrgent': 'Urgent',
    'category': 'Category',
    'categories': 'Categories',
    'createCategory': 'Create a category',
    'newCategory': 'New category',
    'editCategory': 'Edit category',
    'categoryName': 'Category name',
    'categoryNameHint': 'Ex.: Health, Family…',
    'categoryNameError': 'Enter a name',
    'categoryIcon': 'Icon',
    'categoryColor': 'Color',
    'deleteCategoryTitle': 'Delete the category?',
    'deleteCategoryBody':
        '« {name} » and its {count} activities will be moved to « Other ».',
    'categoryPersonal': 'Personal',
    'categoryWork': 'Work',
    'categoryStudy': 'Studies',
    'categorySport': 'Sport',
    'categoryOther': 'Other',

    'search': 'Search',
    'searchTitle': 'Search',
    'searchHint': 'Search activities…',
    'filters': 'Filters',
    'filterDate': 'Date',
    'filterStatus': 'Status',
    'filterPriority': 'Priority',
    'filterCategory': 'Category',
    'all': 'All',
    'statusTodo': 'To do',
    'statusDone': 'Done',
    'statusDoneHint': 'Done today',
    'noResults': 'No activity found',
    'noResultsHint': 'Change your search or filters',
    'clearAll': 'Clear all',
    'clearSearch': 'Clear search',
    'clearSearchFilters': 'Clear search and filters',
    'appearanceSettings': 'Appearance',
    'securitySettings': 'Security',
    'notificationSettings': 'Notifications',
    'languageSettings': 'Language',
    'dataManagement': 'Data',
    'aboutApp': 'About',
    'versionInfo': 'Version {version}',
    'changelogTitle': 'What\'s new',
    'textSizeHint':
        'Applies to the whole interface, on top of system accessibility.',
    'alarmMode': 'Alarm mode',
    'alarmModeHint':
        'The ringtone repeats until you act (Android).',
    'dndIgnore': 'Ignore "Do Not Disturb"',
    'dndIgnoreHint':
        'Let alarms ring even in silent / DND mode.',
    'exactTime': 'At the exact time',
    'manageCategories': 'Manage categories',
    'aboutChangelog': '• Optional security PBKDF2-HMAC-SHA256 '
        '(PIN, password, pattern, biometric).\n'
        '• Native alarm mode with continuous ringtone (Android).\n'
        '• Selectable system & Inter fonts.\n'
        '• AMOLED dark mode with deep blacks.\n'
        '• Full multilingual support with RTL (Arabic) and Chinese.\n'
        '• Advance reminder and snooze (5, 10, 30 min, tomorrow).',
  }, 'en');
}
