import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/models/activity.dart';
import 'package:rappel_plus/models/routine.dart';
import 'package:rappel_plus/providers/providers.dart';
import 'package:rappel_plus/services/storage_service.dart';

/// Stockage en mémoire : les activités et routines persistées restent
/// inspectables et rechargées entre les lectures.
class _MemoryStorage extends StorageService {
  List<Activity> _activities = [];
  List<Routine> _routines = [];

  List<Activity> get persistedActivities => List.of(_activities);
  List<Routine> get persistedRoutines => List.of(_routines);

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
}

void main() {
  late _MemoryStorage storage;
  late ProviderContainer container;

  setUp(() {
    storage = _MemoryStorage();
    container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
  });

  Future<void> settle() async {
    // Laisse le chargement asynchrone des activités se terminer.
    await Future<void>.delayed(Duration.zero);
  }

  group('routinesProvider', () {
    test('créer une routine la persiste et la recharge', () async {
      await settle();
      final notifier = container.read(routinesProvider.notifier);
      final routine = Routine.create(name: 'Matin');
      await notifier.create(routine);

      expect(container.read(routinesProvider), [routine]);
      expect(storage.persistedRoutines, hasLength(1));

      // Recharge depuis le stockage (simulation d'un redémarrage).
      container.read(routinesProvider.notifier).load();
      expect(container.read(routinesProvider).single.name, 'Matin');
    });

    test('modifier une routine conserve les autres', () async {
      await settle();
      final notifier = container.read(routinesProvider.notifier);
      final a = Routine.create(name: 'A');
      final b = Routine.create(name: 'B');
      await notifier.create(a);
      await notifier.create(b);

      await notifier.update(a.copyWith(name: 'A modifiée', icon: '🌅'));

      final list = container.read(routinesProvider);
      expect(list, hasLength(2));
      expect(list.first.name, 'A modifiée');
      expect(list.first.icon, '🌅');
      expect(list.last.name, 'B', reason: 'l\'autre routine est intacte');
    });

    test('supprimer une routine retire uniquement la bonne', () async {
      await settle();
      final notifier = container.read(routinesProvider.notifier);
      final a = Routine.create(name: 'A');
      final b = Routine.create(name: 'B');
      await notifier.create(a);
      await notifier.create(b);

      await notifier.remove(a.id);

      expect(container.read(routinesProvider).single.id, b.id);
      expect(storage.persistedRoutines.single.id, b.id);
    });
  });

  group('routineActivitiesProvider', () {
    test('résout les références depuis la liste globale', () async {
      await settle();
      final a1 = Activity.create(
        name: 'Réveil',
        hour: 7,
        minute: 0,
        date: DateTime(2026, 8, 10),
        repeat: RepeatRule.daily,
      );
      final a2 = Activity.create(
        name: 'Méditation',
        hour: 8,
        minute: 0,
        date: DateTime(2026, 8, 10),
        repeat: RepeatRule.daily,
      );
      await container.read(activitiesProvider.notifier).addAll([a1, a2]);

      final routine = Routine.create(
        name: 'Matin',
        activityIds: [a1.id, a2.id],
      );
      await container.read(routinesProvider.notifier).create(routine);

      final map = container.read(routineActivitiesProvider);
      expect(map[routine.id], hasLength(2));
      expect(map[routine.id]!.map((a) => a.id).toList(), [a1.id, a2.id]);
    });

    test('ignore les références devenues invalides', () async {
      await settle();
      final a1 = Activity.create(
        name: 'Réveil',
        hour: 7,
        minute: 0,
        date: DateTime(2026, 8, 10),
        repeat: RepeatRule.daily,
      );
      await container.read(activitiesProvider.notifier).add(a1);

      final routine = Routine.create(
        name: 'Matin',
        activityIds: [a1.id, 'disparue'],
      );
      await container.read(routinesProvider.notifier).create(routine);

      final map = container.read(routineActivitiesProvider);
      expect(map[routine.id], hasLength(1));
      expect(map[routine.id]!.single.id, a1.id);
    });

    test('ajout en lot : une seule activité, correctement liée', () async {
      await settle();
      final a = Activity.create(
        name: 'Lecture',
        hour: 21,
        minute: 0,
        date: DateTime(2026, 8, 10),
        repeat: RepeatRule.daily,
      );
      await container.read(activitiesProvider.notifier).addAll([a]);

      final routine = Routine.create(
        name: 'Soir',
        activityIds: [a.id],
      );
      await container.read(routinesProvider.notifier).create(routine);

      final map = container.read(routineActivitiesProvider);
      expect(map[routine.id]!.single.name, 'Lecture');
    });
  });

  group('modification d\'une activité de routine', () {
    test('ne touche jamais les autres activités de la routine', () async {
      await settle();
      final a1 = Activity.create(
        name: 'A',
        hour: 7,
        minute: 0,
        date: DateTime(2026, 8, 10),
        repeat: RepeatRule.daily,
      );
      final a2 = Activity.create(
        name: 'B',
        hour: 8,
        minute: 0,
        date: DateTime(2026, 8, 10),
        repeat: RepeatRule.daily,
      );
      await container.read(activitiesProvider.notifier).addAll([a1, a2]);
      final routine = Routine.create(name: 'R', activityIds: [a1.id, a2.id]);
      await container.read(routinesProvider.notifier).create(routine);

      await container
          .read(activitiesProvider.notifier)
          .update(a1.copyWith(name: 'A modifiée', hour: 9));

      final list = container.read(activitiesProvider);
      final map = container.read(routineActivitiesProvider);
      expect(list.first.name, 'A modifiée');
      expect(list.first.hour, 9);
      expect(map[routine.id]![1].name, 'B',
          reason: 'B reste inchangé lors de la modification de A');
      expect(map[routine.id]![1].hour, 8);
    });
  });

  group('suppression d\'une activité de routine', () {
    test('l\'activité est retirée et la référence de la routine nettoyée',
        () async {
      await settle();
      final a1 = Activity.create(
        name: 'A',
        hour: 7,
        minute: 0,
        date: DateTime(2026, 8, 10),
        repeat: RepeatRule.daily,
      );
      final a2 = Activity.create(
        name: 'B',
        hour: 8,
        minute: 0,
        date: DateTime(2026, 8, 10),
        repeat: RepeatRule.daily,
      );
      await container.read(activitiesProvider.notifier).addAll([a1, a2]);
      final routine = Routine.create(name: 'R', activityIds: [a1.id, a2.id]);
      await container.read(routinesProvider.notifier).create(routine);

      await container.read(activitiesProvider.notifier).remove(a1.id);
      await container
          .read(routinesProvider.notifier)
          .update(routine.copyWith(activityIds: [a2.id]));

      final map = container.read(routineActivitiesProvider);
      expect(map[routine.id], hasLength(1));
      expect(map[routine.id]!.single.id, a2.id);
    });
  });
}
