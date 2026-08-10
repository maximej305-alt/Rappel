import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/models/activity.dart';
import 'package:rappel_plus/models/routine.dart';
import 'package:rappel_plus/providers/providers.dart';
import 'package:rappel_plus/screens/routines_screen.dart';
import 'package:rappel_plus/services/storage_service.dart';

class _EmptyStorage extends StorageService {}

class _FakeStorage extends StorageService {
  _FakeStorage({
    this.activities = const [],
    this.routines = const [],
  });

  final List<Activity> activities;
  final List<Routine> routines;

  @override
  List<Activity> loadActivities() => activities;

  @override
  List<Routine> loadRoutines() => routines;
}

Activity activity(String name) => Activity.create(
      name: name,
      hour: 8,
      minute: 0,
      date: DateTime(2026, 8, 10),
      repeat: RepeatRule.daily,
    );

void main() {
  Widget wrap(StorageService storage) => ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: const MaterialApp(home: RoutinesScreen()),
      );

  testWidgets('sans routine : invite à créer une routine', (tester) async {
    await tester.pumpWidget(wrap(_EmptyStorage()));
    await tester.pumpAndSettle();

    expect(find.text('Aucune routine'), findsOneWidget);
    expect(
      find.text(
        'Crée une routine pour lancer plusieurs activités en une fois.',
      ),
      findsOneWidget,
    );
    expect(find.text('Créer une routine'), findsOneWidget);
  });

  testWidgets('avec des routines : liste les noms, icônes et compteurs',
      (tester) async {
    final a = activity('Réveil');
    final r1 = Routine.create(name: 'Matin', icon: '🌅', activityIds: [a.id]);
    final r2 = Routine.create(name: 'Sport', icon: '🏋️');
    await tester.pumpWidget(wrap(_FakeStorage(
      routines: [r1, r2],
      activities: [a],
    )));
    await tester.pumpAndSettle();

    expect(find.text('Routines'), findsWidgets);
    expect(find.text('🌅'), findsOneWidget);
    expect(find.text('Matin'), findsOneWidget);
    expect(find.text('1 activité'), findsOneWidget);
    expect(find.text('🏋️'), findsOneWidget);
    expect(find.text('Sport'), findsOneWidget);
    expect(find.text('0 activité'), findsOneWidget);
  });

  testWidgets('une routine en pause est signalée', (tester) async {
    final r = Routine.create(name: 'Matin').copyWith(active: false);
    await tester.pumpWidget(wrap(_FakeStorage(routines: [r])));
    await tester.pumpAndSettle();

    expect(find.text('Matin'), findsOneWidget);
    expect(find.text('En pause'), findsOneWidget);
  });

  testWidgets('toucher une carte ouvre le détail de la routine',
      (tester) async {
    final a = activity('Réveil');
    final r = Routine.create(name: 'Matin', activityIds: [a.id]);
    await tester.pumpWidget(wrap(_FakeStorage(
      routines: [r],
      activities: [a],
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Matin'));
    await tester.pumpAndSettle();

    expect(find.text('Réveil'), findsOneWidget);
    expect(find.text('Activités'), findsWidgets);
  });

  testWidgets('créer une routine : l\'activité ajoutée puis enregistrée '
      'est persistée et liée', (tester) async {
    final storage = _FakeStorage();
    final container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: RoutinesScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Créer une routine'));
    await tester.pumpAndSettle();

    // Remplit le nom de la routine.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nom de la routine'),
      'Ma routine',
    );

    // Ouvre la feuille d'ajout d'activité.
    await tester.ensureVisible(find.text('Ajouter une activité'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter une activité'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // La feuille s'est ouverte.
    expect(find.text('Activité de la routine'), findsOneWidget,
        reason: 'la feuille d\'ajout doit s\'ouvrir');

    // Saisit le nom de l'activité (dernier champ en focus).
    await tester.enterText(
      find.byType(TextFormField).last,
      'Réveil',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // La ligne apparaît dans l'éditeur.
    expect(find.text('Réveil'), findsOneWidget);

    // Enregistre la routine. Le bouton est construit paresseusement par la
    // ListView : on défile jusqu'à le voir apparaître (le titre de l'appbar
    // porte le même texte, on scinde donc la recherche à la liste).
    final createButton = find.descendant(
      of: find.byType(ListView),
      matching: find.text('Créer une routine'),
    );
    await tester.scrollUntilVisible(createButton, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(createButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    final routines = container.read(routinesProvider);
    final activities = container.read(activitiesProvider);
    expect(routines, hasLength(1));
    expect(routines.single.name, 'Ma routine');
    expect(activities, hasLength(1));
    expect(activities.single.name, 'Réveil');
    expect(routines.single.activityIds, [activities.single.id]);

    // Retour sur la liste : la carte apparaît.
    expect(find.text('Ma routine'), findsOneWidget);
    expect(find.text('1 activité'), findsOneWidget);
  });
}
