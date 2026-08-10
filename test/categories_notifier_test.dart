import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/models/activity.dart';
import 'package:rappel_plus/models/category.dart';
import 'package:rappel_plus/providers/providers.dart';
import 'package:rappel_plus/services/storage_service.dart';

/// Stockage en mémoire : catégories et activités persistées restent
/// inspectables et rechargées entre les lectures.
class _MemoryStorage extends StorageService {
  List<Activity> _activities = [];
  List<Category> _categories = [];

  List<Activity> get persistedActivities => List.of(_activities);
  List<Category> get persistedCategories => List.of(_categories);

  @override
  List<Activity> loadActivities() => _activities;

  @override
  Future<void> saveActivities(List<Activity> activities) async {
    _activities = List.of(activities);
  }

  @override
  List<Category> loadCategories() => _categories;

  @override
  Future<void> saveCategories(List<Category> categories) async {
    _categories = List.of(categories);
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
    // Laisse le chargement asynchrone des catégories se terminer.
    await Future<void>.delayed(Duration.zero);
  }

  group('categoriesProvider', () {
    test('créer une catégorie la persiste et la recharge', () async {
      await settle();
      final notifier = container.read(categoriesProvider.notifier);
      final c = Category.create(name: 'Santé', icon: '💊', colorIndex: 5);
      await notifier.create(c);

      expect(container.read(categoriesProvider), [c]);
      expect(storage.persistedCategories, hasLength(1));

      // Recharge depuis le stockage (simulation d'un redémarrage).
      container.read(categoriesProvider.notifier).load();
      expect(container.read(categoriesProvider).single.name, 'Santé');
    });

    test('modifier une catégorie conserve les autres', () async {
      await settle();
      final notifier = container.read(categoriesProvider.notifier);
      final a = Category.create(name: 'A');
      final b = Category.create(name: 'B');
      await notifier.create(a);
      await notifier.create(b);

      await notifier.update(a.copyWith(name: 'A modifiée', icon: '🏠'));

      final list = container.read(categoriesProvider);
      expect(list, hasLength(2));
      expect(list.first.name, 'A modifiée');
      expect(list.first.icon, '🏠');
      expect(list.last.name, 'B', reason: 'l\'autre catégorie est intacte');
    });

    test('supprimer retire uniquement la bonne catégorie', () async {
      await settle();
      final notifier = container.read(categoriesProvider.notifier);
      final a = Category.create(name: 'A');
      final b = Category.create(name: 'B');
      await notifier.create(a);
      await notifier.create(b);

      await notifier.delete(a.id);

      expect(container.read(categoriesProvider).single.id, b.id);
      expect(storage.persistedCategories.single.id, b.id);
    });

    test('la catégorie de repli n\'est jamais supprimée', () async {
      await settle();
      final notifier = container.read(categoriesProvider.notifier);
      final other =
          CategoryPresets.builtins.firstWhere((c) => c.isFallback);
      await notifier.create(other);

      await notifier.delete(CategoryPresets.otherId);

      final list = container.read(categoriesProvider);
      expect(list.where((c) => c.id == CategoryPresets.otherId), hasLength(1));
    });

    test('supprimer une catégorie inconnue ne change rien', () async {
      await settle();
      await container.read(categoriesProvider.notifier).delete('inconnue');
      expect(container.read(categoriesProvider), isEmpty);
    });
  });

  group('categoryByIdProvider', () {
    test('résout l\'identifiant, null si inconnu', () async {
      await settle();
      final c = Category.create(name: 'Famille');
      await container.read(categoriesProvider.notifier).create(c);

      expect(container.read(categoryByIdProvider(c.id))!.name, 'Famille');
      expect(container.read(categoryByIdProvider('absente')), isNull);
    });
  });

  group('ActivitiesNotifier.updateAll', () {
    test('réassigne en lot avec une seule écriture', () async {
      await settle();
      final a1 = Activity.create(
        name: 'A',
        hour: 8,
        minute: 0,
        date: DateTime(2026, 8, 10),
        categoryId: 'supprimee',
      );
      final a2 = Activity.create(
        name: 'B',
        hour: 9,
        minute: 0,
        date: DateTime(2026, 8, 10),
        categoryId: 'supprimee',
      );
      final notifier = container.read(activitiesProvider.notifier);
      await notifier.addAll([a1, a2]);

      await notifier.updateAll([
        a1.copyWith(categoryId: CategoryPresets.otherId),
        a2.copyWith(categoryId: CategoryPresets.otherId),
      ]);

      final list = container.read(activitiesProvider);
      expect(list, hasLength(2));
      expect(
        list.every((a) => a.categoryId == CategoryPresets.otherId),
        isTrue,
      );
      expect(storage.persistedActivities, hasLength(2));
    });

    test('updateAll avec une liste vide n\'écrit rien', () async {
      await settle();
      final notifier = container.read(activitiesProvider.notifier);
      final a = Activity.create(
        name: 'A',
        hour: 8,
        minute: 0,
        date: DateTime(2026, 8, 10),
      );
      await notifier.add(a);

      await notifier.updateAll(const []);

      expect(storage.persistedActivities, hasLength(1));
      expect(
        container.read(activitiesProvider).single.categoryId,
        CategoryPresets.otherId,
      );
    });
  });
}
