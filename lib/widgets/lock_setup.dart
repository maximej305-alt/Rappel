import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../models/lock_settings.dart';
import '../providers/providers.dart';
import 'pattern_lock.dart';
import 'pin_pad.dart';

/// Affiche le flux de création d'un verrou (méthode + 2 confirmations).
/// Retourne les réglages complets (code hashé) ou `null` si annulé.
Future<LockSettings?> promptLockSetup(
  BuildContext context,
  LockMethod method,
) async {
  final s = context.l10n;
  switch (method) {
    case LockMethod.pin:
      final pin = await _confirmTwice<String>(
        context,
        firstTitle: s.choosePin,
        secondTitle: s.confirmPin,
        subtitle: s.pinHint,
        build: (first) => PinPad(
          onCompleted: (value) => first(value),
          color: Theme.of(context).colorScheme.primary,
        ),
        validate: (a, b) => a == b,
      );
      if (pin == null) return null;
      return const LockSettings(enabled: true, method: LockMethod.pin)
          .copyWith(pinHash: LockSettings.hashPin(pin));

    case LockMethod.password:
      final pw = await _confirmTwice<String>(
        context,
        firstTitle: s.choosePassword,
        secondTitle: s.confirmPassword,
        subtitle: s.passwordMin,
        build: (first) => _PasswordBox(onSubmit: first),
        validate: (a, b) => a.length >= 4 && a == b,
        errorMessage: s.min4Chars,
      );
      if (pw == null) return null;
      return const LockSettings(enabled: true, method: LockMethod.password)
          .copyWith(passwordHash: LockSettings.hashPassword(pw));

    case LockMethod.pattern:
      final pattern = await _confirmTwice<List<int>>(
        context,
        firstTitle: s.drawPattern,
        secondTitle: s.drawPatternAgain,
        subtitle: s.patternMin,
        build: (first) => Center(
          child: SizedBox(
            width: 236,
            height: 236,
            child: PatternLock(
              onCompleted: (p) {
                if (p.length >= 4) first(p);
              },
            ),
          ),
        ),
        validate: (a, b) => a.length >= 4 && listEquals(a, b),
        errorMessage: s.patternMin,
      );
      if (pattern == null) return null;
      return const LockSettings(enabled: true, method: LockMethod.pattern)
          .copyWith(pattern: pattern);

    case LockMethod.biometric:
      return const LockSettings(
        enabled: true,
        method: LockMethod.biometric,
        useBiometric: true,
      );
  }
}

/// Confirmation en 2 étapes pour un code quelconque.
Future<T?> _confirmTwice<T>(
  BuildContext context, {
  required String firstTitle,
  required String secondTitle,
  required String subtitle,
  required Widget Function(ValueChanged<T>) build,
  required bool Function(T a, T b) validate,
  String? errorMessage,
}) async {
  final fallbackText = context.l10n.mismatch;
  final mismatchText = errorMessage ?? fallbackText;
  final first = await _promptOnce<T>(
    context,
    title: firstTitle,
    subtitle: subtitle,
    step: 1,
    build: build,
  );
  if (first == null) return null;
  var errorText = '';
  while (true) {
    if (!context.mounted) return null;
    final second = await _promptOnce<T>(
      context,
      title: secondTitle,
      subtitle: subtitle,
      step: 2,
      build: build,
      error: errorText.isEmpty ? null : errorText,
    );
    if (second == null) return null;
    if (validate(first, second)) return first;
    errorText = mismatchText;
  }
}

/// Dialogue « étape » unique : titre, sous-titre, contenu, pas d'actions.
Future<T?> _promptOnce<T>(
  BuildContext context, {
  required String title,
  required String subtitle,
  required int step,
  required Widget Function(ValueChanged<T>) build,
  String? error,
}) async {
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _SetupDialog<T>(
      title: title,
      subtitle: subtitle,
      step: step,
      bodyBuilder: build,
      error: error,
    ),
  );
}

class _SetupDialog<T> extends StatelessWidget {
  const _SetupDialog({
    required this.title,
    required this.subtitle,
    required this.step,
    required this.bodyBuilder,
    this.error,
  });

  final String title;
  final String subtitle;
  final int step;
  final Widget Function(ValueChanged<T>) bodyBuilder;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        width: 340,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1D202C) : Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 2; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    width: i <= step ? 26 : 10,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i <= step
                          ? scheme.primary
                          : scheme.outlineVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: scheme.outline,
              ),
            ),
            const SizedBox(height: 20),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              child: _StepBody<T>(
                bodyBuilder: bodyBuilder,
                error: error,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, size: 18),
              label: Text(context.l10n.cancel),
              style: TextButton.styleFrom(
                foregroundColor: scheme.outline,
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepBody<T> extends StatelessWidget {
  const _StepBody({required this.bodyBuilder, this.error});

  final Widget Function(ValueChanged<T>) bodyBuilder;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: error != null
              ? Padding(
                  key: const ValueKey('err'),
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            error!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox(key: ValueKey('ok'), width: 0, height: 0),
        ),
        bodyBuilder((value) => Navigator.of(context).pop(value)),
      ],
    );
  }
}

class _PasswordBox extends StatefulWidget {
  const _PasswordBox({required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<_PasswordBox> createState() => _PasswordBoxState();
}

class _PasswordBoxState extends State<_PasswordBox> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;

    return SizedBox(
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: _obscure,
            textAlign: TextAlign.center,
            onSubmitted: (_) => _submit(),
            style: TextStyle(
              fontSize: 20,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: 1.2,
            ),
            decoration: InputDecoration(
              labelText: s.passwordPlaceholder,
              hintText: s.secret,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Theme.of(context).colorScheme.outline,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: Text(s.continueLabel),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final value = _controller.text;
    if (value.trim().length >= 4) widget.onSubmit(value);
  }
}

/// Vérifie le verrou actuel avant de le modifier / le désactiver.
/// Retourne `true` si l'identité est confirmée.
Future<bool> promptLockVerification(
  WidgetRef ref,
  BuildContext context,
  LockSettings lock,
) async {
  if (lock.method == LockMethod.biometric) {
    return ref.read(biometricServiceProvider).authenticate(
          localizedReason: context.l10n.verifyBiometric,
        );
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        width: 340,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1D202C)
              : Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.verification,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.enterToContinue,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 20),
            switch (lock.method) {
              LockMethod.pin => PinPad(
                  onCompleted: (pin) {
                    Navigator.of(context).pop(lock.verifyPin(pin));
                  },
                ),
              LockMethod.password => _PasswordBox(
                  onSubmit: (pw) =>
                      Navigator.of(context).pop(lock.verifyPassword(pw)),
                ),
              LockMethod.pattern => SizedBox(
                  width: 220,
                  height: 220,
                  child: PatternLock(
                    onCompleted: (p) {
                      if (p.length >= 4) {
                        Navigator.of(context).pop(lock.verifyPattern(p));
                      }
                    },
                  ),
                ),
              LockMethod.biometric => const SizedBox.shrink(),
            },
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.close, size: 18),
              label: Text(context.l10n.cancel),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.outline,
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}
