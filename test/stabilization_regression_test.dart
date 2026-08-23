import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/models/activity.dart';
import 'package:rappel_plus/models/category.dart';
import 'package:rappel_plus/models/lock_settings.dart';
import 'package:rappel_plus/models/routine.dart';
import 'package:rappel_plus/providers/providers.dart';
import 'package:rappel_plus/screens/add_activity_screen.dart';
import 'package:rappel_plus/services/storage_service.dart';

/// Stockage en mémoire pour les tests de régression.
class _MemoryStorage extends StorageService {
  List<Activity> _activities = [];
  List<Routine> _routines = [];
  List<Category> _categories = [];
  LockSettings _lock = const LockSettings();

  List<Activity> get persistedActivities => List.of(_activities);
  List<Routine> get persistedRoutines => List.of(_routines);
  LockSettings get persistedLock => _lock;

  @override
  List<Activity> loadActivities() => _activities;

  @override
  Future<void> saveActivities(List<Activity> activities) async {
    _activities = List.of(activities);
  }

  @override
  List<Routine> loadRoutines() => _routines;

  @override
  Future<void> saveRoutines(List<Routine> routines) async {
    _routines = List.of(routines);
  }

  @override
  List<Category> loadCategories() => _categories;

  @override
  Future<void> saveCategories(List<Category> categories) async {
    _categories = List.of(categories);
  }

  @override
  LockSettings loadLockSettings() => _lock;

  @override
  Future<void> saveLockSettings(LockSettings lock) async {
    _lock = lock;
  }
}

void main() {
  /// C4 — un cochage confirmé n'est jamais perdu, même si le notifier est
  /// détruit avant la fin du debounce de 400 ms.
  test('C4 : dispose() flush l\'écriture différée du cochage', () async {
    final storage = _MemoryStorage();
    // Pas de addTearDown : le dispose manuel EST le sujet du test.
    final container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );

    final notifier = container.read(activitiesProvider.notifier);
    await notifier.ready;
    final activity = Activity.create(name: 'Test', hour: 8, minute: 0, date: DateTime.now());
    await notifier.add(activity);

    await notifier.toggleCompleted(activity.id, DateTime.now());
    // Pas d'attente du debounce : on détruit directement.
    container.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(
      storage.persistedActivities.first.isCompletedOn(DateTime.now()),
      isTrue,
      reason: 'le flush au dispose doit persister le cochage',
    );
  });

  /// C5 — plus aucun motif en clair après migration.
  test('C5 : migration du motif legacy vers un hash PBKDF2', () async {
    final storage = _MemoryStorage();
    storage._lock = const LockSettings(
      enabled: true,
      method: LockMethod.pattern,
      patternHash: null,
      legacyPattern: [1, 2, 3],
    );
    final container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    // Charge (déclenche la migration) et attend la fin de la sauvegarde.
    final notifier = container.read(lockSettingsProvider.notifier);
    notifier.load();
    await notifier.migrationDone;

    final persisted = storage.persistedLock;
    expect(persisted.patternHash, isNotNull,
        reason: 'le motif migré doit être haché');
    expect(persisted.legacyPattern, isNull,
        reason: 'le motif en clair doit disparaître');
    expect(persisted.toMap().containsKey('pattern'), isFalse,
        reason: 'toMap ne doit jamais réécrire de motif en clair');

    // Le motif migré vérifie toujours le bon tracé.
    expect(await persisted.verifyPattern([1, 2, 3]), isTrue);
    expect(await persisted.verifyPattern([1, 2]), isFalse);
  });

  /// M8 — notificationId jamais 0 ni dupliqué depuis fromMap.
  test('M8 : identifiants de notification toujours valides et distincts',
      () {
    final a1 = Activity.fromMap({
      'id': 'a1',
      'name': 'A',
      'hour': 8,
      'minute': 0,
      'date': Activity.dateKey(DateTime.now()),
    });
    final a2 = Activity.fromMap({
      'id': 'a2',
      'name': 'B',
      'hour': 9,
      'minute': 0,
      'date': Activity.dateKey(DateTime.now()),
      'notificationId': -5,
    });
    expect(a1.notificationId, greaterThan(0));
    expect(a2.notificationId, greaterThan(0));
    for (var i = 0; i < 200; i++) {
      expect(Activity.newNotificationId(), isNot(0));
    }
  });

  /// M9 — suppression de catégorie : réassignation vers « Autre ».
  testWidgets('M9 : deleteCategoryAndReassign ne laisse aucun orphelin',
      (tester) async {
    final storage = _MemoryStorage();
    var result = false;

    late final ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context, listen: false);
              return ElevatedButton(
                onPressed: () async {
                  result = await deleteCategoryAndReassign(ref, 'cat_sport');
                },
                child: const Text('GO'),
              );
            },
          ),
        ),
      ),
    );

    final activity = Activity.create(
      name: 'X',
      hour: 7,
      minute: 30, date: DateTime.now(),
      categoryId: 'cat_sport',
    );
    await container.read(activitiesProvider.notifier).add(activity);
    await container
        .read(categoriesProvider.notifier)
        .create(const Category(id: 'cat_sport', name: 'Sport'));

    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(
      storage.persistedActivities.every((a) => a.categoryId != 'cat_sport'),
      isTrue,
      reason: 'aucune activité ne doit garder la catégorie supprimée',
    );
    expect(
      storage.persistedActivities.first.categoryId,
      CategoryPresets.otherId,
      reason: 'les activités vont sur la catégorie de repli',
    );
  });

  /// M10 — les clés d'événements calendrier sont UTC (TableCalendar).
  test('M10 : monthEventsProvider expose des clés DateTime.utc', () async {
    final storage = _MemoryStorage();
    final container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    await container.read(activitiesProvider.notifier).ready;
    final daily = Activity.create(name: 'Quotidien', hour: 9, minute: 0, date: DateTime.now());
    await container.read(activitiesProvider.notifier).add(daily);

    final now = DateTime.now();
    final events =
        container.read(monthEventsProvider(DateTime(now.year, now.month)));
    expect(events, isNotEmpty);
    expect(events.keys.every((k) => k.isUtc), isTrue,
        reason: 'TableCalendar transmet des jours UTC');
  });

  /// Purge des références mortes dans les routines à la suppression.
  test('remove() purge l\'ID supprimé des routines persistées', () async {
    final storage = _MemoryStorage();
    final container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(activitiesProvider.notifier);
    await notifier.ready;
    final a = Activity.create(name: 'A', hour: 6, minute: 0, date: DateTime.now());
    await notifier.add(a);
    await container
        .read(routinesProvider.notifier)
        .create(Routine.create(name: 'R', activityIds: [a.id]));

    await notifier.remove(a.id);
    expect(storage.persistedRoutines.first.activityIds, isEmpty,
        reason: 'la routine ne doit plus référencer l\'activité supprimée');
  });

  /// C2 — double-tap sur « Enregistrer » : une seule activité créée.
  testWidgets('C2 : double-tap sur Enregistrer ne duplique pas', (tester) async {
    final storage = _MemoryStorage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageServiceProvider.overrideWithValue(storage)],
        child: const MaterialApp(home: AddActivityScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Pilule');
    // Le formulaire est long : le bouton (en bas) n'est construit que
    // lorsqu'il défile à l'écran.
    final button = find.byWidgetPredicate((w) => w is FilledButton);
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(button, findsOneWidget);

    // Deux taps consécutifs sans attendre la fin de la première sauvegarde.
    await tester.tap(button, warnIfMissed: false);
    await tester.tap(button, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(storage.persistedActivities.length, 1,
        reason: 'un seul tap effectif : pas de duplication');
  });
}
