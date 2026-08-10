import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/models/activity.dart';
import 'package:rappel_plus/models/activity_priority.dart';
import 'package:rappel_plus/models/category.dart';
import 'package:rappel_plus/providers/providers.dart';
import 'package:rappel_plus/screens/search_screen.dart';
import 'package:rappel_plus/services/storage_service.dart';

class _FakeStorage extends StorageService {
  _FakeStorage({
    this.activities = const [],
    this.categories = const [],
  });

  final List<Activity> activities;
  final List<Category> categories;

  @override
  List<Activity> loadActivities() => activities;

  @override
  List<Category> loadCategories() => categories;
}

Widget wrap(StorageService storage) => ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
      child: const MaterialApp(home: SearchScreen()),
    );

/// Activité quotidienne (due tous les jours) : indépendante de la date réelle.
Activity daily(String name, {int hour = 9, Priority priority = Priority.normal}) =>
    Activity.create(
      name: name,
      hour: hour,
      minute: 0,
      date: DateTime(2020, 1, 1),
      repeat: RepeatRule.daily,
      priority: priority,
    );

void main() {
  testWidgets('au départ : toutes les activités sont listées', (tester) async {
    final storage = _FakeStorage(activities: [
      daily('Réveil', hour: 8),
      daily('Ménage', hour: 9),
      daily('Douche', hour: 7),
    ]);
    await tester.pumpWidget(wrap(storage));
    await tester.pumpAndSettle();

    expect(find.text('Recherche'), findsOneWidget);
    expect(find.text('Réveil'), findsOneWidget);
    expect(find.text('Ménage'), findsOneWidget);
    expect(find.text('Douche'), findsOneWidget);
  });

  testWidgets('la saisie filtre les résultats (insensible aux accents)',
      (tester) async {
    final storage = _FakeStorage(activities: [
      daily('Réveil', hour: 8),
      daily('Ménage', hour: 9),
    ]);
    await tester.pumpWidget(wrap(storage));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'menage');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Ménage'), findsOneWidget);
    expect(find.text('Réveil'), findsNothing);
  });

  testWidgets('la recherche par nom de catégorie fonctionne', (tester) async {
    final storage = _FakeStorage(
      categories: CategoryPresets.builtins.toList(),
      activities: [
        daily('Réunion', hour: 8, priority: Priority.normal)
            .copyWith(categoryId: 'builtin_work'),
        daily('Réveil'),
      ],
    );
    await tester.pumpWidget(wrap(storage));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'travail');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Réunion'), findsOneWidget);
    expect(find.text('Réveil'), findsNothing);
  });

  testWidgets('aucun résultat : état vide + bouton d\'effacement',
      (tester) async {
    final storage = _FakeStorage(activities: [daily('Réveil')]);
    await tester.pumpWidget(wrap(storage));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Aucune activité trouvée'), findsOneWidget);
    expect(find.text('Effacer la recherche et les filtres'), findsOneWidget);

    await tester.tap(find.text('Effacer la recherche et les filtres'));
    await tester.pumpAndSettle();

    expect(find.text('Réveil'), findsOneWidget);
  });

  testWidgets('le bouton effacer (×) vide la recherche', (tester) async {
    final storage = _FakeStorage(activities: [
      daily('Réveil'),
      daily('Ménage'),
    ]);
    await tester.pumpWidget(wrap(storage));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ménage');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Réveil'), findsOneWidget);
    expect(find.text('Ménage'), findsOneWidget);
  });

  testWidgets('le bouton filtre ouvre la feuille', (tester) async {
    final storage = _FakeStorage(activities: [daily('Réveil')]);
    await tester.pumpWidget(wrap(storage));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.text('Filtres'), findsOneWidget);
    // Les en-têtes de section sont rendus en capitales.
    expect(find.text('STATUT'), findsOneWidget);
    expect(find.text('PRIORITÉ'), findsOneWidget);
  });

  testWidgets('appliquer un filtre priorité met à jour les résultats',
      (tester) async {
    final storage = _FakeStorage(activities: [
      daily('Urgent act', hour: 8, priority: Priority.urgent),
      daily('Normal act', hour: 9),
    ]);
    await tester.pumpWidget(wrap(storage));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    // L'option Priorité est sous la ligne de flottaison de la feuille.
    await tester.ensureVisible(find.text('Urgent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Urgent'));
    await tester.pumpAndSettle();

    // Les résultats derrière la feuille sont filtrés en direct.
    expect(find.text('Urgent act'), findsOneWidget);
    expect(find.text('Normal act'), findsNothing);

    // Ferme la feuille : le filtre persiste (chip active + liste filtrée).
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(InputChip), findsOneWidget);
    expect(find.text('Urgent act'), findsOneWidget);
    expect(find.text('Normal act'), findsNothing);
  });

  testWidgets('« Tout effacer » depuis la feuille réinitialise les filtres',
      (tester) async {
    final storage = _FakeStorage(activities: [
      daily('Urgent act', hour: 8, priority: Priority.urgent),
      daily('Normal act', hour: 9),
    ]);
    await tester.pumpWidget(wrap(storage));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Urgent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Urgent'));
    await tester.pumpAndSettle();
    // Le bouton du haut de la feuille (il en existe un aussi dans la barre
    // de puces derrière la feuille : on cible celui de la feuille).
    final clearAllInSheet = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('Tout effacer'),
    );
    await tester.tap(clearAllInSheet);
    await tester.pumpAndSettle();

    expect(find.text('Urgent act'), findsOneWidget);
    expect(find.text('Normal act'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('aucun débordement sur petit écran (320 dp)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final storage = _FakeStorage(
      categories: CategoryPresets.builtins.toList(),
      activities: [
        daily('Une activité très longue pour tester l\'ellipse', hour: 8),
        daily('Ménage', hour: 9),
      ],
    );
    await tester.pumpWidget(wrap(storage));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ménage');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Feuille de filtres : ouverture puis défilement vers le bas pour
    // construire les sections basses et détecter tout débordement.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    final sheetScrollable = find
        .descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(sheetScrollable, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
