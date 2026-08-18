import '../services/secret_hasher.dart';

/// Méthodes de protection disponibles.
enum LockMethod { pin, password, pattern, biometric }

extension LockMethodX on LockMethod {
  /// Libellé générique (les libellés localisés sont fournis par l'écran
  /// de réglages via `l10n`).
  String get label => switch (this) {
        LockMethod.pin => 'Code PIN',
        LockMethod.password => 'Mot de passe',
        LockMethod.pattern => 'Motif',
        LockMethod.biometric => 'Biométrie',
      };

  static LockMethod fromName(String? name) => tryParse(name) ?? LockMethod.pin;

  /// `null` si [name] est absent ou inconnu — ne force jamais un PIN.
  static LockMethod? tryParse(String? name) {
    if (name == null || name.isEmpty) return null;
    for (final m in LockMethod.values) {
      if (m.name == name) return m;
    }
    return null;
  }
}

/// Réglages de protection du verrou.
///
/// Les secrets ne sont jamais stockés en clair : PIN, mot de passe et motif
/// sont dérivés via PBKDF2-HMAC-SHA256 avec un sel aléatoire
/// (`SaltHasher`), puis stockés au format `selBase64:iterations:hashBase64`.
///
/// Un motif n'est JAMAIS conservé en clair : on ne stocke que le hash de sa
/// représentation canonique (`node1,node2,...`).
class LockSettings {
  const LockSettings({
    this.enabled = false,
    this.method = LockMethod.pin,
    this.pinHash,
    this.passwordHash,
    this.patternHash,
    this.fallbackMethod,
    this.useBiometric = false,
    this.legacyPattern,
  });

  final bool enabled;
  final LockMethod method;

  /// Hashes au format `selBase64:hashBase64` (PBKDF2-SHA256).
  final String? pinHash;
  final String? passwordHash;
  final String? patternHash;

  /// Motif hérité d'une ancienne version où il était stocké en clair.
  /// Conservé uniquement pour permettre la vérification pendant la
  /// migration ; jamais utilisé pour une nouvelle écriture.
  final List<int>? legacyPattern;

  /// Méthode de secours quand [method] est biométrique (ex. PIN).
  final LockMethod? fallbackMethod;

  /// La biométrie est utilisée seule ou comme méthode principale.
  final bool useBiometric;

  bool get hasCredential => switch (method) {
        LockMethod.pin => pinHash != null,
        LockMethod.password => passwordHash != null,
        LockMethod.pattern => patternHash != null,
        LockMethod.biometric => true,
      };

  /// Méthode de secours effectivement utilisable quand [method] est
  /// biométrique : un PIN, mot de passe ou motif dont le hash existe.
  /// `null` si aucun secours réel n'est configuré.
  LockMethod? get effectiveFallback {
    final f = fallbackMethod;
    if (f == null) return null;
    return switch (f) {
      LockMethod.pin => pinHash != null ? f : null,
      LockMethod.password => passwordHash != null ? f : null,
      LockMethod.pattern => patternHash != null ? f : null,
      LockMethod.biometric => null,
    };
  }

  /// Vrai si un verrou de secours est configurable après échec biométrique.
  bool get hasFallback => effectiveFallback != null;

  /// Représentation canonique d'un motif : `n1,n2,n3,...`.
  static String _patternKey(List<int> path) => path.join(',');

  /// Dérive un secret en `selBase64:iterations:hashBase64` (hors thread UI).
  static Future<String> _saltedHash(String secret) async {
    final r = await SecretHasher.hash(secret);
    return '${r.salt}:${r.iterations}:${r.hash}';
  }

  static Future<String> hashPin(String pin) => _saltedHash(pin);
  static Future<String> hashPassword(String password) => _saltedHash(password);
  static Future<String> hashPattern(List<int> pattern) =>
      _saltedHash(_patternKey(pattern));

  /// Vérifie [secret] contre un hash éventuellement au format historique
  /// (SHA-256 simple préfixé) pour rester rétrocompatible. Asynchrone :
  /// la dérivation PBKDF2 s'exécute hors du thread UI.
  ///
  /// Formats acceptés :
  ///  - `selBase64:iterations:hashBase64` (actuel, itérations encodées) ;
  ///  - `selBase64:hashBase64` (ancien, vérifié avec [SecretHasher.legacyIterations]) ;
  ///  - hash SHA-256 hexadécimal direct (hérité de très vieilles versions).
  static Future<bool> _verifySaltedOrLegacy(
    String secret,
    String? stored,
    String legacyPrefix,
  ) async {
    if (stored == null) return false;
    final parts = stored.split(':');
    if (parts.length >= 3) {
      final iters = int.tryParse(parts[1]);
      if (iters == null || iters <= 0) return false;
      return SecretHasher.verify(
        secret,
        parts[0],
        parts.sublist(2).join(':'),
        iterationCount: iters,
      );
    }
    if (parts.length == 2) {
      return SecretHasher.verify(
        secret,
        parts[0],
        parts[1],
        iterationCount: SecretHasher.legacyIterations,
      );
    }
    // Ancien format : sha256('rappel:pin:$pin') — hachage direct sans sel.
    final legacy = SecretHasher.legacySha256('$legacyPrefix$secret');
    return SecretHasher.constantTimeEquals(legacy, stored);
  }

  Future<bool> verifyPin(String pin) =>
      _verifySaltedOrLegacy(pin, pinHash, 'rappel:pin:');

  Future<bool> verifyPassword(String password) =>
      _verifySaltedOrLegacy(password, passwordHash, 'rappel:pw:');

  Future<bool> verifyPattern(List<int> entered) async {
    // Nouveau format : hash sécurisé.
    if (patternHash != null) {
      return _verifySaltedOrLegacy(
        _patternKey(entered),
        patternHash,
        'rappel:pattern:',
      );
    }
    // Ancien format : comparaison directe avec le motif stocké en clair.
    final legacy = legacyPattern;
    if (legacy == null || legacy.length != entered.length) return false;
    for (var i = 0; i < legacy.length; i++) {
      if (legacy[i] != entered[i]) return false;
    }
    return true;
  }

  /// Réécrit le verrou avec un nouveau secret (les autres restent).
  Future<LockSettings> withSecret(
    LockMethod newMethod, {
    String? pin,
    String? password,
    List<int>? pattern,
  }) async {
    return LockSettings(
      enabled: enabled,
      method: newMethod,
      pinHash:
          pin != null ? await _saltedHash(pin) : pinHash,
      passwordHash: password != null
          ? await _saltedHash(password)
          : passwordHash,
      patternHash: pattern != null
          ? await _saltedHash(_patternKey(pattern))
          : patternHash,
      fallbackMethod: fallbackMethod,
      useBiometric: useBiometric,
    );
  }

  LockSettings copyWith({
    bool? enabled,
    LockMethod? method,
    String? pinHash,
    String? passwordHash,
    String? patternHash,
    LockMethod? fallbackMethod,
    bool? useBiometric,
    bool clearFallback = false,
  }) {
    return LockSettings(
      enabled: enabled ?? this.enabled,
      method: method ?? this.method,
      pinHash: pinHash ?? this.pinHash,
      passwordHash: passwordHash ?? this.passwordHash,
      patternHash: patternHash ?? this.patternHash,
      fallbackMethod: clearFallback ? null : fallbackMethod ?? this.fallbackMethod,
      useBiometric: useBiometric ?? this.useBiometric,
    );
  }

  factory LockSettings.fromMap(Map<String, dynamic> map) {
    final storedPattern = map['pattern'];
    return LockSettings(
      enabled: (map['enabled'] as bool?) ?? false,
      method: LockMethodX.fromName(map['method'] as String?),
      pinHash: map['pinHash'] as String?,
      passwordHash: map['passwordHash'] as String?,
      patternHash: map['patternHash'] as String?,
      fallbackMethod: LockMethodX.tryParse(map['fallbackMethod'] as String?),
      useBiometric: (map['useBiometric'] as bool?) ?? false,
      legacyPattern: storedPattern is List
          ? [for (final v in storedPattern) v as int]
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'method': method.name,
        'pinHash': pinHash,
        'passwordHash': passwordHash,
        'patternHash': patternHash,
        'fallbackMethod': fallbackMethod?.name,
        'useBiometric': useBiometric,
        // Conserve le motif hérité tant qu'il n'a pas été reconfiguré
        // (section migration) ; supprimé dès qu'un nouveau secret est posé.
        if (patternHash == null && legacyPattern != null)
          'pattern': legacyPattern,
      };
}
