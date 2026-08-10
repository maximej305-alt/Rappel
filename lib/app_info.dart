import 'package:package_info_plus/package_info_plus.dart';

/// Version réelle de l'application, lue depuis le build
/// (pubspec.yaml → versionName du paquet installé).
class AppInfo {
  AppInfo._();

  /// Version semver (`1.0.0`), ou `null` si indisponible.
  static Future<String?> version() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final v = info.version.trim();
      return v.isEmpty ? null : v;
    } catch (_) {
      return null;
    }
  }
}
