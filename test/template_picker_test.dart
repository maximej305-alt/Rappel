import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/l10n/app_strings.dart';
import 'package:rappel_plus/models/activity.dart';
import 'package:rappel_plus/models/routine.dart';
import 'package:rappel_plus/models/routine_template.dart';
import 'package:rappel_plus/providers/providers.dart';
import 'package:rappel_plus/screens/routine_edit_screen.dart';
import 'package:rappel_plus/services/storage_service.dart';

class _EmptyStorage extends StorageService {
  @override
  List<Activity> loadActivities() => [];

  @override
  Future<void> saveActivities(List<Activity> activities) async {}

  @override
  List<Routine> loadRoutines() => [];

  @override
  Future<void> saveRoutines(List<Routine> routines) async {}
}

void main() {
  Widget wrap() => ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(_EmptyStorage()),
        ],
        child: const MaterialApp(home: RoutineEditScreen()),
      );

  testWidgets('changer de modèle remplace les activités proposées',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final fr = AppStrings.fr;
    final morning = RoutineTemplate.templates[0];
    final evening = RoutineTemplate.templates[1];

    // Applique le premier modèle (matin).
    await tester.tap(find.text(fr.tr(morning.key)));
    await tester.pumpAndSettle();

    // Une activité du modèle matin est affichée.
    expect(
      find.textContaining(fr.tr(morning.activities.first.nameKey)),
      findsWidgets,
    );

    // Change pour le deuxième modèle (soir).
    await tester.tap(find.text(fr.tr(evening.key)));
    await tester.pumpAndSettle();

    // Les activités de l'ancien modèle doivent avoir disparu.
    expect(
      find.textContaining(fr.tr(morning.activities.first.nameKey)),
      findsNothing,
      reason: "les activités de l'ancien modèle doivent être remplacées",
    );
    // Celles du nouveau modèle apparaissent.
    expect(
      find.textContaining(fr.tr(evening.activities.first.nameKey)),
      findsWidgets,
      reason: 'les activités du nouveau modèle doivent apparaître',
    );
  });
}
