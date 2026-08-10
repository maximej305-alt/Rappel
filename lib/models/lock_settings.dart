import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

enum LockMethod { pin, password, pattern, biometric }

extension LockMethodX on LockMethod {
  String get label => switch (this) {
        LockMethod.pin => 'Code PIN',
        LockMethod.password => 'Mot de passe',
        LockMethod.pattern => 'Motif',
        LockMethod.biometric => 'Empreinte digitale',
      };

  static LockMethod fromName(String? name) => LockMethod.values.firstWhere(
        (m) => m.name == name,
        orElse: () => LockMethod.pin,
      );
}

class LockSettings {
  const LockSettings({
    this.enabled = false,
    this.method = LockMethod.pin,
    this.pinHash,
    this.passwordHash,
    this.pattern = const [],
    this.useBiometric = false,
  });

  final bool enabled;
  final LockMethod method;
  final String? pinHash;
  final String? passwordHash;
  final List<int> pattern;
  final bool useBiometric;

  bool get hasCredential => switch (method) {
        LockMethod.pin => pinHash != null,
        LockMethod.password => passwordHash != null,
        LockMethod.pattern => pattern.isNotEmpty,
        LockMethod.biometric => true,
      };

  static String _hash(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  static String hashPin(String pin) => _hash('rappel:pin:$pin');
  static String hashPassword(String password) => _hash('rappel:pw:$password');

  bool verifyPin(String pin) => pinHash != null && pinHash == hashPin(pin);
  bool verifyPassword(String password) =>
      passwordHash != null && passwordHash == hashPassword(password);
  bool verifyPattern(List<int> entered) =>
      pattern.isNotEmpty && listEquals(pattern, entered);

  LockSettings copyWith({
    bool? enabled,
    LockMethod? method,
    String? pinHash,
    String? passwordHash,
    List<int>? pattern,
    bool? useBiometric,
  }) {
    return LockSettings(
      enabled: enabled ?? this.enabled,
      method: method ?? this.method,
      pinHash: pinHash ?? this.pinHash,
      passwordHash: passwordHash ?? this.passwordHash,
      pattern: pattern ?? this.pattern,
      useBiometric: useBiometric ?? this.useBiometric,
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'method': method.name,
        'pinHash': pinHash,
        'passwordHash': passwordHash,
        'pattern': pattern,
        'useBiometric': useBiometric,
      };

  factory LockSettings.fromMap(Map<String, dynamic> map) => LockSettings(
        enabled: (map['enabled'] as bool?) ?? false,
        method: LockMethodX.fromName(map['method'] as String?),
        pinHash: map['pinHash'] as String?,
        passwordHash: map['passwordHash'] as String?,
        pattern: (map['pattern'] as List?)?.cast<int>() ?? const [],
        useBiometric: (map['useBiometric'] as bool?) ?? false,
      );
}
