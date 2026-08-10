import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Motif de verrouillage 3×3 façon téléphone : points centrés, tracé fluide,
/// retour haptique et animation d'erreur.
class PatternLock extends StatefulWidget {
  const PatternLock({
    super.key,
    required this.onCompleted,
    this.error = false,
    this.color,
  });

  /// Appelé quand un motif d'au moins 4 points est relâché.
  final ValueChanged<List<int>> onCompleted;

  /// Passe à `true` pour déclencher l'animation d'erreur sur le dernier motif.
  final bool error;

  /// Couleur d'accent (par défaut : `colorScheme.primary`).
  final Color? color;

  @override
  State<PatternLock> createState() => _PatternLockState();
}

class _PatternLockState extends State<PatternLock>
    with SingleTickerProviderStateMixin {
  final _selected = <int>[];
  Offset? _current;
  List<int> _lastErrorPattern = const [];
  bool _showingError = false;

  late final AnimationController _errorController;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _errorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _shake = Tween(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(
        parent: _errorController,
        curve: const Interval(0, 1, curve: Curves.elasticOut),
      ),
    );
  }

  @override
  void didUpdateWidget(PatternLock old) {
    super.didUpdateWidget(old);
    if (widget.error && !old.error) {
      _playError();
    }
  }

  @override
  void dispose() {
    _errorController.dispose();
    super.dispose();
  }

  void _playError() {
    _lastErrorPattern = List.of(_selected);
    setState(() {
      _showingError = true;
      _current = null;
      _selected.clear();
    });
    HapticFeedback.vibrate();
    _errorController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 550), () {
      if (mounted) {
        _errorController.reset();
        setState(() => _showingError = false);
      }
    });
  }

  /// Centre de chaque point : cellule [0, cell] → centre `cell * 0.5`.
  static Offset _center(Size size, int node) {
    final cell = size.width / 3;
    final row = node ~/ 3;
    final col = node % 3;
    return Offset(cell * (col + 0.5), cell * (row + 0.5));
  }

  static const _positions = [
    (0, 0), (1, 0), (2, 0),
    (0, 1), (1, 1), (2, 1),
    (0, 2), (1, 2), (2, 2),
  ];

  /// Point le plus proche du doigt (dans un rayon d'accroche), ou `-1`.
  int _nearest(Offset pos, Size size) {
    final cell = size.width / 3;
    final threshold = cell * 0.62;
    var best = -1;
    double bestDist = threshold * threshold;
    for (var i = 0; i < _positions.length; i++) {
      final (col, row) = _positions[i];
      final center = Offset(cell * (col + 0.5), cell * (row + 0.5));
      final dx = pos.dx - center.dx;
      final dy = pos.dy - center.dy;
      final d2 = dx * dx + dy * dy;
      if (d2 <= bestDist) {
        bestDist = d2;
        best = i;
      }
    }
    return best;
  }

  void _onStart(Offset pos, Size size) {
    final node = _nearest(pos, size);
    if (node < 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selected.add(node);
      _current = pos;
    });
  }

  void _onUpdate(Offset pos, Size size) {
    if (_selected.isEmpty) return;
    setState(() => _current = pos);
    final node = _nearest(pos, size);
    if (node < 0 || _selected.contains(node)) return;
    // Empêche les sauts de points trop éloignés, tout en autorisant
    // les diagonales entre points adjacents (distance = cell × √2).
    final last = _center(size, _selected.last);
    final cand = _center(size, node);
    final cell = size.width / 3;
    final dx = cand.dx - last.dx;
    final dy = cand.dy - last.dy;
    if ((dx * dx + dy * dy) > (cell * 1.5) * (cell * 1.5)) return;
    HapticFeedback.selectionClick();
    setState(() => _selected.add(node));
  }

  void _onEnd() {
    if (_selected.isEmpty) return;
    final pattern = List<int>.of(_selected);
    setState(() {
      _current = null;
      _selected.clear();
    });
    if (pattern.length >= 4) widget.onCompleted(pattern);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : (constraints.hasBoundedHeight
                ? constraints.maxHeight
                : 260.0);
        final size = Size.square(side);
        return AnimatedBuilder(
          animation: _errorController,
          builder: (context, _) {
            return Transform.translate(
              offset: Offset(_shake.value, 0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => _onStart(d.localPosition, size),
                onPanUpdate: (d) => _onUpdate(d.localPosition, size),
                onPanEnd: (_) => _onEnd(),
                onPanCancel: _onEnd,
                child: CustomPaint(
                  size: size,
                  painter: _PatternPainter(
                    accent: widget.color ?? Theme.of(context).colorScheme.primary,
                    errorColor: Theme.of(context).colorScheme.error,
                    selected: _selected,
                    current: _current,
                    errorPattern: _showingError ? _lastErrorPattern : const [],
                    errorProgress: _showingError
                        ? _errorController.value
                        : 0.0,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required this.accent,
    required this.errorColor,
    required this.selected,
    required this.current,
    required this.errorPattern,
    required this.errorProgress,
  });

  final Color accent;
  final Color errorColor;
  final List<int> selected;
  final Offset? current;
  final List<int> errorPattern;
  final double errorProgress;

  static const _positions = [
    (0, 0), (1, 0), (2, 0),
    (0, 1), (1, 1), (2, 1),
    (0, 2), (1, 2), (2, 2),
  ];

  static Offset _center(Size size, int node) {
    final cell = size.width / 3;
    final (col, row) = _positions[node];
    return Offset(cell * (col + 0.5), cell * (row + 0.5));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 3;
    final error = errorPattern.isNotEmpty && errorProgress < 1.0;
    final color = error ? errorColor : accent;

    // Halo doux du dernier point (pour le fondu du motif d'erreur).
    if (error) {
      final fade = (1.0 - errorProgress).clamp(0.0, 1.0);
      for (final i in errorPattern) {
        final c = _center(size, i);
        canvas.drawCircle(
          c,
          cell * 0.5 * fade,
          Paint()..color = color.withValues(alpha: 0.12 * fade),
        );
      }
    }

    // Lignes entre les points sélectionnés.
    if (selected.length > 1) {
      final line = Paint()
        ..color = color
        ..strokeWidth = cell * 0.12
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      for (var i = 0; i < selected.length - 1; i++) {
        canvas.drawLine(
          _center(size, selected[i]),
          _center(size, selected[i + 1]),
          line,
        );
      }
      if (current != null && selected.isNotEmpty) {
        canvas.drawLine(_center(size, selected.last), current!, line);
      }
    }

    // Ligne principale (plus nette par-dessus le halo).
    if (selected.length > 1) {
      final solid = Paint()
        ..color = color.withValues(alpha: 0.85)
        ..strokeWidth = cell * 0.06
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < selected.length - 1; i++) {
        canvas.drawLine(
          _center(size, selected[i]),
          _center(size, selected[i + 1]),
          solid,
        );
      }
      if (current != null && selected.isNotEmpty) {
        canvas.drawLine(_center(size, selected.last), current!, solid);
      }
    }

    // Points.
    for (var i = 0; i < 9; i++) {
      final center = _center(size, i);
      final isSel = selected.contains(i);
      final isErr = error && errorPattern.contains(i);
      final r = cell * 0.16;

      if (isSel || isErr) {
        // Halo.
        canvas.drawCircle(
          center,
          r * 2.1,
          Paint()..color = color.withValues(alpha: isErr ? 0.2 : 0.22),
        );
        // Pastille pleine.
        canvas.drawCircle(center, r, Paint()..color = color);
        // Centre blanc.
        canvas.drawCircle(
          center,
          r * 0.45,
          Paint()..color = Colors.white,
        );
      } else {
        // Point inactif : contour fin.
        canvas.drawCircle(
          center,
          r * 1.05,
          Paint()
            ..color = color.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
        canvas.drawCircle(
          center,
          r * 0.32,
          Paint()..color = color.withValues(alpha: 0.12),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) {
    return old.accent != accent ||
        old.errorColor != errorColor ||
        old.selected != selected ||
        old.current != current ||
        old.errorPattern != errorPattern ||
        old.errorProgress != errorProgress;
  }
}
