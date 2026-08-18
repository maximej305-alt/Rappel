import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/l10n/app_strings.dart';
import 'package:rappel_plus/models/sound_option.dart';
import 'package:rappel_plus/providers/providers.dart';
import 'package:rappel_plus/services/storage_service.dart';
import 'package:rappel_plus/widgets/sound_picker_sheet.dart';

class _EmptyStorage extends StorageService {}

/// Harness : un écran avec un bouton qui ouvre la feuille de choix de son.
class _Harness extends StatefulWidget {
  const _Harness({required this.currentId});

  final String currentId;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  String? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () async {
                final chosen = await showSoundPickerSheet(
                  context,
                  currentId: widget.currentId,
                );
                setState(() => _result = chosen?.id);
              },
              child: const Text('ouvrir'),
            ),
            const SizedBox(height: 8),
            Text('resultat=${_result ?? ''}'),
          ],
        ),
      ),
    );
  }
}

Widget _app(String currentId) => ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(_EmptyStorage()),
      ],
      child: MaterialApp(
        home: _Harness(currentId: currentId),
      ),
    );

Finder _checkInTile(String soundId) => find.descendant(
      of: find.byKey(Key('sound-$soundId')),
      matching: find.byIcon(Icons.check_circle),
    );

void main() {
  final s = AppStrings.fr;

  testWidgets('ouvre avec le son courant pré-sélectionné', (tester) async {
    await tester.pumpWidget(_app('chime1'));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    // « Carillon » est déjà choisi à l'ouverture.
    expect(_checkInTile('chime1'), findsOneWidget);
    expect(_checkInTile('default'), findsNothing);
  });

  testWidgets(
      'toucher un son le sélectionne immédiatement (coche qui se déplace)',
      (tester) async {
    await tester.pumpWidget(_app('default'));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(_checkInTile('default'), findsOneWidget);
    expect(_checkInTile('chime1'), findsNothing);

    await tester.tap(find.byKey(const Key('sound-chime1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // La coche a quitté « Par défaut » et est allée sur « Carillon ».
    expect(_checkInTile('chime1'), findsOneWidget);
    expect(_checkInTile('default'), findsNothing);
  });

  testWidgets('« Enregistrer » renvoie le son sélectionné', (tester) async {
    await tester.pumpWidget(_app('default'));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sound-chime2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.widgetWithText(FilledButton, s.save));
    await tester.pumpAndSettle();

    expect(find.textContaining('resultat='), findsOneWidget);
    expect(find.text('resultat=chime2'), findsOneWidget);
    expect(SoundOption.fromId('chime2').id == 'chime2', isTrue);
  });

  testWidgets('annuler (barrière) ne change pas la sélection',
      (tester) async {
    await tester.pumpWidget(_app('default'));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sound-beep')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Fermer la feuille sans valider (tap en dehors).
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('resultat='), findsOneWidget);
  });
}