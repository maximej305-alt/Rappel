import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Dérivation de secret résistante aux attaques locales.
///
/// Un PIN / mot de passe / motif est un secret court : un simple hash
/// déterministe (SHA-256 direct) serait vulnérable au brute-force. On utilise
/// donc PBKDF2-HMAC-SHA256 avec un sel aléatoire de 16 octets et
/// [iterations] itérations, stocké séparément du secret. La vérification est
/// menée en temps constant pour ne pas fuir d'information sur la longueur des
/// entrées.
///
/// Le nombre d'itérations est encodé dans le hash (`sel:iterations:hash`) pour
/// pouvoir évoluer sans casser les anciens secrets ; un hash historique sans
/// itérations (`sel:hash`) est vérifié avec [legacyIterations].
///
/// La dérivation est longue par conception (anti brute-force) : elle est donc
/// exécutée dans un Isolate pour ne jamais bloquer le thread UI.
abstract final class SecretHasher {
  /// Itérations pour les nouveaux secrets. Réduit depuis 150 000 car un
  /// appareil modeste (Snapdragon 4xx) mettait 5-10 s à vérifier un PIN.
  static const int iterations = 30000;

  /// Itérations des hashes historiques (format `sel:hash` sans compteur).
  static const int legacyIterations = 150000;

  static const int saltLength = 16;
  static const int keyLength = 32;

  static final Random _random = Random.secure();

  /// Calcule PBKDF2-HMAC-SHA256 (RFC 2898).
  static List<int> pbkdf2Sha256(
    String password,
    List<int> salt,
    int iterationCount,
    int length,
  ) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final blocks = (length + 31) ~/ 32;
    final result = <int>[];

    for (var block = 1; block <= blocks; block++) {
      final blockInput = <int>[
        ...salt,
        (block >> 24) & 0xff,
        (block >> 16) & 0xff,
        (block >> 8) & 0xff,
        block & 0xff,
      ];
      var u = hmac.convert(blockInput).bytes;
      final t = List<int>.of(u);
      for (var i = 1; i < iterationCount; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      final take = min(length - result.length, t.length);
      result.addAll(t.sublist(0, take));
    }
    return result;
  }

  /// Génère un sel aléatoire cryptographique.
  static List<int> newSalt() =>
      List<int>.generate(saltLength, (_) => _random.nextInt(256));

  /// Dérive un secret avec un sel aléatoire frais (hors thread UI).
  /// Retourne `(salt, iterations, hash)` encodés en base64.
  static Future<({String salt, String iterations, String hash})> hash(
      String secret) async {
    final salt = newSalt();
    return Isolate.run(() {
      final digest = pbkdf2Sha256(secret, salt, iterations, keyLength);
      return (
        salt: base64Encode(salt),
        iterations: '$iterations',
        hash: base64Encode(digest),
      );
    });
  }

  /// Vérifie un secret contre `salt` + `hash` (base64) avec [iterationCount]
  /// itérations, en temps constant, dans un Isolate pour ne pas bloquer le
  /// thread UI. [iterationCount] défaut : [iterations].
  static Future<bool> verify(
    String secret,
    String saltBase64,
    String hashBase64, {
    int iterationCount = iterations,
  }) async {
    try {
      final salt = base64Decode(saltBase64);
      return await Isolate.run(() {
        final digest =
            pbkdf2Sha256(secret, salt, iterationCount, keyLength);
        return constantTimeEquals(base64Encode(digest), hashBase64);
      });
    } catch (_) {
      return false;
    }
  }

  /// Compare deux chaînes en temps quasi constant (mémoire identique
  /// quelle que soit la position de la différence).
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// SHA-256 direct (ancien format de stockage, sans sel). Réservé à la
  /// migration de données existantes : toute nouvelle écriture doit passer
  /// par [hash] avec sel aléatoire.
  static String legacySha256(String input) =>
      sha256.convert(utf8.encode(input)).toString();
}