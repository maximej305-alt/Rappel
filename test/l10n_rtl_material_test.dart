import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/l10n/app_strings_ext.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('I18n, RTL & Material Localizations Tests', () {
    test('Arabic locale returns isRtl true', () {
      final strings = appStringsFor('ar');
      expect(strings.isRtl, isTrue);
      expect(strings.appName, equals('تذكير +'));
    });

    test('Chinese locale returns proper Chinese translations', () {
      final strings = appStringsFor('zh');
      expect(strings.isRtl, isFalse);
      expect(strings.today, equals('今天'));
    });

    test('Unknown locale falls back to English', () {
      final strings = appStringsFor('unknown_xyz');
      expect(strings.code, equals('en'));
      expect(strings.today, equals('Today'));
    });

    testWidgets('MaterialApp builds cleanly with Arabic RTL and GlobalMaterialLocalizations', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [
            Locale('fr'),
            Locale('en'),
            Locale('ar'),
            Locale('zh'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final direction = Directionality.of(context);
                return Text(
                  'RTL Test',
                  textDirection: direction,
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('RTL Test'), findsOneWidget);
    });
  });
}
