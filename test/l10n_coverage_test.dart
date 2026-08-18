import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/l10n/app_strings.dart';
import 'package:rappel_plus/l10n/app_strings_ext.dart';

/// Audit automatisé des clés de traduction :
/// 1. chaque clé de référence (EN) existe dans les 8 langues,
/// 2. les placeholders `{...}` d'une clé sont tous conservés dans la
///    traduction (aucune variable perdue),
/// 3. aucune valeur ne reste en anglais alors qu'une langue est choisie.
void main() {
  final reference = AppStrings.en;
  final placeholderRe = RegExp(r'\{[a-zA-Z]+\}');

  for (final code in AppStrings.supportedLocales) {
    group('l10n — $code', () {
      final s = appStringsFor(code);

      test('couvre toutes les clés de référence', () {
        final missing = reference.keys
            .where((k) => !s.keys.contains(k))
            .toList();
        expect(missing, isEmpty, reason: 'clés manquantes: $missing');
      });

      test('conserve les placeholders des variables', () {
        final broken = <String>[];
        for (final key in reference.keys) {
          final en = reference.tr(key);
          final placeholders =
              placeholderRe.allMatches(en).map((m) => m.group(0)!).toSet();
          if (placeholders.isEmpty) continue;
          final localized = s.tr(key);
          final missing = placeholders
              .where((p) => !localized.contains(p))
              .toList();
          if (missing.isNotEmpty) {
            broken.add('$key ($missing)');
          }
        }
        expect(broken, isEmpty,
            reason: 'placeholders perdus: $broken');
      });

      test('aucun repli silencieux vers l\'anglais pour les clés de référence',
          () {
        final englishFalls = reference.keys
            .where((k) => !s.keys.contains(k))
            .map((k) => '$k -> "${s.tr(k)}"')
            .toList();
        expect(englishFalls, isEmpty,
            reason: 'ces clés retomberaient sur l\'anglais: $englishFalls');
      });
    });
  }
}
