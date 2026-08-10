import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rappel_plus/models/activity.dart';
import 'package:rappel_plus/providers/providers.dart';
import 'package:rappel_plus/screens/stats_screen.dart';
import 'package:rappel_plus/services/storage_service.dart';

class _EmptyStorage extends StorageService {}

class _FakeStorage extends StorageService {
  _FakeStorage(this.activities);

  final List<Activity> activities;

  @override
  List<Activity> loadActivities() => activities;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  Widget wrap(StorageService storage) => ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
        ],
        child: const MaterialApp(home: StatsScreen()),
      );

  testWidgets('sans routine : invite à créer des activités', (tester) async {
    await tester.pumpWidget(wrap(_EmptyStorage()));
    await tester.pumpAndSettle();

    expect(find.text('Pas encore de routine'), findsOneWidget);
    expect(
      find.text(
        'Crée des activités, puis coche-les chaque jour pour voir ta progression.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('avec des activités : affiche toutes les sections', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));

    final sport = Activity.create(
      name: 'Sport',
      hour: 9,
      minute: 0,
      date: twoDaysAgo,
      repeat: RepeatRule.daily,
    )
        .withCompletedDay(twoDaysAgo, true)
        .withCompletedDay(yesterday, true);

    await tester.pumpWidget(wrap(_FakeStorage([sport])));
    await tester.pumpAndSettle();

    expect(find.text('Série actuelle'), findsOneWidget);
    expect(find.text('Meilleure série'), findsOneWidget);
    expect(find.text('Cette semaine'), findsOneWidget);
    expect(find.text('Progression hebdo'), findsOneWidget);
    expect(find.text('Historique'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Vue mensuelle'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Vue mensuelle'), findsOneWidget);
  });
}
