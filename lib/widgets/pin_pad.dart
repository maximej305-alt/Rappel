import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pavé numérique professionnel (type écran de verrouillage de téléphone).
/// Touches circulaires larges, retour haptique, animation de pression.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.onCompleted,
    this.length = 4,
    this.enabled = true,
    this.color,
    this.highlight = false,
  });

  final ValueChanged<String> onCompleted;
  final int length;
  final bool enabled;

  /// Couleur d'accent (par défaut : `colorScheme.primary`).
  final Color? color;

  /// `true` pour afficher les points déjà saisis en couleur accent.
  final bool highlight;

  @override
  State<PinPad> createState() => PinPadState();
}

class PinPadState extends State<PinPad> {
  final _digits = <String>[];
  bool _error = false;
  Color get _accent =>
      widget.color ?? Theme.of(context).colorScheme.primary;

  void _onDigit(String d) {
    if (!widget.enabled || _digits.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() {
      _digits.add(d);
      _error = false;
    });
    if (_digits.length == widget.length) {
      final code = _digits.join();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _digits.clear());
        widget.onCompleted(code);
      });
    }
  }

  void _onBackspace() {
    if (_digits.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _digits.removeLast());
  }

  void _flashError() {
    HapticFeedback.vibrate();
    setState(() => _error = true);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _error = false);
    });
  }

  /// Signale un code erroné (points rouges + vibration).
  void showError() => _flashError();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dotColor = _error ? scheme.error : _accent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Points de progression (animer lors d'un code faux).
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  width: i < _digits.length ? 30 : 13,
                  height: 13,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _digits.length
                        ? dotColor
                        : scheme.outlineVariant.withValues(alpha: 0.7),
                    border: Border.all(
                      color: i < _digits.length
                          ? dotColor.withValues(alpha: 0.5)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Column(
          children: [
            _row(['1', '2', '3']),
            const SizedBox(height: 14),
            _row(['4', '5', '6']),
            const SizedBox(height: 14),
            _row(['7', '8', '9']),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(width: 72),
                _Key(label: '0', accent: _accent, onTap: () => _onDigit('0')),
                SizedBox(
                  width: 72,
                  height: 72,
                  child: _ActionKey(
                    icon: Icons.backspace_outlined,
                    onTap: _onBackspace,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final d in digits) _Key(label: d, accent: _accent, onTap: () => _onDigit(d)),
      ],
    );
  }
}

class _Key extends StatefulWidget {
  const _Key({required this.label, required this.accent, required this.onTap});

  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: _pressed ? 0.88 : 1.0,
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _pressed
                ? widget.accent.withValues(alpha: 0.18)
                : Colors.transparent,
            border: Border.all(
              color: _pressed
                  ? widget.accent
                  : scheme.outlineVariant.withValues(alpha: 0.55),
              width: 1.4,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionKey extends StatefulWidget {
  const _ActionKey({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_ActionKey> createState() => _ActionKeyState();
}

class _ActionKeyState extends State<_ActionKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: _pressed ? 0.88 : 1.0,
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _pressed
                ? scheme.outlineVariant.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
          child: Icon(
            widget.icon,
            size: 24,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
