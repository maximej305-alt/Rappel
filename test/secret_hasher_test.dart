import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rappel_plus/models/lock_settings.dart';
import 'package:rappel_plus/services/secret_hasher.dart';

void main() {
  group('SecretHasher', () {
    test('hash + verify : un secret vérifié avec le sel stocké', () async {
      final r = await SecretHasher.hash('1234');
      expect(await SecretHasher.verify('1234', r.salt, r.hash), isTrue);
      expect(await SecretHasher.verify('1235', r.salt, r.hash), isFalse);
      expect(await SecretHasher.verify('', r.salt, r.hash), isFalse);
    });

    test('sel aléatoire : deux hachages du même secret diffèrent', () async {
      final a = await SecretHasher.hash('abcd');
      final b = await SecretHasher.hash('abcd');
      expect(a.salt, isNot(b.salt));
      expect(a.hash, isNot(b.hash));
      // Mais les deux restent vérifiables.
      expect(await SecretHasher.verify('abcd', a.salt, a.hash), isTrue);
      expect(await SecretHasher.verify('abcd', b.salt, b.hash), isTrue);
    });

    test('PBKDF2 : la dérivation est déterministe pour sel + itérations fixes', () {
      final salt = utf8.encode('just-a-salt');
      final d1 = SecretHasher.pbkdf2Sha256('secret', salt, 1000, 32);
      final d2 = SecretHasher.pbkdf2Sha256('secret', salt, 1000, 32);
      expect(d1, d2);
      final d3 = SecretHasher.pbkdf2Sha256('secret2', salt, 1000, 32);
      expect(d1, isNot(d3));
      // Longueur demandée respectée.
      expect(d1.length, 32);
      final d4 = SecretHasher.pbkdf2Sha256('secret', salt, 1000, 48);
      expect(d4.length, 48);
    });

    test('constantTimeEquals : principe de comparaison fiable', () {
      expect(SecretHasher.constantTimeEquals('abc', 'abc'), isTrue);
      expect(SecretHasher.constantTimeEquals('abc', 'abd'), isFalse);
      expect(SecretHasher.constantTimeEquals('abc', 'ab'), isFalse);
      expect(SecretHasher.constantTimeEquals('', ''), isTrue);
    });

    test('legacySha256 : correspond au format SHA-256 direct', () {
      final legacy = SecretHasher.legacySha256('rappel:pin:1234');
      expect(legacy.length, 64); // hex sha256
      expect(SecretHasher.legacySha256('rappel:pin:1234'), legacy);
      expect(SecretHasher.legacySha256('rappel:pin:1235'), isNot(legacy));
    });
  });

  group('LockSettings (modèle sécurisé)', () {
    test('sans credential, hasCredential est faux', () async {
      const lock = LockSettings();
      expect(lock.hasCredential, isFalse);
      expect(await lock.verifyPin('1234'), isFalse);
      expect(await lock.verifyPassword('x'), isFalse);
      expect(await lock.verifyPattern([1, 2]), isFalse);
    });

    test('hashPin + verifyPin : aller-retour', () async {
      final lock = LockSettings(
        enabled: true,
        method: LockMethod.pin,
        pinHash: await LockSettings.hashPin('1234'),
      );
      expect(lock.hasCredential, isTrue);
      expect(await lock.verifyPin('1234'), isTrue);
      expect(await lock.verifyPin('4321'), isFalse);
    });

    test('hashPassword + verifyPassword : aller-retour', () async {
      final lock = LockSettings(
        enabled: true,
        method: LockMethod.password,
        passwordHash: await LockSettings.hashPassword('monmotdepasse'),
      );
      expect(await lock.verifyPassword('monmotdepasse'), isTrue);
      expect(await lock.verifyPassword('autre'), isFalse);
    });

    test('motif : seul le hash est stocké, jamais le chemin en clair', () async {
      final lock = LockSettings(
        enabled: true,
        method: LockMethod.pattern,
        patternHash: await LockSettings.hashPattern([1, 2, 5, 4]),
      );
      expect(await lock.verifyPattern([1, 2, 5, 4]), isTrue);
      expect(await lock.verifyPattern([1, 2, 5, 3]), isFalse);
      expect(await lock.verifyPattern([1, 2, 5]), isFalse);
      expect(await lock.verifyPattern(const []), isFalse);
    });

    test('legacy : un ancien hash SHA-256 préfixé reste vérifiable', () async {
      final legacyPin = SecretHasher.legacySha256('rappel:pin:9999');
      final lock = LockSettings(
        enabled: true,
        method: LockMethod.pin,
        pinHash: legacyPin,
      );
      expect(await lock.verifyPin('9999'), isTrue);
      expect(await lock.verifyPin('0000'), isFalse);
    });

    test('rétrocompat : un hash `sel:hash` sans itérations (ancien format) '
        'reste vérifiable avec legacyIterations', () async {
      const pin = '2468';
      final salt = SecretHasher.newSalt();
      final digest = SecretHasher.pbkdf2Sha256(
        pin,
        salt,
        SecretHasher.legacyIterations,
        SecretHasher.keyLength,
      );
      final legacySalted = '${base64Encode(salt)}:${base64Encode(digest)}';
      final lock = LockSettings(
        enabled: true,
        method: LockMethod.pin,
        pinHash: legacySalted,
      );
      expect(await lock.verifyPin(pin), isTrue);
      expect(await lock.verifyPin('1357'), isFalse);
    });

    test('legacy pattern : un motif hérité en clair reste vérifiable ET '
        'est purgé dès qu\'un nouveau secret est posé', () async {
      // Charge depuis un ancien stockage contenant motif en clair.
      final restored = LockSettings.fromMap({
        'enabled': true,
        'method': 'pattern',
        'pattern': [3, 4, 1, 2, 5],
      });
      expect(await restored.verifyPattern([3, 4, 1, 2, 5]), isTrue);
      expect(await restored.verifyPattern([3, 4, 1, 2, 6]), isFalse);
      // Le legacy est re-sérialisé pour ne pas perdre l'accès.
      expect(restored.toMap()['pattern'], [3, 4, 1, 2, 5]);
      // Dès qu'un nouveau secret est posé, le clair disparaît.
      final upgraded = await restored.withSecret(
        LockMethod.pattern,
        pattern: [0, 2, 4, 6],
      );
      expect(upgraded.patternHash, isNotNull);
      expect(upgraded.toMap().containsKey('pattern'), isFalse);
      expect(await upgraded.verifyPattern([0, 2, 4, 6]), isTrue);
    });

    test('hasFallback : vrai uniquement si un secours est configuré', () async {
      const none = LockSettings(
        enabled: true,
        method: LockMethod.biometric,
        useBiometric: true,
      );
      expect(none.hasFallback, isFalse);

      final withPin = LockSettings(
        enabled: true,
        method: LockMethod.biometric,
        useBiometric: true,
        fallbackMethod: LockMethod.pin,
        pinHash: await LockSettings.hashPin('1234'),
      );
      expect(withPin.hasFallback, isTrue);

      final broken = LockSettings(
        enabled: true,
        method: LockMethod.biometric,
        fallbackMethod: LockMethod.password,
      );
      expect(broken.hasFallback, isFalse);
    });

    test('fromMap : fallbackMethod absent reste null (pas de PIN implicite)', () async {
      final restored = LockSettings.fromMap({
        'enabled': true,
        'method': 'biometric',
        'useBiometric': true,
      });
      expect(restored.fallbackMethod, isNull);
      expect(restored.hasFallback, isFalse);
    });

    test('toMap/fromMap : préserve salés + fallback (aucun secret en clair)', () async {
      final lock = LockSettings(
        enabled: true,
        method: LockMethod.biometric,
        useBiometric: true,
        fallbackMethod: LockMethod.pin,
        pinHash: await LockSettings.hashPin('1234'),
      );
      final restored = LockSettings.fromMap(lock.toMap());
      expect(restored.enabled, isTrue);
      expect(restored.method, LockMethod.biometric);
      expect(restored.fallbackMethod, LockMethod.pin);
      expect(restored.useBiometric, isTrue);
      expect(await restored.verifyPin('1234'), isTrue);
      // Le secret en clair ne doit apparaître nulle part.
      final serialized = jsonEncode(lock.toMap());
      expect(serialized.contains('1234'), isFalse);
    });
  });
}