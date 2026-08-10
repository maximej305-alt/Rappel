import 'package:flutter/material.dart';

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.valueLabel,
    required this.unitLabel,
    this.size = 96,
    this.strokeWidth = 7,
    this.color = Colors.white,
    this.backgroundColor = Colors.white24,
  });

  final double progress;
  final String valueLabel;
  final String unitLabel;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            strokeWidth: strokeWidth,
            color: color,
            backgroundColor: backgroundColor,
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  valueLabel,
                  style: TextStyle(
                    fontSize: size * 0.24,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
                  ),
                ),
                SizedBox(height: size * 0.03),
                Text(
                  unitLabel,
                  style: TextStyle(
                    fontSize: size * 0.12,
                    color: color.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
