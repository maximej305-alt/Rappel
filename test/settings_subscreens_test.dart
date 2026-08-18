import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/screens/settings_pages.dart';
import 'package:rappel_plus/screens/settings_screen.dart';
import 'package:rappel_plus/providers/providers.dart';
import 'package:rappel_plus/services/storage_service.dart';

class _FakeStorage extends StorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings Sub-screens Navigation Widget Tests', () {
    testWidgets('SettingsScreen displays category cards and navigates to subpages', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(_FakeStorage()),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Paramètres'), findsOneWidget);

      // Tap on Appearance card
      final appearanceFinder = find.widgetWithText(Card, 'Apparence');
      expect(appearanceFinder, findsOneWidget);
      await tester.tap(appearanceFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AppearanceSettingsPage), findsOneWidget);
    });
  });
}