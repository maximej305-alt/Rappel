/// Horloge injectable pour tester les comportements dépendant de la date
/// (rollover de minuit, jour « aujourd'hui », semaine courante).
///
/// En production, [DateTime.now()] via `final DateTime Function()`.
class Clock {
  const Clock(this._now);

  final DateTime Function() _now;

  factory Clock.system() => Clock(_systemNow);

  DateTime now() => _now();

  /// Normalise la date à minuit (jour courant sans composante horaire).
  DateTime today() => DayKey.normalize(now());

  /// Jour « aujourd'hui » en clé stable `yyyy-MM-dd`.
  String todayKey() => DayKey.key(now());

  static DateTime _systemNow() => DateTime.now();
}

/// Identifiants de jour (clés calendaires) partagés partout :
/// une SEULE source de vérité pour éviter les décalages de rollover.
abstract final class DayKey {
  static String key(DateTime d) =>
      '${_pad(d.year, 4)}-${_pad(d.month, 2)}-${_pad(d.day, 2)}';

  /// Décode une clé `yyyy-MM-dd` en [DateTime] à minuit. Lève une
  /// [FormatException] si la clé est malformée ou si la date est invalide
  /// (mois hors 1-12, jour inexistant). [tryDate] préférer pour un parsing
  /// défensif qui ne plante pas.
  static DateTime date(String key) {
    final parsed = tryDate(key);
    if (parsed == null) {
      throw FormatException('Clé de date invalide : "$key"');
    }
    return parsed;
  }

  /// Parsing défensif : renvoie `null` au lieu de lever sur une clé
  /// malformée (segments manquants, non numériques, date inexistante
  /// comme 31 février). Protège le démarrage contre les données corrompues.
  static DateTime? tryDate(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final result = DateTime(year, month, day);
    // DateTime normalise les débordements (31 février → 2 mars) : on vérifie
    // donc que le jour est réellement celui demandé.
    if (result.year != year || result.month != month || result.day != day) {
      return null;
    }
    return result;
  }

  static DateTime normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _pad(int value, int width) =>
      value.toString().padLeft(width, '0');
}