import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('basic Material interface renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Rappel+'))),
    );

    expect(find.text('Rappel+'), findsOneWidget);
  });
}
