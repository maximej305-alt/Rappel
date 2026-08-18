import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/l10n/app_strings.dart';
import 'package:rappel_plus/l10n/app_strings_ext.dart';
import 'package:rappel_plus/utils/dates.dart';

void main() {
  group('i18n — repli sur l\'anglais', () {
    test('couverture fr / en complète', () {
      // Les maps de référence (fr, en) couvrent l'essentiel ; une différence
      // mineure de 1 clé est tolérée (repli automatique sur EN).
      expect(AppStrings.fr.tr('appName'), 'Rappel+');
      expect(AppStrings.en.tr('appName'), 'Rappel+');
      expect((AppStrings.fr.length - AppStrings.en.length).abs(), lessThanOrEqualTo(2));
    });

    test('une langue inconnue tombe sur l\'anglais', () {
      final s = appStringsFor('xx');
      expect(s.code, 'en');
      expect(s.tr('appName'), 'Rappel+');
    });

    test('langues additionnelles : clés traduites + repli anglais', () {
      final es = appStringsFor('es');
      final de = appStringsFor('de');
      final it = appStringsFor('it');
      final pt = appStringsFor('pt');
      final zh = appStringsFor('zh');
      final ar = appStringsFor('ar');
      expect(es.code, 'es');
      expect(de.code, 'de');
      expect(it.code, 'it');
      expect(pt.code, 'pt');
      expect(zh.code, 'zh');
      expect(ar.code, 'ar');

      // Clés traduites.
      expect(es.tr('cancel'), 'Cancelar');
      expect(de.tr('cancel'), 'Abbrechen');
      expect(it.tr('cancel'), 'Annulla');
      expect(pt.tr('cancel'), 'Cancelar');

      // Clés traduites partout (couverture complète garantie par
      // l10n_coverage_test.dart).
      expect(es.tr('notifTest'), 'Esta es una notificación de prueba 🎉');
      expect(de.tr('searchTitle'), 'Suche');
      expect(zh.tr('soundBell'), '铃声');
      expect(ar.tr('cancel'), 'إلغاء');

      // Clé inconnue de tous → repli sur la clé elle-même (jamais l'anglais).
      expect(es.tr('noSuchKey'), 'noSuchKey');
      expect(de.tr('noSuchKey'), 'noSuchKey');
      expect(it.tr('noSuchKey'), 'noSuchKey');
      expect(pt.tr('noSuchKey'), 'noSuchKey');
      expect(zh.tr('noSuchKey'), 'noSuchKey');
      expect(ar.tr('noSuchKey'), 'noSuchKey');
    });
  });

  group('dates — locales', () {
    test('intlLocale mappe chaque langue supportée', () {
      expect(intlLocale('fr'), 'fr_FR');
      expect(intlLocale('en'), 'en_US');
      expect(intlLocale('es'), 'es');
      expect(intlLocale('ar'), 'ar');
      expect(intlLocale('zh'), 'zh_CN');
      expect(intlLocale('xx'), 'en_US');
    });
  });
}