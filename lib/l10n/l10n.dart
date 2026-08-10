import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'app_strings.dart';

export 'app_strings.dart';

/// Accès rapide aux chaînes traduites depuis n'importe quel widget :
/// `context.l10n.today`.
extension L10nX on BuildContext {
  AppStrings get l10n {
    final container = ProviderScope.containerOf(this, listen: false);
    return container.read(stringsProvider);
  }
}
