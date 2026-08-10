import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/l10n/app_strings.dart';
import 'package:rappel_plus/models/activity.dart';
import 'package:rappel_plus/models/activity_priority.dart';
import 'package:rappel_plus/models/category.dart';
import 'package:rappel_plus/utils/activity_search.dart';

void main() {
  final s = AppStrings.fr;

  // Lundi 10 août 2026, 15h30.
  final now = DateTime(2026, 8, 10, 15, 30);

  final categories = <Category>[
    CategoryPresets.builtins[1], // Travail (builtin_work)
    CategoryPresets.builtins[4], // Autre (builtin_other)
    const Category(id: 'custom_sante', name: 'Santé', icon: '❤️'),
  ];

  Activity act(
    String name, {
    int hour = 9,
    int minute = 0,
    DateTime? date,
    Priority priority = Priority.normal,
    String categoryId = CategoryPresets.otherId,
    List<String> completedDays = const [],
    RepeatRule repeat = RepeatRule.none,
  }) =>
      Activity.create(
        name: name,
        hour: hour,
        minute: minute,
        date: date ?? DateTime(now.year, now.month, now.day),
        priority: priority,
        categoryId: categoryId,
        repeat: repeat,
      ).copyWith(completedDays: completedDays);

  List<String> search(
    List<Activity> activities, {
    String query = '',
    ActivityFilter filter = const ActivityFilter(),
    DateTime? at,
  }) =>
      filterActivities(
        activities: activities,
        categories: categories,
        query: query,
        filter: filter,
        now: at ?? now,
        s: s,
      ).map((a) => a.name).toList();

  group('normalizeForSearch', () {
    test('minuscules + accents supprimés', () {
      expect(normalizeForSearch('Ménage'), 'menage');
      expect(normalizeForSearch('ÉTÉ'), 'ete');
      expect(normalizeForSearch('ça été'), 'ca ete');
      expect(normalizeForSearch('François'), 'francois');
    });
  });

  group('recherche texte', () {
    test('nom contenant la requête', () {
      final activities = [
        act('Réveil'),
        act('Ménage cuisine'),
        act('Lire un livre'),
      ];
      expect(search(activities, query: 'Ménage'), ['Ménage cuisine']);
    });

    test('insensible à la casse', () {
      final activities = [act('Réveil'), act('Douche')];
      expect(search(activities, query: 'REVEIL'), ['Réveil']);
      expect(search(activities, query: 'douche'), ['Douche']);
    });

    test('insensible aux accents (requête non accentuée)', () {
      final activities = [act('Ménage'), act('Études')];
      expect(search(activities, query: 'menage'), ['Ménage']);
      expect(search(activities, query: 'etudes'), ['Études']);
    });

    test('recherche par nom de catégorie', () {
      final activities = [
        act('Réunion', categoryId: 'builtin_work'),
        act('Réveil'),
      ];
      expect(search(activities, query: 'travail'), ['Réunion']);
    });

    test('recherche par catégorie personnalisée, insensible aux accents', () {
      final activities = [
        act('Rendez-vous', categoryId: 'custom_sante'),
        act('Réveil'),
      ];
      expect(search(activities, query: 'sante'), ['Rendez-vous']);
    });

    test('la requête ne cible pas les catégories inexistantes', () {
      final activities = [
        act('Orpheline', categoryId: 'disparue'),
        act('Réveil'),
      ];
      expect(search(activities, query: 'disparue'), isEmpty);
    });

    test('requête vide : toutes les activités, triées', () {
      final activities = [
        act('Zulu', hour: 11),
        act('Alpha', hour: 8),
        act('Bravo', hour: 8),
      ];
      expect(search(activities), ['Alpha', 'Bravo', 'Zulu']);
    });

    test('une requête sans correspondance ne retourne rien', () {
      final activities = [act('Réveil'), act('Douche')];
      expect(search(activities, query: 'zzz'), isEmpty);
    });
  });

  group('filtres', () {
    test('filtre Date : aujourd\'hui', () {
      final activities = [
        act('Aujourd\'hui'),
        act('Demain', date: DateTime(2026, 8, 11)),
        act('Répète', repeat: RepeatRule.daily),
      ];
      expect(
        search(activities, filter: const ActivityFilter(date: DateScope.today)),
        ['Aujourd\'hui', 'Répète'],
      );
    });

    test('filtre Date : demain', () {
      final activities = [
        act('Aujourd\'hui'),
        act('Demain', date: DateTime(2026, 8, 11)),
        act('Répète', repeat: RepeatRule.daily),
      ];
      expect(
        search(
          activities,
          filter: const ActivityFilter(date: DateScope.tomorrow),
        ),
        // Trié par date de base croissante : le quotidien (10) avant le
        // ponctuel du 11.
        ['Répète', 'Demain'],
      );
    });

    test('filtre Date : cette semaine (lundi → dimanche)', () {
      final activities = [
        act('Lundi', date: DateTime(2026, 8, 10)),
        act('Dimanche', date: DateTime(2026, 8, 16)),
        act('Lundi prochain', date: DateTime(2026, 8, 17)),
      ];
      expect(
        search(
          activities,
          filter: const ActivityFilter(date: DateScope.thisWeek),
        ),
        ['Lundi', 'Dimanche'],
      );
    });

    test('filtre Statut : à faire = due aujourd\'hui et non terminée', () {
      final activities = [
        act('À faire', completedDays: const []),
        act('Faites', completedDays: const ['2026-08-10']),
        act('Future', date: DateTime(2026, 8, 12)),
      ];
      expect(
        search(activities, filter: const ActivityFilter(status: StatusFilter.todo)),
        ['À faire'],
      );
    });

    test('filtre Statut : à faire exclut une activité future non terminée', () {
      final activities = [
        act('Future', date: DateTime(2026, 8, 12)),
      ];
      expect(
        search(activities, filter: const ActivityFilter(status: StatusFilter.todo)),
        isEmpty,
      );
    });

    test('filtre Statut : terminées = due aujourd\'hui et terminée aujourd\'hui',
        () {
      final activities = [
        act('Faites', completedDays: const ['2026-08-10']),
        act('À faire', completedDays: const []),
        // Faite hier seulement : pas « terminée aujourd\'hui ».
        act(
          'Faite hier',
          repeat: RepeatRule.daily,
          completedDays: const ['2026-08-09'],
        ),
      ];
      expect(
        search(
          activities,
          filter: const ActivityFilter(status: StatusFilter.done),
        ),
        ['Faites'],
      );
    });

    test('filtre Priorité', () {
      final activities = [
        act('Urgent', priority: Priority.urgent),
        act('Important', priority: Priority.important),
        act('Normal'),
      ];
      expect(
        search(
          activities,
          filter: const ActivityFilter(priority: Priority.urgent),
        ),
        ['Urgent'],
      );
    });

    test('filtre Catégorie', () {
      final activities = [
        act('Réunion', categoryId: 'builtin_work'),
        act('Réveil', categoryId: CategoryPresets.otherId),
        act('Rendez-vous', categoryId: 'custom_sante'),
      ];
      expect(
        search(activities, filter: const ActivityFilter(categoryId: 'builtin_work')),
        ['Réunion'],
      );
    });
  });

  group('combinaison', () {
    test('requête ET filtre : intersection', () {
      final activities = [
        act('Ménage urgent', priority: Priority.urgent),
        act('Ménage normal'),
        act('Autre urgent', priority: Priority.urgent),
      ];
      expect(
        search(
          activities,
          query: 'ménage',
          filter: const ActivityFilter(priority: Priority.urgent),
        ),
        ['Ménage urgent'],
      );
    });

    test('tri appliqué après filtrage (heure croissante)', () {
      final activities = [
        act('Urgent tard', hour: 11, priority: Priority.urgent),
        act('Normal tôt', hour: 8),
        act('Autre tôt', hour: 8),
      ];
      expect(search(activities), ['Autre tôt', 'Normal tôt', 'Urgent tard']);
    });
  });

  group('ActivityFilter', () {
    test('inactif par défaut, actif dès qu\'un critère est posé', () {
      const empty = ActivityFilter();
      expect(empty.isActive, isFalse);
      expect(empty.activeCount, 0);

      const date = ActivityFilter(date: DateScope.today);
      expect(date.isActive, isTrue);
      expect(date.activeCount, 1);

      const two = ActivityFilter(
        date: DateScope.today,
        status: StatusFilter.todo,
      );
      expect(two.activeCount, 2);

      const three = ActivityFilter(
        date: DateScope.today,
        status: StatusFilter.todo,
        priority: Priority.urgent,
        categoryId: 'builtin_work',
      );
      expect(three.activeCount, 4);
    });

    test('copyWith efface priorité et catégorie via les drapeaux', () {
      const filter = ActivityFilter(
        date: DateScope.today,
        status: StatusFilter.todo,
        priority: Priority.urgent,
        categoryId: 'builtin_work',
      );
      final cleared = filter.copyWith(clearPriority: true, clearCategory: true);
      expect(cleared.priority, isNull);
      expect(cleared.categoryId, isNull);
      expect(cleared.date, DateScope.today);
      expect(cleared.status, StatusFilter.todo);
    });

    test('copyWith remplace une valeur sans perdre les autres', () {
      const filter = ActivityFilter(
        date: DateScope.today,
        status: StatusFilter.todo,
      );
      final changed = filter.copyWith(date: DateScope.tomorrow);
      expect(changed.date, DateScope.tomorrow);
      expect(changed.status, StatusFilter.todo);
    });
  });
}
