/// Activité d'un modèle de routine (nom traduit via une clé l10n).
class RoutineTemplateActivity {
  const RoutineTemplateActivity(this.nameKey, this.hour, this.minute);

  final String nameKey;
  final int hour;
  final int minute;
}

/// Modèle de routine prédéfini.
///
/// Liste volontairement courte et réelle, facile à modifier. Les libellés
/// passent par des clés de traduction (FR/EN).
class RoutineTemplate {
  const RoutineTemplate({
    required this.key,
    required this.icon,
    required this.activities,
  });

  /// Clé l10n du nom du modèle.
  final String key;
  final String icon;
  final List<RoutineTemplateActivity> activities;

  static const templates = [
    RoutineTemplate(
      key: 'tmplMorning',
      icon: '🌅',
      activities: [
        RoutineTemplateActivity('tmplWakeUp', 5, 0),
        RoutineTemplateActivity('tmplWater', 5, 10),
        RoutineTemplateActivity('tmplWorkout', 5, 30),
        RoutineTemplateActivity('tmplShower', 6, 0),
        RoutineTemplateActivity('tmplBreakfast', 6, 30),
      ],
    ),
    RoutineTemplate(
      key: 'tmplEvening',
      icon: '🌙',
      activities: [
        RoutineTemplateActivity('tmplDinner', 19, 30),
        RoutineTemplateActivity('tmplRelax', 20, 30),
        RoutineTemplateActivity('tmplReading', 21, 30),
        RoutineTemplateActivity('tmplBedtime', 22, 30),
      ],
    ),
    RoutineTemplate(
      key: 'tmplWork',
      icon: '💼',
      activities: [
        RoutineTemplateActivity('tmplEmails', 8, 30),
        RoutineTemplateActivity('tmplMeeting', 10, 0),
        RoutineTemplateActivity('tmplLunchBreak', 12, 30),
        RoutineTemplateActivity('tmplReports', 15, 0),
        RoutineTemplateActivity('tmplWrapUp', 17, 30),
      ],
    ),
    RoutineTemplate(
      key: 'tmplStudy',
      icon: '📚',
      activities: [
        RoutineTemplateActivity('tmplReview', 9, 0),
        RoutineTemplateActivity('tmplExercises', 10, 30),
        RoutineTemplateActivity('tmplStudyBreak', 11, 30),
        RoutineTemplateActivity('tmplReading', 14, 0),
      ],
    ),
    RoutineTemplate(
      key: 'tmplSport',
      icon: '🏃',
      activities: [
        RoutineTemplateActivity('tmplWarmup', 6, 30),
        RoutineTemplateActivity('tmplRun', 7, 0),
        RoutineTemplateActivity('tmplStretch', 7, 45),
      ],
    ),
  ];

  /// Icônes proposées pour une routine personnalisée.
  static const icons = ['📋', '🌅', '🌙', '💼', '📚', '🏃', '🧘', '🛒', '🧹', '💊'];
}
