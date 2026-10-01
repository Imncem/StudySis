import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum StudySisPatternDensity { low, medium, high }

class StudySisDecorativeBackground extends StatelessWidget {
  const StudySisDecorativeBackground({
    required this.child,
    this.accentColor,
    this.density = StudySisPatternDensity.medium,
    this.opacity,
    this.hero = false,
    super.key,
  });

  final Widget child;
  final Color? accentColor;
  final StudySisPatternDensity density;
  final double? opacity;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final isDark = StudySisColors.isDark(context);
    final accent = accentColor ?? Theme.of(context).colorScheme.primary;
    final resolvedOpacity = opacity ?? (isDark ? 0.10 : 0.08);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: IgnorePointer(
              child: CustomPaint(
                painter: StudySisPatternPainter(
                  accentColor: accent,
                  density: density,
                  opacity: resolvedOpacity,
                  isDark: isDark,
                  hero: hero,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class StudySisPatternPainter extends CustomPainter {
  const StudySisPatternPainter({
    required this.accentColor,
    required this.density,
    required this.opacity,
    required this.isDark,
    required this.hero,
  });

  final Color accentColor;
  final StudySisPatternDensity density;
  final double opacity;
  final bool isDark;
  final bool hero;

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = accentColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    final warmPaint = Paint()
      ..color = (isDark ? StudySisColors.xpDark : StudySisColors.xp)
          .withValues(alpha: opacity * 0.72)
      ..style = PaintingStyle.fill;
    final softPaint = Paint()
      ..color = (isDark ? StudySisColors.muffinDark : StudySisColors.muffin)
          .withValues(alpha: opacity * 0.58)
      ..style = PaintingStyle.fill;

    if (hero) {
      canvas.drawCircle(
        Offset(size.width * 0.82, size.height * 0.04),
        size.shortestSide * 0.26,
        dotPaint,
      );
      canvas.drawCircle(
        Offset(size.width * 0.12, size.height * 0.78),
        size.shortestSide * 0.18,
        warmPaint,
      );
    }

    final step = switch (density) {
      StudySisPatternDensity.low => 132.0,
      StudySisPatternDensity.medium => 96.0,
      StudySisPatternDensity.high => 68.0,
    };
    var row = 0;
    for (double y = 28; y < size.height; y += step) {
      for (double x = row.isEven ? 24 : 68; x < size.width; x += step) {
        final selector = ((x + y) ~/ step) % 5;
        if (selector == 0) {
          _drawSparkle(canvas, Offset(x, y), 6, warmPaint);
        } else if (selector == 2) {
          canvas.drawCircle(Offset(x, y), 2.8, dotPaint);
        } else if (selector == 4) {
          canvas.drawCircle(Offset(x + 7, y - 5), 1.8, softPaint);
        }
      }
      row++;
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * 0.28, center.dy - radius * 0.28)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx + radius * 0.28, center.dy + radius * 0.28)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius * 0.28, center.dy + radius * 0.28)
      ..lineTo(center.dx - radius, center.dy)
      ..lineTo(center.dx - radius * 0.28, center.dy - radius * 0.28)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant StudySisPatternPainter oldDelegate) {
    return accentColor != oldDelegate.accentColor ||
        density != oldDelegate.density ||
        opacity != oldDelegate.opacity ||
        isDark != oldDelegate.isDark ||
        hero != oldDelegate.hero;
  }
}
