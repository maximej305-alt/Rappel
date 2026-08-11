import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../models/lock_settings.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
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
  bool _checkingBiometric = false;
  bool _biometricFailed = false;
  final _pinKey = GlobalKey<PinPadState>();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    final lock = ref.read(lockSettingsProvider);
    if (lock.method == LockMethod.biometric) {
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
    final ok = await ref
        .read(biometricServiceProvider)
        .authenticate(localizedReason: context.l10n.verifyBiometric);
    if (!mounted) return;
    setState(() => _checkingBiometric = false);
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() => _biometricFailed = true);
    }
  }

  void _onPin(String pin) {
    final lock = ref.read(lockSettingsProvider);
    if (lock.verifyPin(pin)) {
      widget.onUnlocked();
    } else {
      _fail(context.l10n.wrongPin);
      _pinKey.currentState?.showError();
    }
  }

  void _onPassword(String password) {
    final lock = ref.read(lockSettingsProvider);
    if (lock.verifyPassword(password)) {
      widget.onUnlocked();
    } else {
      _fail(context.l10n.wrongPassword);
      _passwordController.clear();
    }
  }

  void _onPattern(List<int> pattern) {
    final lock = ref.read(lockSettingsProvider);
    if (lock.verifyPattern(pattern)) {
      widget.onUnlocked();
    } else {
      _fail(context.l10n.wrongPattern);
    }
  }

  void _fail(String message) {
    HapticFeedback.vibrate();
    _attempts++;
    setState(() => _error = message);
    // L'erreur disparaît après un court instant (sauf pour le motif,
    // qui est géré par son animation interne).
    if (ref.read(lockSettingsProvider).method != LockMethod.pattern) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _error = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(lockSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF12141D), const Color(0xFF171A26)]
                : [const Color(0xFFEEF0FF), const Color(0xFFFBFBFF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Logo(),
                    const SizedBox(height: 28),
                    _MethodLabel(
                      method: lock.method,
                      error: _error,
                      attempts: _attempts,
                      s: context.l10n,
                    ),
                    const SizedBox(height: 28),
                    _LockCard(
                      child: switch (lock.method) {
                        LockMethod.pin => PinPad(
                            key: _pinKey,
                            onCompleted: _onPin,
                            length: 4,
                          ),
                        LockMethod.password => _PasswordField(
                            controller: _passwordController,
                            obscure: _obscure,
                            error: _error,
                            onToggleObscure: () =>
                                setState(() => _obscure = !_obscure),
                            onSubmit: _onPassword,
                          ),
                        LockMethod.pattern => SizedBox(
                            width: 264,
                            height: 264,
                            child: PatternLock(
                              onCompleted: _onPattern,
                              error: _error != null,
                            ),
                          ),
                        LockMethod.biometric => _BiometricButton(
                            checking: _checkingBiometric,
                            failed: _biometricFailed,
                            onTap: _tryBiometric,
                          ),
                      },
                    ),
                    if (lock.useBiometric &&
                        lock.method != LockMethod.biometric) ...[
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: _checkingBiometric ? null : _tryBiometric,
                        icon: const Icon(Icons.fingerprint),
                        label: Text(context.l10n.useFingerprint),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
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
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            gradient: AppTheme.headerGradient,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppTheme.seed.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.notifications_active,
            color: Colors.white,
            size: 42,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          context.l10n.appName,
          style: AppTypography.displaySmall.copyWith(
            color: scheme.onSurface,
          ),
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

    return AnimatedSwitcher(
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
            error ?? switch (method) {
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
    );
  }

  IconData _promptIcon() => switch (method) {
        LockMethod.pin => Icons.pin_outlined,
        LockMethod.password => Icons.key_outlined,
        LockMethod.pattern => Icons.gesture,
        LockMethod.biometric => Icons.fingerprint,
      };
}

class _LockCard extends StatelessWidget {
  const _LockCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D202C) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.error,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool obscure;
  final String? error;
  final VoidCallback onToggleObscure;
  final ValueChanged<String> onSubmit;

  void _submit() {
    final value = controller.text.trim();
    if (value.isNotEmpty) onSubmit(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          obscureText: obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
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
                obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: scheme.outline,
              ),
              onPressed: onToggleObscure,
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _submit,
          child: Text(context.l10n.unlockBtn),
        ),
      ],
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
        GestureDetector(
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
          OutlinedButton(
            onPressed: onTap,
            child: Text(s.tryAgain),
          ),
        ],
      ],
    );
  }
}
