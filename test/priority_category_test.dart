import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/l10n/app_strings.dart';
import 'package:rappel_plus/models/activity.dart';
import 'package:rappel_plus/models/activity_priority.dart';
import 'package:rappel_plus/models/category.dart';
import 'package:rappel_plus/models/routine.dart';
import 'package:rappel_plus/services/routine_service.dart';

void main() {
  group('Priority', () {
    test('fromName tolère les valeurs inconnues → normal', () {
      expect(PriorityX.fromName('urgent'), Priority.urgent);
      expect(PriorityX.fromName('important'), Priority.important);
      expect(PriorityX.fromName('normal'), Priority.normal);
      expect(PriorityX.fromName(null), Priority.normal);
      expect(PriorityX.fromName('bogus'), Priority.normal);
    });

    test('ordre d\'index : normal < important < urgent', () {
      expect(Priority.normal.index, lessThan(Priority.important.index));
      expect(Priority.important.index, lessThan(Priority.urgent.index));
    });
  });

  group('CategoryPresets', () {
    test('cinq catégories intégrées avec identifiants stables', () {
      expect(CategoryPresets.builtins, hasLength(5));
      expect(
        CategoryPresets.builtins.map((c) => c.id).toSet(),
        {
          'builtin_perso',
          'builtin_work',
          'builtin_study',
          'builtin_sport',
          'builtin_other',
        },
      );
      expect(CategoryPresets.builtins.every((c) => c.builtin), isTrue);
    });

    test('builtin_other est l\'unique catégorie de repli', () {
      final fallbacks =
          CategoryPresets.builtins.where((c) => c.isFallback).toList();
      expect(fallbacks, hasLength(1));
      expect(fallbacks.single.id, CategoryPresets.otherId);
    });
  });

  group('Category', () {
    test('create génère un identifiant et conserve les champs', () {
      final c = Category.create(name: 'Santé', icon: '💊', colorIndex: 5);
      expect(c.id, isNotEmpty);
      expect(c.name, 'Santé');
      expect(c.icon, '💊');
      expect(c.colorIndex, 5);
      expect(c.builtin, isFalse);
      expect(c.isFallback, isFalse);
    });

    test('toMap/fromMap : aller-retour complet', () {
      const c = Category(
        id: 'x',
        name: 'Famille',
        nameKey: 'categoryOther',
        icon: '🏠',
        colorIndex: 3,
        builtin: true,
        isFallback: true,
      );
      final restored = Category.fromMap(c.toMap());
      expect(restored.id, 'x');
      expect(restored.name, 'Famille');
      expect(restored.nameKey, 'categoryOther');
      expect(restored.icon, '🏠');
      expect(restored.colorIndex, 3);
      expect(restored.builtin, isTrue);
      expect(restored.isFallback, isTrue);
    });

    test('fromMap tolère les champs manquants', () {
      final restored = Category.fromMap({'id': 'x'});
      expect(restored.name, '');
      expect(restored.nameKey, isNull);
      expect(restored.icon, '📦');
      expect(restored.colorIndex, 0);
      expect(restored.builtin, isFalse);
      expect(restored.isFallback, isFalse);
    });

    test('copyWith modifie uniquement les champs demandés', () {
      final c = Category.create(name: 'A', icon: '👤', colorIndex: 1);
      final next = c.copyWith(name: 'B');
      expect(next.id, c.id);
      expect(next.name, 'B');
      expect(next.icon, '👤');
      expect(next.colorIndex, 1);
      expect(c.name, 'A', reason: 'l\'original n\'est pas muté');
    });

    test('displayName : les intégrées sont traduites, les personnalisées non',
        () {
      final work =
          CategoryPresets.builtins.firstWhere((c) => c.id == 'builtin_work');
      expect(work.displayName(AppStrings.fr), 'Travail');
      expect(work.displayName(AppStrings.en), 'Work');

      final custom = Category.create(name: 'Mémo perso');
      expect(custom.displayName(AppStrings.fr), 'Mémo perso');
      expect(custom.displayName(AppStrings.en), 'Mémo perso');
    });
  });

  group('Activity : priorité et catégorie', () {
    test('create applique les valeurs par défaut', () {
      final a = Activity.create(
        name: 'X',
        hour: 9,
        minute: 0,
        date: DateTime(2026, 8, 10),
      );
      expect(a.priority, Priority.normal);
      expect(a.categoryId, CategoryPresets.otherId);
    });

    test('create conserve les valeurs fournies', () {
      final a = Activity.create(
        name: 'X',
        hour: 9,
        minute: 0,
        date: DateTime(2026, 8, 10),
        priority: Priority.urgent,
        categoryId: 'builtin_work',
      );
      expect(a.priority, Priority.urgent);
      expect(a.categoryId, 'builtin_work');
    });

    test('copyWith préserve priorité et catégorie si non précisées', () {
      final a = Activity.create(
        name: 'X',
        hour: 9,
        minute: 0,
        date: DateTime(2026, 8, 10),
        priority: Priority.important,
        categoryId: 'builtin_sport',
      );
      final next = a.copyWith(name: 'Y');
      expect(next.name, 'Y');
      expect(next.priority, Priority.important);
      expect(next.categoryId, 'builtin_sport');
    });

    test('toMap/fromMap : aller-retour complet', () {
      final a = Activity.create(
        name: 'X',
        hour: 9,
        minute: 0,
        date: DateTime(2026, 8, 10),
        priority: Priority.urgent,
        categoryId: 'custom-1',
      );
      final restored = Activity.fromMap(a.toMap());
      expect(restored.priority, Priority.urgent);
      expect(restored.categoryId, 'custom-1');
      expect(restored.id, a.id);
    });

    test('fromMap tolère l\'absence de priority et categoryId', () {
      final restored = Activity.fromMap({
        'id': 'a',
        'name': 'Ancienne',
        'hour': 7,
        'minute': 30,
        'date': '2026-08-10',
        'repeat': 'daily',
        'weekdays': <int>[],
        'sound': 'default',
        'enabled': true,
        'completedDays': <String>[],
        'notificationId': 1,
      });
      expect(restored.priority, Priority.normal);
      expect(restored.categoryId, CategoryPresets.otherId);
    });

    test('withCompletedDay conserve priorité et catégorie', () {
      final a = Activity.create(
        name: 'X',
        hour: 9,
        minute: 0,
        date: DateTime(2026, 8, 10),
        priority: Priority.important,
        categoryId: 'c1',
      );
      final next = a.withCompletedDay(DateTime(2026, 8, 10), true);
      expect(next.isCompletedOn(DateTime(2026, 8, 10)), isTrue);
      expect(next.priority, Priority.important);
      expect(next.categoryId, 'c1');
    });

    test('RoutineService.buildActivities propage priorité et catégorie', () {
      final activities = RoutineService.buildActivities(
        [
          RoutineActivityDraft(
            name: 'Réveil',
            hour: 7,
            minute: 0,
            sound: 'default',
            priority: Priority.urgent,
            categoryId: 'builtin_work',
          ),
        ],
        usedIds: const {},
        now: DateTime(2026, 8, 10),
      );
      expect(activities.single.priority, Priority.urgent);
      expect(activities.single.categoryId, 'builtin_work');
    });
  });
}
