import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/models/routine.dart';

void main() {
  group('Routine.create', () {
    test('deux routines reçoivent des identifiants distincts', () {
      final a = Routine.create(name: 'Matin');
      final b = Routine.create(name: 'Soir');
      expect(a.id, isNot(b.id));
    });

    test('les valeurs par défaut sont correctes', () {
      final r = Routine.create(name: 'Matin');
      expect(r.icon, '📋');
      expect(r.description, isNull);
      expect(r.activityIds, isEmpty);
      expect(r.active, isTrue);
      expect(r.createdAt, isNotNull);
    });

    test('on peut fournir une description, une icône et des activités', () {
      final r = Routine.create(
        name: 'Sport',
        icon: '🏋️',
        description: 'Quotidien',
        activityIds: const ['a1', 'a2'],
      );
      expect(r.icon, '🏋️');
      expect(r.description, 'Quotidien');
      expect(r.activityIds, ['a1', 'a2']);
    });
  });

  group('Routine.copyWith', () {
    test('conserve identité et date de création', () {
      final r = Routine.create(name: 'Matin', activityIds: const ['a1']);
      final updated = r.copyWith(name: 'Matin et soir');
      expect(updated.id, r.id);
      expect(updated.createdAt, r.createdAt);
      expect(updated.name, 'Matin et soir');
      expect(updated.activityIds, ['a1']);
    });

    test('permet de retirer une activité de la liste', () {
      final r = Routine.create(name: 'Matin', activityIds: const ['a1', 'a2']);
      final pruned = r.copyWith(activityIds: const ['a1']);
      expect(pruned.activityIds, ['a1']);
    });

    test('permet d\'activer / désactiver sans toucher au reste', () {
      final r = Routine.create(name: 'Matin');
      final paused = r.copyWith(active: false);
      expect(paused.active, isFalse);
      expect(paused.name, r.name);
      final resumed = paused.copyWith(active: true);
      expect(resumed.active, isTrue);
    });
  });

  group('Routine sérialisation', () {
    test('aller-retour toMap / fromMap', () {
      final r = Routine.create(
        name: 'Matin',
        icon: '🌅',
        description: 'Réveil',
        activityIds: const ['a1', 'a2'],
      );
      final restored = Routine.fromMap(r.toMap());
      expect(restored.id, r.id);
      expect(restored.name, r.name);
      expect(restored.icon, r.icon);
      expect(restored.description, r.description);
      expect(restored.activityIds, r.activityIds);
      expect(restored.createdAt, r.createdAt);
      expect(restored.active, r.active);
    });

    test('les champs absents sont tolérés (données anciennes)', () {
      final r = Routine.fromMap({
        'id': 'r1',
        'name': 'Ancienne',
      });
      expect(r.icon, '📋');
      expect(r.description, isNull);
      expect(r.activityIds, isEmpty);
      expect(r.active, isTrue);
    });

    test('une routine désactivée est restaurée désactivée', () {
      final r = Routine.fromMap({
        'id': 'r1',
        'name': 'Pause',
        'icon': '⏸️',
        'activityIds': <String>[],
        'createdAt': DateTime(2026, 8, 1).toIso8601String(),
        'active': false,
      });
      expect(r.active, isFalse);
    });
  });
}
