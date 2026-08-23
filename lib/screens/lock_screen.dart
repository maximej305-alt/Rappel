import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../models/lock_settings.dart';
import '../providers/providers.dart';
import '../theme/app_typography.dart';
import '../widgets/pattern_lock.dart';
import '../widgets/pin_pad.dart';

/// Écran de verrouillage affiché tant que le code n'est pas saisi.
/// Mise en page professionnelle façon verrou de téléphone.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String? _error;
  bool _checking = false;
  bool _checkingBiometric = false;
  bool _biometricFailed = false;
  bool _usingFallback = false;
  final _pinKey = GlobalKey<PinPadState>();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  int _attempts = 0;

  LockSettings get _lockNow => ref.read(lockSettingsProvider);

  /// Méthode effectivement affichée : si la biométrie a échoué et qu'un
  /// secours est configuré, on bascule dessus.
  LockMethod get _effectiveMethod {
    final lock = _lockNow;
    if (lock.method == LockMethod.biometric &&
        _biometricFailed &&
        lock.hasFallback) {
      return lock.fallbackMethod!;
    }
    return lock.method;
  }

  @override
  void initState() {
    super.initState();
    if (_lockNow.method == LockMethod.biometric) {
      _tryBiometric();
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    if (_checkingBiometric) return;
    setState(() {
      _checkingBiometric = true;
      _biometricFailed = false;
    });
    final result = await ref
        .read(biometricServiceProvider)
        .authenticate(localizedReason: context.l10n.verifyBiometric);
    if (!mounted) return;
    setState(() {
      _checkingBiometric = false;
      // Une annulation volontaire (ou interruption) ne force pas le secours :
      // on reste sur la biométrie pour permettre un nouvel essai.
      _biometricFailed = result != BiometricAuthResult.success &&
          result != BiometricAuthResult.cancelled;
    });
    if (result == BiometricAuthResult.success) widget.onUnlocked();
  }

  /// Bascule sur la méthode de secours (ou retour à la biométrie).
  void _toggleFallback() {
    if (_usingFallback) {
      setState(() {
        _usingFallback = false;
        _biometricFailed = false;
      });
      _tryBiometric();
    } else {
      setState(() {
        _usingFallback = true;
        _biometricFailed = true;
        _error = null;
      });
    }
  }

  Future<void> _onPin(String pin) async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final lock = ref.read(lockSettingsProvider);
    final ok = await lock.verifyPin(pin);
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) {
      widget.onUnlocked();
    } else {
      _fail(context.l10n.wrongPin);
      _pinKey.currentState?.showError();
    }
  }

  Future<void> _onPassword(String password) async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final lock = ref.read(lockSettingsProvider);
    final ok = await lock.verifyPassword(password);
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) {
      widget.onUnlocked();
    } else {
      _fail(context.l10n.wrongPassword);
      _passwordController.clear();
    }
  }

  Future<void> _onPattern(List<int> pattern) async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final lock = ref.read(lockSettingsProvider);
    final ok = await lock.verifyPattern(pattern);
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) {
      widget.onUnlocked();
    } else {
      _fail(context.l10n.wrongPattern);
    }
  }

  void _fail(String message) {
    HapticFeedback.vibrate();
    _attempts++;
    setState(() => _error = message);
    // L'erreur disparaît après un court instant (le motif est déjà géré
    // par son animation interne de secousse).
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _error = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(lockSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = context.l10n;
    final effective = _effectiveMethod;
    final showFallback =
        lock.method == LockMethod.biometric && lock.hasFallback;
    final inFallback =
        _usingFallback ||
        (lock.method == LockMethod.biometric &&
            _biometricFailed &&
            lock.hasFallback);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Color.lerp(
                    Theme.of(context).scaffoldBackgroundColor,
                    Theme.of(context).colorScheme.primary,
                    isDark ? 0.08 : 0.06,
                  ) ??
                  Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            // Layout figé : le contenu est mis à l'échelle pour tenir à
            // l'écran, sans scrolling — la grille de motif ne peut plus
            // « bouger » pendant la saisie.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 360,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Logo(),
                      const SizedBox(height: 24),
                      _MethodLabel(
                        method: effective,
                        error: _error,
                        attempts: _attempts,
                        s: s,
                      ),
                      const SizedBox(height: 24),
                      _LockCard(
                        child: switch (effective) {
                          LockMethod.pin => PinPad(
                            key: _pinKey,
                            onCompleted: _onPin,
                            length: 4,
                            checking: _checking,
                            semantics: PinPadSemantics(
                              delete: s.delete,
                              error: s.wrongPin,
                            ),
                          ),
                          LockMethod.password => _PasswordField(
                            controller: _passwordController,
                            obscure: _obscure,
                            error: _error,
                            checking: _checking,
                            onToggleObscure: () =>
                                setState(() => _obscure = !_obscure),
                            onSubmit: _onPassword,
                          ),
                          LockMethod.pattern => _AdaptivePattern(
                            onCompleted: _onPattern,
                            error: _error != null,
                            checking: _checking,
                          ),
                          LockMethod.biometric => _BiometricButton(
                            checking: _checkingBiometric,
                            failed: _biometricFailed,
                            onTap: _tryBiometric,
                          ),
                        },
                      ),
                      const SizedBox(height: 8),
                      if (showFallback) ...[
                        TextButton.icon(
                          onPressed: _toggleFallback,
                          icon: Icon(
                            inFallback
                                ? Icons.fingerprint
                                : Icons.edit_outlined,
                            size: 18,
                          ),
                          label: Text(
                            inFallback
                                ? s.retryBiometric
                                : switch (lock.fallbackMethod) {
                                    LockMethod.pin => s.useFallbackPin,
                                    LockMethod.password => s.useFallbackPassword,
                                    LockMethod.pattern => s.useFallbackPattern,
                                    _ => s.useFallbackPin,
                                  },
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if ((lock.useBiometric || lock.useDeviceFingerprint) &&
                          lock.method != LockMethod.biometric &&
                          !inFallback) ...[
                        OutlinedButton.icon(
                          onPressed: _checkingBiometric ? null : _tryBiometric,
                          icon: const Icon(Icons.fingerprint),
                          label: Text(s.useFingerprint),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.8),
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      TextButton(
                        onPressed: () => _showForgotCode(context),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.outline,
                        ),
                        child: Text(s.forgotCode),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotCode(BuildContext context) {
    final s = context.l10n;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.forgotCodeTitle),
        content: Text(s.forgotCodeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(s.forgotCodeOk),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Image.asset(
              'assets/images/app_icon.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          context.l10n.appName,
          style: AppTypography.displaySmall.copyWith(color: scheme.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.lockAppTitle,
          style: AppTypography.captionMd.copyWith(
            fontWeight: AppTypography.w500,
            color: scheme.outline,
          ),
        ),
      ],
    );
  }
}

class _MethodLabel extends StatelessWidget {
  const _MethodLabel({
    required this.method,
    required this.error,
    required this.attempts,
    required this.s,
  });

  final LockMethod method;
  final String? error;
  final int attempts;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = error != null;
    final color = hasError ? scheme.error : scheme.onSurfaceVariant;

    return Semantics(
      label: switch (method) {
        LockMethod.pin => s.unlockPin,
        LockMethod.password => s.unlockPassword,
        LockMethod.pattern => s.unlockPattern,
        LockMethod.biometric => s.unlockBiometric,
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: Column(
          key: ValueKey(hasError),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasError ? Icons.error_outline : _promptIcon(),
              size: 22,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              error ??
                  switch (method) {
                    LockMethod.pin => s.unlockPin,
                    LockMethod.password => s.unlockPassword,
                    LockMethod.pattern => s.unlockPattern,
                    LockMethod.biometric => s.unlockBiometric,
                  },
              textAlign: TextAlign.center,
              style: AppTypography.titleSmall.copyWith(
                fontWeight: AppTypography.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _promptIcon() => switch (method) {
    LockMethod.pin => Icons.pin_outlined,
    LockMethod.password => Icons.key_outlined,
    LockMethod.pattern => Icons.gesture,
    LockMethod.biometric => Icons.fingerprint,
  };
}

/// Grille de motif auto-dimensionnée : carré, calé sur l'espace disponible,
/// jamais plus grand que 280 px pour rester utilisable au doigt.
class _AdaptivePattern extends StatelessWidget {
  const _AdaptivePattern({
    required this.onCompleted,
    required this.error,
    required this.checking,
  });

  final ValueChanged<List<int>> onCompleted;
  final bool error;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide.clamp(180.0, 280.0);
        return SizedBox(
          width: side,
          height: side,
          child: PatternLock(
            onCompleted: onCompleted,
            error: error,
            checking: checking,
            semanticHint: context.l10n.patternHint,
          ),
        );
      },
    );
  }
}

class _LockCard extends StatelessWidget {
  const _LockCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surface = Theme.of(context).cardTheme.color ?? scheme.surface;

    return Semantics(
      label: context.l10n.lockApp,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: scheme.brightness == Brightness.dark ? 0.35 : 0.06,
              ),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.error,
    required this.checking,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool obscure;
  final String? error;
  final bool checking;
  final VoidCallback onToggleObscure;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: context.l10n.passwordField,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            obscureText: obscure,
            enabled: !checking,
            textInputAction: TextInputAction.done,
            onSubmitted: onSubmit,
            style: TextStyle(
              fontSize: 18,
              color: scheme.onSurface,
              letterSpacing: 1.2,
            ),
            decoration: InputDecoration(
              hintText: context.l10n.passwordField,
              errorText: error,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: scheme.outline,
                ),
                onPressed: onToggleObscure,
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: checking ? null : () => onSubmit(controller.text),
            child: checking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(context.l10n.unlockBtn),
          ),
        ],
      ),
    );
  }
}

class _BiometricButton extends StatelessWidget {
  const _BiometricButton({
    required this.checking,
    required this.failed,
    required this.onTap,
  });

  final bool checking;
  final bool failed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = context.l10n;

    return Column(
      children: [
        Semantics(
          label: checking ? s.checking : s.touchSensor,
          child: GestureDetector(
            onTap: checking ? null : onTap,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: failed
                    ? scheme.error.withValues(alpha: 0.12)
                    : scheme.primary.withValues(alpha: 0.12),
                border: Border.all(
                  color: failed
                      ? scheme.error.withValues(alpha: 0.6)
                      : scheme.primary.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Center(
                child: checking
                    ? SizedBox(
                        width: 52,
                        height: 52,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.5,
                          color: scheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.fingerprint,
                        size: 58,
                        color: failed ? scheme.error : scheme.primary,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          failed ? s.touchSensor : (checking ? s.checking : s.touchSensor),
          style: AppTypography.labelLarge.copyWith(
            fontWeight: AppTypography.w600,
            color: failed ? scheme.error : scheme.onSurfaceVariant,
          ),
        ),
        if (failed) ...[
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onTap, child: Text(s.tryAgain)),
        ],
      ],
    );
  }
}
