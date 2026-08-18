import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/theme/app_theme.dart';
import 'package:rappel_plus/theme/theme_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Typography & Theme Font Tests', () {
    test('AppTheme supports every registered font family', () {
      final systemTheme = AppTheme.lightFor(
        ThemePalette.classic,
        fontFamily: 'System',
      );
      expect(systemTheme.textTheme.bodyMedium?.fontFamily, isNull);

      for (final family in AppTheme.fontFamilies) {
        if (family == 'System') continue;
        final theme = AppTheme.lightFor(ThemePalette.classic, fontFamily: family);
        expect(
          theme.textTheme.bodyMedium?.fontFamily,
          equals(family),
          reason: 'la famille $family doit être appliquée au thème',
        );
      }
    });

    test('every font family has a non-empty display name', () {
      for (final family in AppTheme.fontFamilies) {
        final label = AppTheme.fontDisplayName(family);
        expect(label, isNotEmpty, reason: '$family doit avoir un libellé');
        expect(label, isNot(contains('  ')), reason: '$label ne doit pas avoir de double espace');
      }
      expect(AppTheme.fontDisplayName('PlayfairDisplay'), 'Playfair Display');
      expect(AppTheme.fontDisplayName('JetBrainsMono'), 'JetBrains Mono');
      expect(AppTheme.fontDisplayName('SourceSans3'), 'Source Sans 3');
      expect(AppTheme.fontDisplayName('BebasNeue'), 'Bebas Neue');
      expect(AppTheme.fontDisplayName('UnknownFont'), 'UnknownFont');
    });

    test('AMOLED mode uses pure black #000000 surface in dark theme', () {
      final amoledTheme = AppTheme.darkFor(ThemePalette.classic, amoled: true);
      expect(amoledTheme.scaffoldBackgroundColor, equals(const Color(0xFF000000)));
    });

    test('fontFamilies matches the fonts declared in pubspec.yaml', () {
      final lines = File('pubspec.yaml').readAsStringSync().split('\n');
      final declared = <String>[];
      var inFlutter = false;
      var inFonts = false;
      for (final line in lines) {
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('flutter:')) {
          inFlutter = true;
          inFonts = false;
          continue;
        }
        if (inFlutter && trimmed.startsWith('fonts:')) {
          inFonts = true;
          continue;
        }
        if (inFonts) {
          if (trimmed.startsWith('- family: ')) {
            declared.add(trimmed.substring('- family: '.length).trim());
          } else if (trimmed.startsWith('assets:') || trimmed.isEmpty) {
            inFonts = false;
          }
        }
      }
      for (final family in AppTheme.fontFamilies) {
        if (family == 'System') continue;
        expect(
          declared,
          contains(family),
          reason:
              'la famille $family est proposée dans les réglages mais absente '
              'du bloc fonts: de pubspec.yaml',
        );
      }
    });
  });
}
