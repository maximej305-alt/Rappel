import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rappel_plus/models/lock_settings.dart';
import 'package:rappel_plus/providers/providers.dart';
import 'package:rappel_plus/screens/lock_gate.dart';
import 'package:rappel_plus/screens/splash_screen.dart';
import 'package:rappel_plus/services/storage_service.dart';

/// Stockage factice en mémoire : permet de piloter le verrou sans Hive.
class _FakeStorage extends StorageService {
  LockSettings lock = const LockSettings();

  @override
  LockSettings loadLockSettings() => lock;

  @override
  Future<void> saveLockSettings(LockSettings value) async {
    lock = value;
  }
}

void main() {
  Widget app(LockSettings lock, {required Widget child}) {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(_FakeStorage()..lock = lock),
      ],
      child: MaterialApp(home: LockGate(child: child)),
    );
  }

  Future<void> enterPin(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.text(d).first);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 250));
  }

  group('SplashScreen', () {
    testWidgets('affiche la marque Rappel+ puis déclenche onDone', (tester) async {
      var done = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(_FakeStorage()),
          ],
          child: MaterialApp(
            home: SplashScreen(onDone: () => done = true),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Rappel+'), findsOneWidget);
      expect(done, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(done, isTrue);
    });
  });

  group('LockGate', () {
    testWidgets('aucune sécurité activée → accueil direct', (tester) async {
      await tester.pumpWidget(
        app(const LockSettings(), child: const Scaffold(body: Text('HOME'))),
      );
      await tester.pump();
      expect(find.text('HOME'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets('PIN activé → écran de verrouillage demandé', (tester) async {
      final pinHash = await tester.runAsync(() => LockSettings.hashPin('1234'));
      final lock = LockSettings(
        enabled: true,
        method: LockMethod.pin,
        pinHash: pinHash,
      );
      await tester.pumpWidget(
        app(lock, child: const Scaffold(body: Text('HOME'))),
      );
      await tester.pump();
      expect(find.text('HOME'), findsNothing);
      expect(find.text('Rappel+'), findsWidgets);
    });

    testWidgets('mauvais PIN → reste verrouillé', (tester) async {
      final pinHash = await tester.runAsync(() => LockSettings.hashPin('1234'));
      final lock = LockSettings(
        enabled: true,
        method: LockMethod.pin,
        pinHash: pinHash,
      );
      await tester.pumpWidget(
        app(lock, child: const Scaffold(body: Text('HOME'))),
      );
      await tester.pump();
      await enterPin(tester, '9999');
      expect(find.text('HOME'), findsNothing);
      // Laisse expirer le minuteur d'effacement d'erreur.
      await tester.pump(const Duration(milliseconds: 550));
    });

    testWidgets('bon PIN → déverrouille vers l\'accueil', (tester) async {
      final pinHash = await tester.runAsync(() => LockSettings.hashPin('1234'));
      final lock = LockSettings(
        enabled: true,
        method: LockMethod.pin,
        pinHash: pinHash,
      );
      await tester.pumpWidget(
        app(lock, child: const Scaffold(body: Text('HOME'))),
      );
      await tester.pump();
      // La vérification PBKDF2 s'exécute dans un Isolate : runAsync permet
      // au vrai event loop de faire aboutir le déverrouillage. En JIT la
      // dérivation 150k itérations prend quelques secondes, on attend.
      await tester.runAsync(() async {
        await enterPin(tester, '1234');
        await Future<void>.delayed(const Duration(seconds: 4));
      });
      await tester.pump();
      expect(find.text('HOME'), findsOneWidget);
    });
  });
}
