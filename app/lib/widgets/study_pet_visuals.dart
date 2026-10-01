import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/study_pet.dart';

class StudyEggAvatar extends StatelessWidget {
  const StudyEggAvatar({
    required this.egg,
    this.size = 92,
    this.selected = false,
    this.hero = false,
    this.crackProgress = 0,
    super.key,
  });

  final StudyEggDefinition egg;
  final double size;
  final bool selected;
  final bool hero;
  final double crackProgress;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      padding: EdgeInsets.all(hero ? size * 0.02 : size * 0.11),
      decoration: BoxDecoration(
        color: Color(egg.secondaryColor).withValues(alpha: hero ? 0.55 : 1),
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Color(egg.primaryColor) : const Color(0xFFE2E8E3),
          width: selected ? 3 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Color(egg.primaryColor).withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: CustomPaint(
        painter: _EggPainter(
          egg: egg,
          crackProgress: crackProgress,
          selected: selected,
        ),
      ),
    );
  }
}

class StudyPetAvatar extends StatelessWidget {
  const StudyPetAvatar({
    required this.pet,
    this.growthStage = StudyPetGrowthStage.hatchling,
    this.size = 92,
    super.key,
  });

  final StudyPetDefinition pet;
  final StudyPetGrowthStage growthStage;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: StudyPetCompanionVisual(
        pet: pet,
        growthStage: growthStage,
        size: size,
      ),
    );
  }
}

class StudyPetMysteryVisual extends StatelessWidget {
  const StudyPetMysteryVisual({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MysteryPetPainter(
          color: Theme.of(context).colorScheme.onSurface,
          surface: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}

class StudyPetCompanionVisual extends StatelessWidget {
  const StudyPetCompanionVisual({
    required this.pet,
    required this.size,
    this.growthStage = StudyPetGrowthStage.hatchling,
    this.idleValue = 0,
    super.key,
  });

  final StudyPetDefinition pet;
  final double size;
  final StudyPetGrowthStage growthStage;
  final double idleValue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _StudyPetPainter(
          pet: pet,
          growthStage: growthStage,
          idleValue: idleValue,
          outline: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class _EggPainter extends CustomPainter {
  const _EggPainter({
    required this.egg,
    required this.crackProgress,
    required this.selected,
  });

  final StudyEggDefinition egg;
  final double crackProgress;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(size.width * 0.13, size.height * 0.04) &
        Size(size.width * 0.74, size.height * 0.88);
    final eggPath = Path()
      ..moveTo(size.width * 0.50, size.height * 0.04)
      ..cubicTo(size.width * 0.16, size.height * 0.08, size.width * 0.04,
          size.height * 0.58, size.width * 0.22, size.height * 0.82)
      ..cubicTo(size.width * 0.36, size.height * 1.02, size.width * 0.70,
          size.height * 1.02, size.width * 0.84, size.height * 0.82)
      ..cubicTo(size.width * 1.02, size.height * 0.56, size.width * 0.84,
          size.height * 0.08, size.width * 0.50, size.height * 0.04)
      ..close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          Color(egg.secondaryColor),
          Color(egg.primaryColor).withValues(alpha: 0.88),
        ],
      ).createShader(rect);
    canvas.drawPath(eggPath, paint);

    final accent = Paint()
      ..color = Color(egg.primaryColor).withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.38, size.height * 0.43),
        width: size.width * 0.16,
        height: size.height * 0.10,
      ),
      accent,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.62, size.height * 0.62),
        width: size.width * 0.20,
        height: size.height * 0.13,
      ),
      accent,
    );

    final shine = Paint()..color = Colors.white.withValues(alpha: 0.56);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.38, size.height * 0.25),
        width: size.width * 0.13,
        height: size.height * 0.22,
      ),
      shine,
    );

    if (crackProgress > 0.05) {
      final crack = Path()
        ..moveTo(size.width * 0.48, size.height * 0.18)
        ..lineTo(size.width * 0.56, size.height * 0.30)
        ..lineTo(size.width * 0.49, size.height * 0.39)
        ..lineTo(size.width * 0.59, size.height * 0.52)
        ..lineTo(size.width * 0.52, size.height * 0.66);
      final metric = crack.computeMetrics().first;
      final partial = metric.extractPath(0, metric.length * crackProgress);
      canvas.drawPath(
        partial,
        Paint()
          ..color = Color(egg.primaryColor).withValues(alpha: 0.70)
          ..strokeWidth = selected ? 3 : 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_EggPainter oldDelegate) {
    return oldDelegate.egg != egg ||
        oldDelegate.crackProgress != crackProgress ||
        oldDelegate.selected != selected;
  }
}

class _MysteryPetPainter extends CustomPainter {
  const _MysteryPetPainter({
    required this.color,
    required this.surface,
  });

  final Color color;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final soft = color.withValues(alpha: 0.14);
    final body = Paint()..color = soft;
    final outline = Paint()
      ..color = color.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.64),
        width: size.width * 0.48,
        height: size.height * 0.48,
      ),
      body,
    );
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.33),
      size.width * 0.22,
      body,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.34, size.height * 0.20)
        ..lineTo(size.width * 0.39, size.height * 0.02)
        ..lineTo(size.width * 0.49, size.height * 0.20)
        ..close(),
      body,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.51, size.height * 0.20)
        ..lineTo(size.width * 0.63, size.height * 0.02)
        ..lineTo(size.width * 0.66, size.height * 0.22)
        ..close(),
      body,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.91),
        width: size.width * 0.56,
        height: size.height * 0.09,
      ),
      Paint()..color = color.withValues(alpha: 0.10),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.64),
        width: size.width * 0.48,
        height: size.height * 0.48,
      ),
      outline,
    );
    final lockPaint = Paint()..color = color.withValues(alpha: 0.45);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.50, size.height * 0.56),
          width: size.width * 0.22,
          height: size.height * 0.18,
        ),
        Radius.circular(size.width * 0.04),
      ),
      lockPaint,
    );
  }

  @override
  bool shouldRepaint(_MysteryPetPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.surface != surface;
  }
}

class _StudyPetPainter extends CustomPainter {
  const _StudyPetPainter({
    required this.pet,
    required this.growthStage,
    required this.idleValue,
    required this.outline,
  });

  final StudyPetDefinition pet;
  final StudyPetGrowthStage growthStage;
  final double idleValue;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Color(pet.primaryColor);
    final dark = Color.lerp(base, Colors.black, 0.22)!;
    final light = Color.lerp(base, Colors.white, 0.55)!;
    final blink = math.sin((idleValue * math.pi * 2) + 5.2) > 0.965;
    final tailFlick = math.sin(idleValue * math.pi * 2) * size.width * 0.025;
    final earTwitch = math.sin((idleValue + 0.18) * math.pi * 2) * 0.05;
    final auraAlpha = switch (growthStage) {
      StudyPetGrowthStage.hatchling => 0.0,
      StudyPetGrowthStage.young => 0.06,
      StudyPetGrowthStage.evolved => 0.11,
      StudyPetGrowthStage.adult => 0.16,
    };

    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.10);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.91),
        width: size.width * 0.60,
        height: size.height * 0.10,
      ),
      shadow,
    );
    if (auraAlpha > 0) {
      canvas.drawCircle(
        Offset(size.width * 0.50, size.height * 0.52),
        size.width *
            switch (growthStage) {
              StudyPetGrowthStage.hatchling => 0.0,
              StudyPetGrowthStage.young => 0.30,
              StudyPetGrowthStage.evolved => 0.38,
              StudyPetGrowthStage.adult => 0.45,
            },
        Paint()..color = light.withValues(alpha: auraAlpha),
      );
    }

    switch (pet.id) {
      case StudyPetId.fox:
        _drawFox(canvas, size, base, dark, light, blink, tailFlick, earTwitch);
      case StudyPetId.bunny:
        _drawBunny(canvas, size, base, dark, light, blink, earTwitch);
      case StudyPetId.cat:
        _drawCat(canvas, size, base, dark, light, blink, tailFlick, earTwitch);
    }
  }

  void _drawFox(
    Canvas canvas,
    Size size,
    Color base,
    Color dark,
    Color light,
    bool blink,
    double tailFlick,
    double earTwitch,
  ) {
    final maturity = growthStage.index;
    final isFinal = growthStage == StudyPetGrowthStage.adult;
    final isEvolved = growthStage.index >= StudyPetGrowthStage.evolved.index;
    final foxBase = isFinal
        ? const Color(0xFFB94F2D)
        : isEvolved
            ? const Color(0xFFC96732)
            : base;
    final foxDark = isFinal
        ? const Color(0xFF2F2927)
        : isEvolved
            ? const Color(0xFF4A342B)
            : dark;
    final foxLight = isFinal
        ? const Color(0xFFFFC68E)
        : isEvolved
            ? const Color(0xFFFFD6B1)
            : light;
    final body = Paint()..color = foxBase;
    final cream = Paint()..color = foxLight.withValues(alpha: 0.96);
    final bodyWidth = size.width *
        (isFinal
            ? 0.335
            : isEvolved
                ? 0.31 + maturity * 0.010
                : 0.34 + maturity * 0.012);
    final bodyHeight = size.height *
        (isFinal
            ? 0.545
            : isEvolved
                ? 0.49 + maturity * 0.014
                : 0.46 + maturity * 0.018);
    final headWidth = size.width *
        (isFinal
            ? 0.355
            : isEvolved
                ? 0.36 + maturity * 0.004
                : 0.38 + maturity * 0.006);
    final headHeight = size.height *
        (isFinal
            ? 0.365
            : isEvolved
                ? 0.35 + maturity * 0.005
                : 0.34 + maturity * 0.006);
    final headCenter = Offset(
      size.width * 0.50,
      size.height *
          (isFinal
              ? 0.35
              : isEvolved
                  ? 0.365
                  : 0.38),
    );
    final line = Paint()
      ..color = foxDark.withValues(alpha: isEvolved ? 0.68 : 0.55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    _drawFoxTail(
      canvas,
      size,
      foxBase,
      foxLight,
      foxDark,
      tailFlick,
      maturity,
      isEvolved,
      isFinal,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.66),
        width: bodyWidth,
        height: bodyHeight,
      ),
      body,
    );
    _drawFoxChest(canvas, size, cream, maturity);
    _drawFoxPaws(canvas, size, foxDark, foxLight, isEvolved, isFinal);
    _drawFoxEar(
      canvas,
      size,
      0.36,
      -0.14 - earTwitch * 0.2,
      foxBase,
      foxLight,
      foxDark,
      isEvolved,
      isFinal,
    );
    _drawFoxEar(
      canvas,
      size,
      0.64,
      0.14 + earTwitch * 0.2,
      foxBase,
      foxLight,
      foxDark,
      isEvolved,
      isFinal,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: headCenter,
        width: headWidth,
        height: headHeight,
      ),
      body,
    );
    if (isFinal) {
      _drawFinalFoxMarkings(canvas, size, foxDark, foxLight);
    }
    _drawFoxCheekFluff(canvas, size, foxBase, isEvolved);
    _drawFoxFace(canvas, size, foxDark, foxLight, blink, isEvolved, isFinal);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.40, size.height * 0.52)
        ..quadraticBezierTo(size.width * 0.50, size.height * 0.58,
            size.width * 0.60, size.height * 0.52),
      line,
    );
    _drawSpark(canvas, Offset(size.width * 0.72, size.height * 0.55),
        size.width * 0.035, foxLight);
    if (growthStage.index >= StudyPetGrowthStage.young.index) {
      _drawSpark(canvas, Offset(size.width * 0.28, size.height * 0.48),
          size.width * 0.030, const Color(0xFFFFD76A));
    }
    if (growthStage.index >= StudyPetGrowthStage.evolved.index) {
      _drawSpark(canvas, Offset(size.width * 0.76, size.height * 0.32),
          size.width * 0.040, const Color(0xFFFFA64D));
      _drawSpark(canvas, Offset(size.width * 0.31, size.height * 0.31),
          size.width * 0.026, const Color(0xFF5A4036));
    }
    if (isFinal) {
      _drawSpark(canvas, Offset(size.width * 0.70, size.height * 0.23),
          size.width * 0.032, const Color(0xFFFFC15A));
      _drawSpark(canvas, Offset(size.width * 0.26, size.height * 0.58),
          size.width * 0.024, const Color(0xFFFF7A3D));
    }
  }

  void _drawFoxTail(
    Canvas canvas,
    Size size,
    Color base,
    Color light,
    Color darkTip,
    double tailFlick,
    int maturity,
    bool isEvolved,
    bool isFinal,
  ) {
    final tailWidth = size.width *
        (isFinal
            ? 0.178
            : isEvolved
                ? 0.140 + maturity * 0.008
                : 0.125 + maturity * 0.010);
    final tail = Paint()
      ..color = base.withValues(alpha: 0.96)
      ..strokeWidth = tailWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final tailPath = Path()
      ..moveTo(size.width * 0.62, size.height * 0.69)
      ..cubicTo(
        size.width *
            (isFinal
                ? 0.90
                : isEvolved
                    ? 0.86
                    : 0.83),
        size.height *
                (isFinal
                    ? 0.43
                    : isEvolved
                        ? 0.47
                        : 0.52) +
            tailFlick,
        size.width *
            (isFinal
                ? 0.90
                : isEvolved
                    ? 0.88
                    : 0.86),
        size.height * (isFinal ? 0.81 : 0.78),
        size.width * (isFinal ? 0.60 : 0.64),
        size.height * 0.80,
      );
    canvas.drawPath(tailPath, tail);

    canvas.drawPath(
      Path()
        ..moveTo(
          size.width *
              (isFinal
                  ? 0.82
                  : isEvolved
                      ? 0.80
                      : 0.78),
          size.height *
                  (isFinal
                      ? 0.52
                      : isEvolved
                          ? 0.56
                          : 0.62) +
              tailFlick * 0.35,
        )
        ..quadraticBezierTo(
          size.width *
              (isFinal
                  ? 0.91
                  : isEvolved
                      ? 0.89
                      : 0.87),
          size.height * 0.69,
          size.width *
              (isFinal
                  ? 0.70
                  : isEvolved
                      ? 0.73
                      : 0.72),
          size.height * 0.785,
        ),
      Paint()
        ..color = (isEvolved ? darkTip : light).withValues(alpha: 0.92)
        ..strokeWidth = tailWidth *
            (isFinal
                ? 0.48
                : isEvolved
                    ? 0.54
                    : 0.62)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    if (isFinal) {
      canvas.drawPath(
        Path()
          ..moveTo(size.width * 0.72, size.height * 0.76)
          ..quadraticBezierTo(size.width * 0.83, size.height * 0.67,
              size.width * 0.78, size.height * 0.54)
          ..quadraticBezierTo(size.width * 0.86, size.height * 0.61,
              size.width * 0.88, size.height * 0.71),
        Paint()
          ..color = const Color(0xFFFFA64D).withValues(alpha: 0.52)
          ..strokeWidth = size.width * 0.020
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawFoxEar(
    Canvas canvas,
    Size size,
    double centerX,
    double rotation,
    Color base,
    Color light,
    Color darkTip,
    bool isEvolved,
    bool isFinal,
  ) {
    canvas.save();
    canvas.translate(size.width * centerX, size.height * 0.29);
    canvas.rotate(rotation);
    final earHeight = size.height *
        (isFinal
            ? 0.30
            : isEvolved
                ? 0.265
                : 0.24);
    final earWidth = size.width *
        (isFinal
            ? 0.105
            : isEvolved
                ? 0.12
                : 0.13);
    final ear = Path()
      ..moveTo(0, -earHeight)
      ..quadraticBezierTo(earWidth * 0.72, -earHeight * 0.38, earWidth * 0.48,
          size.height * 0.01)
      ..quadraticBezierTo(
          0, size.height * 0.06, -earWidth * 0.48, size.height * 0.01)
      ..quadraticBezierTo(-earWidth * 0.72, -earHeight * 0.38, 0, -earHeight)
      ..close();
    canvas.drawPath(ear, Paint()..color = base);
    if (isEvolved) {
      canvas.drawPath(
        Path()
          ..moveTo(0, -earHeight)
          ..quadraticBezierTo(earWidth * 0.44, -earHeight * 0.62,
              earWidth * 0.30, -earHeight * 0.38)
          ..quadraticBezierTo(
              0, -earHeight * 0.49, -earWidth * 0.30, -earHeight * 0.38)
          ..quadraticBezierTo(
              -earWidth * 0.44, -earHeight * 0.62, 0, -earHeight)
          ..close(),
        Paint()..color = darkTip.withValues(alpha: 0.90),
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(0, -earHeight * 0.70)
        ..quadraticBezierTo(earWidth * 0.34, -earHeight * 0.26, earWidth * 0.23,
            -earHeight * 0.02)
        ..quadraticBezierTo(
            0, size.height * 0.02, -earWidth * 0.23, -earHeight * 0.02)
        ..quadraticBezierTo(
            -earWidth * 0.34, -earHeight * 0.26, 0, -earHeight * 0.70)
        ..close(),
      Paint()..color = light.withValues(alpha: 0.86),
    );
    canvas.restore();
  }

  void _drawFoxChest(Canvas canvas, Size size, Paint cream, int maturity) {
    final chest = Path()
      ..moveTo(size.width * 0.50, size.height * 0.50)
      ..cubicTo(size.width * 0.60, size.height * 0.55, size.width * 0.59,
          size.height * 0.69, size.width * 0.54, size.height * 0.78)
      ..lineTo(size.width * 0.50, size.height * (0.82 + maturity * 0.004))
      ..lineTo(size.width * 0.46, size.height * 0.78)
      ..cubicTo(size.width * 0.41, size.height * 0.69, size.width * 0.40,
          size.height * 0.55, size.width * 0.50, size.height * 0.50)
      ..close();
    canvas.drawPath(chest, cream);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.43, size.height * 0.57)
        ..lineTo(size.width * 0.50, size.height * 0.66)
        ..lineTo(size.width * 0.57, size.height * 0.57),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.30)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawFoxPaws(
      Canvas canvas, Size size, Color dark, Color light, bool isEvolved,
      [bool isFinal = false]) {
    final pawPaint = Paint()
      ..color = dark.withValues(
          alpha: isFinal
              ? 0.78
              : isEvolved
                  ? 0.64
                  : 0.16);
    final footPaint = Paint()
      ..color =
          (isEvolved ? dark : light).withValues(alpha: isFinal ? 0.76 : 0.68);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.42, size.height * 0.83),
        width: size.width * 0.15,
        height: size.height * 0.065,
      ),
      pawPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.58, size.height * 0.83),
        width: size.width * 0.15,
        height: size.height * 0.065,
      ),
      pawPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.44, size.height * 0.70),
        width: size.width * 0.055,
        height: size.height * 0.13,
      ),
      footPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.56, size.height * 0.70),
        width: size.width * 0.055,
        height: size.height * 0.13,
      ),
      footPaint,
    );
  }

  void _drawFoxCheekFluff(
      Canvas canvas, Size size, Color base, bool isEvolved) {
    final cheek = Paint()..color = base;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.34, size.height * 0.39)
        ..lineTo(size.width * 0.25, size.height * 0.45)
        ..lineTo(size.width * 0.35, size.height * 0.48)
        ..close(),
      cheek,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.66, size.height * 0.39)
        ..lineTo(size.width * 0.75, size.height * 0.45)
        ..lineTo(size.width * 0.65, size.height * 0.48)
        ..close(),
      cheek,
    );
    if (isEvolved) {
      final accent = Paint()
        ..color = const Color(0xFF5A4036).withValues(alpha: 0.54);
      canvas.drawPath(
        Path()
          ..moveTo(size.width * 0.30, size.height * 0.42)
          ..lineTo(size.width * 0.22, size.height * 0.45)
          ..lineTo(size.width * 0.32, size.height * 0.46)
          ..close(),
        accent,
      );
      canvas.drawPath(
        Path()
          ..moveTo(size.width * 0.70, size.height * 0.42)
          ..lineTo(size.width * 0.78, size.height * 0.45)
          ..lineTo(size.width * 0.68, size.height * 0.46)
          ..close(),
        accent,
      );
    }
  }

  void _drawFinalFoxMarkings(
      Canvas canvas, Size size, Color dark, Color emberLight) {
    final marking = Paint()..color = dark.withValues(alpha: 0.30);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.37, size.height * 0.28)
        ..quadraticBezierTo(size.width * 0.44, size.height * 0.34,
            size.width * 0.43, size.height * 0.45)
        ..quadraticBezierTo(size.width * 0.37, size.height * 0.42,
            size.width * 0.34, size.height * 0.35)
        ..close(),
      marking,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.63, size.height * 0.28)
        ..quadraticBezierTo(size.width * 0.56, size.height * 0.34,
            size.width * 0.57, size.height * 0.45)
        ..quadraticBezierTo(size.width * 0.63, size.height * 0.42,
            size.width * 0.66, size.height * 0.35)
        ..close(),
      marking,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.50, size.height * 0.52)
        ..quadraticBezierTo(size.width * 0.55, size.height * 0.62,
            size.width * 0.53, size.height * 0.77)
        ..lineTo(size.width * 0.50, size.height * 0.84)
        ..lineTo(size.width * 0.47, size.height * 0.77)
        ..quadraticBezierTo(size.width * 0.45, size.height * 0.62,
            size.width * 0.50, size.height * 0.52)
        ..close(),
      Paint()..color = emberLight.withValues(alpha: 0.34),
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.43, size.height * 0.58)
        ..quadraticBezierTo(size.width * 0.50, size.height * 0.64,
            size.width * 0.57, size.height * 0.58),
      Paint()
        ..color = dark.withValues(alpha: 0.42)
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawFoxFace(
    Canvas canvas,
    Size size,
    Color dark,
    Color light,
    bool blink,
    bool isEvolved,
    bool isFinal,
  ) {
    final eye = Paint()..color = dark.withValues(alpha: 0.88);
    final muzzle = Paint()..color = light.withValues(alpha: 0.92);
    if (isEvolved) {
      canvas.drawPath(
        Path()
          ..moveTo(size.width * (isFinal ? 0.390 : 0.405),
              size.height * (isFinal ? 0.405 : 0.410))
          ..quadraticBezierTo(
              size.width * 0.50,
              size.height * 0.505,
              size.width * (isFinal ? 0.610 : 0.595),
              size.height * (isFinal ? 0.405 : 0.410))
          ..quadraticBezierTo(
              size.width * 0.50,
              size.height * (isFinal ? 0.470 : 0.455),
              size.width * (isFinal ? 0.390 : 0.405),
              size.height * (isFinal ? 0.405 : 0.410))
          ..close(),
        muzzle,
      );
    } else {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.50, size.height * 0.43),
          width: size.width * 0.19,
          height: size.height * 0.105,
        ),
        muzzle,
      );
    }
    if (blink) {
      final blinkPaint = Paint()
        ..color = dark.withValues(alpha: 0.78)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(size.width * 0.41, size.height * 0.37),
          Offset(size.width * 0.46, size.height * 0.37), blinkPaint);
      canvas.drawLine(Offset(size.width * 0.54, size.height * 0.37),
          Offset(size.width * 0.59, size.height * 0.37), blinkPaint);
    } else {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.43, size.height * 0.37),
          width: size.width *
              (isFinal
                  ? 0.066
                  : isEvolved
                      ? 0.060
                      : 0.048),
          height: size.height *
              (isFinal
                  ? 0.026
                  : isEvolved
                      ? 0.030
                      : 0.048),
        ),
        eye,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.57, size.height * 0.37),
          width: size.width *
              (isFinal
                  ? 0.066
                  : isEvolved
                      ? 0.060
                      : 0.048),
          height: size.height *
              (isFinal
                  ? 0.026
                  : isEvolved
                      ? 0.030
                      : 0.048),
        ),
        eye,
      );
      canvas.drawCircle(Offset(size.width * 0.438, size.height * 0.362),
          size.width * 0.007, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(size.width * 0.562, size.height * 0.362),
          size.width * 0.007, Paint()..color = Colors.white);
    }

    final brow = Paint()
      ..color = dark.withValues(
          alpha: isFinal
              ? 0.88
              : isEvolved
                  ? 0.78
                  : 0.50)
      ..strokeWidth = isFinal
          ? 2.3
          : isEvolved
              ? 2.1
              : 1.7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(
            size.width * 0.405,
            size.height *
                (isFinal
                    ? 0.326
                    : isEvolved
                        ? 0.330
                        : 0.335)),
        Offset(
            size.width * 0.465,
            size.height *
                (isFinal
                    ? 0.358
                    : isEvolved
                        ? 0.355
                        : 0.350)),
        brow);
    canvas.drawLine(
        Offset(
            size.width * 0.595,
            size.height *
                (isFinal
                    ? 0.326
                    : isEvolved
                        ? 0.330
                        : 0.335)),
        Offset(
            size.width * 0.535,
            size.height *
                (isFinal
                    ? 0.358
                    : isEvolved
                        ? 0.355
                        : 0.350)),
        brow);

    final nose = Paint()..color = dark.withValues(alpha: 0.82);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.50, size.height * 0.418)
        ..lineTo(size.width * 0.472, size.height * 0.445)
        ..lineTo(size.width * 0.528, size.height * 0.445)
        ..close(),
      nose,
    );
    final mouth = Paint()
      ..color = dark.withValues(alpha: 0.70)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.50, size.height * 0.445),
        Offset(size.width * 0.50, size.height * 0.465), mouth);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.50, size.height * 0.465)
        ..quadraticBezierTo(size.width * 0.47, size.height * 0.485,
            size.width * 0.445, size.height * 0.463),
      mouth,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.50, size.height * 0.465)
        ..quadraticBezierTo(size.width * 0.53, size.height * 0.485,
            size.width * 0.555, size.height * 0.463),
      mouth,
    );
  }

  void _drawBunny(
    Canvas canvas,
    Size size,
    Color base,
    Color dark,
    Color light,
    bool blink,
    double earTwitch,
  ) {
    final body = Paint()..color = base;
    final inner = Paint()
      ..color = Color.lerp(light, const Color(0xFFFFC7D8), 0.48)!
          .withValues(alpha: 0.92);
    final maturity = growthStage.index;

    final bodyCenter = Offset(size.width * 0.50, size.height * 0.675);
    final bodyWidth = size.width * (0.42 + maturity * 0.014);
    final bodyHeight = size.height * (0.52 + maturity * 0.018);
    final headCenter = Offset(size.width * 0.50, size.height * 0.365);
    final headWidth = size.width * (0.43 + maturity * 0.006);
    final headHeight = size.height * (0.40 + maturity * 0.005);

    _drawBunnyEar(
      canvas,
      size,
      0.395,
      -0.095 + earTwitch * 0.38,
      body,
      inner,
      maturity,
      headHeight,
    );
    _drawBunnyEar(
      canvas,
      size,
      0.605,
      0.095 - earTwitch * 0.38,
      body,
      inner,
      maturity,
      headHeight,
    );

    if (growthStage.index >= StudyPetGrowthStage.young.index) {
      canvas.drawCircle(
        Offset(size.width * 0.715, size.height * 0.675),
        size.width * (0.054 + maturity * 0.004),
        Paint()..color = light.withValues(alpha: 0.92),
      );
    }

    _drawBunnyBody(canvas, bodyCenter, bodyWidth, bodyHeight, body);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.700),
        width: size.width * (0.175 + maturity * 0.006),
        height: size.height * (0.300 + maturity * 0.008),
      ),
      Paint()..color = light.withValues(alpha: 0.76),
    );
    if (growthStage.index >= StudyPetGrowthStage.evolved.index) {
      _drawBunnyChestFluff(canvas, size, light);
    }

    _drawBunnyPaws(canvas, size, dark, light, maturity);
    _drawBunnyHead(canvas, headCenter, headWidth, headHeight, body);
    _drawBunnyCheekFluff(canvas, size, body, maturity);
    _drawBunnyFace(canvas, size, dark, blink, maturity);

    _drawLeaf(canvas, size, Offset(size.width * 0.350, size.height * 0.585),
        size.width * 0.052, light);
    _drawLeaf(canvas, size, Offset(size.width * 0.650, size.height * 0.585),
        size.width * 0.052, light);
    if (growthStage.index >= StudyPetGrowthStage.young.index) {
      _drawLeaf(canvas, size, Offset(size.width * 0.50, size.height * 0.205),
          size.width * 0.045, const Color(0xFFD9F0AF));
    }
    if (growthStage.index >= StudyPetGrowthStage.evolved.index) {
      _drawFlower(canvas, Offset(size.width * 0.36, size.height * 0.20),
          size.width * 0.034, const Color(0xFFFFD8E2));
      _drawFlower(canvas, Offset(size.width * 0.64, size.height * 0.20),
          size.width * 0.034, const Color(0xFFFFF0A8));
      _drawSpark(canvas, Offset(size.width * 0.73, size.height * 0.42),
          size.width * 0.028, const Color(0xFFE8FFD7));
    }
    if (growthStage.index >= StudyPetGrowthStage.adult.index) {
      _drawSpark(canvas, Offset(size.width * 0.28, size.height * 0.38),
          size.width * 0.032, const Color(0xFFFFF0A8));
    }
  }

  void _drawCat(
    Canvas canvas,
    Size size,
    Color base,
    Color dark,
    Color light,
    bool blink,
    double tailFlick,
    double earTwitch,
  ) {
    final body = Paint()..color = base;
    final maturity = growthStage.index;
    if (growthStage == StudyPetGrowthStage.young) {
      _drawYoungCat(
        canvas,
        size,
        base,
        dark,
        light,
        blink,
        tailFlick,
        earTwitch,
      );
      return;
    }
    if (growthStage == StudyPetGrowthStage.evolved) {
      _drawAstralCat(
        canvas,
        size,
        blink,
        tailFlick,
        earTwitch,
      );
      return;
    }
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.68, size.height * 0.70)
        ..cubicTo(
            size.width * 0.96,
            size.height * 0.48 + tailFlick,
            size.width * 0.93,
            size.height * 0.86,
            size.width * 0.72,
            size.height * 0.77),
      Paint()
        ..color = base.withValues(alpha: 0.96)
        ..strokeWidth = size.width * (0.10 + maturity * 0.014)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.67),
        width: size.width * (0.40 + maturity * 0.018),
        height: size.height * (0.42 + maturity * 0.020),
      ),
      body,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.70),
        width: size.width * 0.19,
        height: size.height * 0.24,
      ),
      Paint()..color = light,
    );
    _drawPaws(canvas, size, dark);
    _drawTriangle(canvas, size, 0.36, 0.28, -earTwitch, base, light);
    _drawTriangle(canvas, size, 0.64, 0.28, earTwitch, base, light);
    canvas.drawCircle(Offset(size.width * 0.50, size.height * 0.39),
        size.width * (0.22 + maturity * 0.006), body);
    _drawFace(canvas, size, dark, blink);
    _drawCrescent(canvas, Offset(size.width * 0.50, size.height * 0.66),
        size.width * 0.060, light);
    if (growthStage.index >= StudyPetGrowthStage.young.index) {
      _drawSpark(canvas, Offset(size.width * 0.62, size.height * 0.55),
          size.width * 0.026, const Color(0xFFFFE78A));
    }
    if (growthStage.index >= StudyPetGrowthStage.evolved.index) {
      _drawSpark(canvas, Offset(size.width * 0.38, size.height * 0.28),
          size.width * 0.032, const Color(0xFFEDEBFF));
    }
    final whisker = Paint()
      ..color = dark.withValues(alpha: 0.42)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.35, size.height * 0.43),
        Offset(size.width * 0.22, size.height * 0.40), whisker);
    canvas.drawLine(Offset(size.width * 0.65, size.height * 0.43),
        Offset(size.width * 0.78, size.height * 0.40), whisker);
  }

  void _drawAstralCat(
    Canvas canvas,
    Size size,
    bool blink,
    double tailFlick,
    double earTwitch,
  ) {
    const fur = Color(0xFF737CCB);
    const furShade = Color(0xFF5962A8);
    const darkMark = Color(0xFF30365F);
    const moon = Color(0xFFECE9FF);
    const starlight = Color(0xFFAEEBFF);
    final body = Paint()..color = fur;
    final chest = Paint()..color = moon.withValues(alpha: 0.88);
    final stripe = Paint()
      ..color = darkMark.withValues(alpha: 0.70)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    _drawAstralCatTail(canvas, size, furShade, darkMark, starlight, tailFlick);
    _drawAstralCatBody(canvas, size, body);
    _drawAstralCatChest(canvas, size, chest);
    _drawAstralCatPaws(canvas, size, darkMark, moon);
    _drawAstralCatEar(
        canvas, size, 0.375, -0.08 - earTwitch * 0.25, fur, darkMark, moon);
    _drawAstralCatEar(
        canvas, size, 0.625, 0.08 + earTwitch * 0.25, fur, darkMark, moon);
    _drawAstralCatHead(canvas, size, body);
    _drawAstralCatStripes(canvas, size, stripe);
    _drawAstralCatFace(canvas, size, darkMark, moon, blink);
    _drawSpark(canvas, Offset(size.width * 0.66, size.height * 0.55),
        size.width * 0.030, starlight);
    _drawSpark(canvas, Offset(size.width * 0.33, size.height * 0.34),
        size.width * 0.022, moon);
  }

  void _drawAstralCatTail(
    Canvas canvas,
    Size size,
    Color fur,
    Color darkMark,
    Color starlight,
    double tailFlick,
  ) {
    final tailPath = Path()
      ..moveTo(size.width * 0.61, size.height * 0.70)
      ..cubicTo(
        size.width * 0.88,
        size.height * 0.51 + tailFlick,
        size.width * 0.86,
        size.height * 0.84,
        size.width * 0.61,
        size.height * 0.78,
      );
    canvas.drawPath(
      tailPath,
      Paint()
        ..color = fur.withValues(alpha: 0.96)
        ..strokeWidth = size.width * 0.095
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    final band = Paint()
      ..color = darkMark.withValues(alpha: 0.62)
      ..strokeWidth = size.width * 0.018
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final point in const [
      Offset(0.74, 0.60),
      Offset(0.80, 0.67),
      Offset(0.76, 0.76),
    ]) {
      canvas.drawLine(
        Offset(size.width * (point.dx - 0.035), size.height * point.dy),
        Offset(
            size.width * (point.dx + 0.035), size.height * (point.dy + 0.04)),
        band,
      );
    }
    canvas.drawCircle(
      Offset(size.width * 0.84, size.height * 0.55 + tailFlick * 0.2),
      size.width * 0.018,
      Paint()..color = starlight.withValues(alpha: 0.70),
    );
  }

  void _drawAstralCatBody(Canvas canvas, Size size, Paint body) {
    final path = Path()
      ..moveTo(size.width * 0.50, size.height * 0.455)
      ..cubicTo(size.width * 0.625, size.height * 0.48, size.width * 0.655,
          size.height * 0.635, size.width * 0.625, size.height * 0.80)
      ..cubicTo(size.width * 0.585, size.height * 0.91, size.width * 0.415,
          size.height * 0.91, size.width * 0.375, size.height * 0.80)
      ..cubicTo(size.width * 0.345, size.height * 0.635, size.width * 0.375,
          size.height * 0.48, size.width * 0.50, size.height * 0.455)
      ..close();
    canvas.drawPath(path, body);
  }

  void _drawAstralCatChest(Canvas canvas, Size size, Paint chest) {
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.50, size.height * 0.505)
        ..cubicTo(size.width * 0.575, size.height * 0.57, size.width * 0.565,
            size.height * 0.72, size.width * 0.52, size.height * 0.81)
        ..lineTo(size.width * 0.50, size.height * 0.845)
        ..lineTo(size.width * 0.48, size.height * 0.81)
        ..cubicTo(size.width * 0.435, size.height * 0.72, size.width * 0.425,
            size.height * 0.57, size.width * 0.50, size.height * 0.505)
        ..close(),
      chest,
    );
  }

  void _drawAstralCatPaws(
      Canvas canvas, Size size, Color darkMark, Color moon) {
    final hind = Paint()..color = darkMark.withValues(alpha: 0.42);
    final front = Paint()..color = moon.withValues(alpha: 0.80);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.405, size.height * 0.835),
        width: size.width * 0.130,
        height: size.height * 0.065,
      ),
      hind,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.595, size.height * 0.835),
        width: size.width * 0.130,
        height: size.height * 0.065,
      ),
      hind,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.435, size.height * 0.700),
        width: size.width * 0.050,
        height: size.height * 0.170,
      ),
      front,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.565, size.height * 0.700),
        width: size.width * 0.050,
        height: size.height * 0.170,
      ),
      front,
    );
  }

  void _drawAstralCatEar(
    Canvas canvas,
    Size size,
    double centerX,
    double rotation,
    Color fur,
    Color darkMark,
    Color moon,
  ) {
    canvas.save();
    canvas.translate(size.width * centerX, size.height * 0.285);
    canvas.rotate(rotation);
    final ear = Path()
      ..moveTo(0, -size.height * 0.185)
      ..lineTo(size.width * 0.080, size.height * 0.052)
      ..quadraticBezierTo(
          0, size.height * 0.092, -size.width * 0.080, size.height * 0.052)
      ..close();
    canvas.drawPath(ear, Paint()..color = fur);
    canvas.drawPath(
      Path()
        ..moveTo(0, -size.height * 0.185)
        ..quadraticBezierTo(size.width * 0.040, -size.height * 0.095,
            size.width * 0.030, -size.height * 0.035)
        ..quadraticBezierTo(
            0, -size.height * 0.060, -size.width * 0.030, -size.height * 0.035)
        ..quadraticBezierTo(
            -size.width * 0.040, -size.height * 0.095, 0, -size.height * 0.185)
        ..close(),
      Paint()..color = darkMark.withValues(alpha: 0.74),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, -size.height * 0.085)
        ..lineTo(size.width * 0.033, size.height * 0.038)
        ..quadraticBezierTo(
            0, size.height * 0.058, -size.width * 0.033, size.height * 0.038)
        ..close(),
      Paint()..color = moon.withValues(alpha: 0.82),
    );
    canvas.restore();
  }

  void _drawAstralCatHead(Canvas canvas, Size size, Paint body) {
    final path = Path()
      ..moveTo(size.width * 0.50, size.height * 0.235)
      ..cubicTo(size.width * 0.635, size.height * 0.245, size.width * 0.675,
          size.height * 0.365, size.width * 0.642, size.height * 0.465)
      ..cubicTo(size.width * 0.60, size.height * 0.555, size.width * 0.40,
          size.height * 0.555, size.width * 0.358, size.height * 0.465)
      ..cubicTo(size.width * 0.325, size.height * 0.365, size.width * 0.365,
          size.height * 0.245, size.width * 0.50, size.height * 0.235)
      ..close();
    canvas.drawPath(path, body);
  }

  void _drawAstralCatStripes(Canvas canvas, Size size, Paint stripe) {
    canvas.drawLine(Offset(size.width * 0.50, size.height * 0.285),
        Offset(size.width * 0.50, size.height * 0.335), stripe);
    canvas.drawLine(Offset(size.width * 0.455, size.height * 0.300),
        Offset(size.width * 0.475, size.height * 0.340), stripe);
    canvas.drawLine(Offset(size.width * 0.545, size.height * 0.300),
        Offset(size.width * 0.525, size.height * 0.340), stripe);
    canvas.drawLine(Offset(size.width * 0.360, size.height * 0.410),
        Offset(size.width * 0.285, size.height * 0.388), stripe);
    canvas.drawLine(Offset(size.width * 0.640, size.height * 0.410),
        Offset(size.width * 0.715, size.height * 0.388), stripe);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.365, size.height * 0.630),
        width: size.width * 0.17,
        height: size.height * 0.16,
      ),
      -0.30,
      0.95,
      false,
      stripe,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.635, size.height * 0.630),
        width: size.width * 0.17,
        height: size.height * 0.16,
      ),
      math.pi + 2.48,
      0.95,
      false,
      stripe,
    );
    _drawCrescent(canvas, Offset(size.width * 0.50, size.height * 0.365),
        size.width * 0.030, const Color(0xFFAEEBFF));
  }

  void _drawAstralCatFace(
    Canvas canvas,
    Size size,
    Color darkMark,
    Color moon,
    bool blink,
  ) {
    final eye = Paint()
      ..color = darkMark
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (blink) {
      canvas.drawLine(Offset(size.width * 0.405, size.height * 0.388),
          Offset(size.width * 0.465, size.height * 0.388), eye);
      canvas.drawLine(Offset(size.width * 0.535, size.height * 0.388),
          Offset(size.width * 0.595, size.height * 0.388), eye);
    } else {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.425, size.height * 0.385),
          width: size.width * 0.050,
          height: size.height * 0.030,
        ),
        eye,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.575, size.height * 0.385),
          width: size.width * 0.050,
          height: size.height * 0.030,
        ),
        eye,
      );
      canvas.drawCircle(Offset(size.width * 0.435, size.height * 0.377),
          size.width * 0.006, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(size.width * 0.585, size.height * 0.377),
          size.width * 0.006, Paint()..color = Colors.white);
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.430),
        width: size.width * 0.033,
        height: size.height * 0.023,
      ),
      eye,
    );
    final mouth = Paint()
      ..color = darkMark
      ..strokeWidth = 1.35
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.50, size.height * 0.443),
        Offset(size.width * 0.50, size.height * 0.462), mouth);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.475, size.height * 0.462),
        width: size.width * 0.046,
        height: size.height * 0.030,
      ),
      0.2,
      1.0,
      false,
      mouth,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.525, size.height * 0.462),
        width: size.width * 0.046,
        height: size.height * 0.030,
      ),
      math.pi - 1.20,
      1.0,
      false,
      mouth,
    );
    final whisker = Paint()
      ..color = darkMark.withValues(alpha: 0.42)
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.39, size.height * 0.440),
        Offset(size.width * 0.26, size.height * 0.415), whisker);
    canvas.drawLine(Offset(size.width * 0.39, size.height * 0.462),
        Offset(size.width * 0.27, size.height * 0.468), whisker);
    canvas.drawLine(Offset(size.width * 0.61, size.height * 0.440),
        Offset(size.width * 0.74, size.height * 0.415), whisker);
    canvas.drawLine(Offset(size.width * 0.61, size.height * 0.462),
        Offset(size.width * 0.73, size.height * 0.468), whisker);
  }

  void _drawYoungCat(
    Canvas canvas,
    Size size,
    Color base,
    Color dark,
    Color light,
    bool blink,
    double tailFlick,
    double earTwitch,
  ) {
    final body = Paint()..color = base;
    final belly = Paint()..color = light.withValues(alpha: 0.82);
    final outline = Paint()
      ..color = dark.withValues(alpha: 0.20)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.62, size.height * 0.70)
        ..cubicTo(
          size.width * 0.83,
          size.height * 0.50 + tailFlick,
          size.width * 0.83,
          size.height * 0.80,
          size.width * 0.60,
          size.height * 0.76,
        ),
      Paint()
        ..color = base.withValues(alpha: 0.94)
        ..strokeWidth = size.width * 0.085
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.68, size.height * 0.56 + tailFlick * 0.3)
        ..quadraticBezierTo(size.width * 0.78, size.height * 0.59,
            size.width * 0.74, size.height * 0.67),
      Paint()
        ..color = light.withValues(alpha: 0.52)
        ..strokeWidth = size.width * 0.030
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    _drawYoungCatBody(canvas, size, body);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.680),
        width: size.width * 0.165,
        height: size.height * 0.290,
      ),
      belly,
    );
    _drawYoungCatPaws(canvas, size, dark, light);
    _drawYoungCatEar(
        canvas, size, 0.375, -0.07 - earTwitch * 0.25, base, light);
    _drawYoungCatEar(canvas, size, 0.625, 0.07 + earTwitch * 0.25, base, light);
    _drawYoungCatHead(canvas, size, body);
    _drawYoungCatFace(canvas, size, dark, light, blink);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.39, size.height * 0.52)
        ..quadraticBezierTo(size.width * 0.50, size.height * 0.57,
            size.width * 0.61, size.height * 0.52),
      outline,
    );
    _drawSpark(canvas, Offset(size.width * 0.63, size.height * 0.55),
        size.width * 0.026, const Color(0xFFFFE78A));
  }

  void _drawYoungCatBody(Canvas canvas, Size size, Paint body) {
    final path = Path()
      ..moveTo(size.width * 0.50, size.height * 0.465)
      ..cubicTo(size.width * 0.625, size.height * 0.49, size.width * 0.665,
          size.height * 0.64, size.width * 0.635, size.height * 0.80)
      ..cubicTo(size.width * 0.595, size.height * 0.92, size.width * 0.405,
          size.height * 0.92, size.width * 0.365, size.height * 0.80)
      ..cubicTo(size.width * 0.335, size.height * 0.64, size.width * 0.375,
          size.height * 0.49, size.width * 0.50, size.height * 0.465)
      ..close();
    canvas.drawPath(path, body);
  }

  void _drawYoungCatHead(Canvas canvas, Size size, Paint body) {
    final path = Path()
      ..moveTo(size.width * 0.50, size.height * 0.245)
      ..cubicTo(size.width * 0.64, size.height * 0.255, size.width * 0.685,
          size.height * 0.375, size.width * 0.650, size.height * 0.470)
      ..cubicTo(size.width * 0.61, size.height * 0.565, size.width * 0.39,
          size.height * 0.565, size.width * 0.350, size.height * 0.470)
      ..cubicTo(size.width * 0.315, size.height * 0.375, size.width * 0.36,
          size.height * 0.255, size.width * 0.50, size.height * 0.245)
      ..close();
    canvas.drawPath(path, body);
  }

  void _drawYoungCatEar(
    Canvas canvas,
    Size size,
    double centerX,
    double rotation,
    Color base,
    Color light,
  ) {
    canvas.save();
    canvas.translate(size.width * centerX, size.height * 0.285);
    canvas.rotate(rotation);
    final ear = Path()
      ..moveTo(0, -size.height * 0.175)
      ..lineTo(size.width * 0.078, size.height * 0.052)
      ..quadraticBezierTo(
          0, size.height * 0.090, -size.width * 0.078, size.height * 0.052)
      ..close();
    canvas.drawPath(ear, Paint()..color = base);
    canvas.drawPath(
      Path()
        ..moveTo(0, -size.height * 0.090)
        ..lineTo(size.width * 0.035, size.height * 0.036)
        ..quadraticBezierTo(
            0, size.height * 0.055, -size.width * 0.035, size.height * 0.036)
        ..close(),
      Paint()..color = light.withValues(alpha: 0.86),
    );
    canvas.restore();
  }

  void _drawYoungCatPaws(Canvas canvas, Size size, Color dark, Color light) {
    final hind = Paint()..color = dark.withValues(alpha: 0.30);
    final front = Paint()..color = light.withValues(alpha: 0.78);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.405, size.height * 0.835),
        width: size.width * 0.135,
        height: size.height * 0.070,
      ),
      hind,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.595, size.height * 0.835),
        width: size.width * 0.135,
        height: size.height * 0.070,
      ),
      hind,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.435, size.height * 0.700),
        width: size.width * 0.048,
        height: size.height * 0.155,
      ),
      front,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.565, size.height * 0.700),
        width: size.width * 0.048,
        height: size.height * 0.155,
      ),
      front,
    );
  }

  void _drawYoungCatFace(
    Canvas canvas,
    Size size,
    Color dark,
    Color light,
    bool blink,
  ) {
    final eye = Paint()
      ..color = dark
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (blink) {
      canvas.drawLine(Offset(size.width * 0.405, size.height * 0.385),
          Offset(size.width * 0.465, size.height * 0.385), eye);
      canvas.drawLine(Offset(size.width * 0.535, size.height * 0.385),
          Offset(size.width * 0.595, size.height * 0.385), eye);
    } else {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.425, size.height * 0.382),
          width: size.width * 0.034,
          height: size.height * 0.045,
        ),
        eye,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.575, size.height * 0.382),
          width: size.width * 0.034,
          height: size.height * 0.045,
        ),
        eye,
      );
      canvas.drawCircle(Offset(size.width * 0.433, size.height * 0.372),
          size.width * 0.007, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(size.width * 0.583, size.height * 0.372),
          size.width * 0.007, Paint()..color = Colors.white);
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.435),
        width: size.width * 0.030,
        height: size.height * 0.022,
      ),
      eye,
    );
    final mouth = Paint()
      ..color = dark
      ..strokeWidth = 1.35
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.50, size.height * 0.447),
        Offset(size.width * 0.50, size.height * 0.465), mouth);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.475, size.height * 0.465),
        width: size.width * 0.050,
        height: size.height * 0.034,
      ),
      0.2,
      1.05,
      false,
      mouth,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.525, size.height * 0.465),
        width: size.width * 0.050,
        height: size.height * 0.034,
      ),
      math.pi - 1.25,
      1.05,
      false,
      mouth,
    );
    final cheek = Paint()
      ..color = const Color(0xFFFFC7D8).withValues(alpha: 0.32);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.385, size.height * 0.435),
        width: size.width * 0.045,
        height: size.height * 0.020,
      ),
      cheek,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.615, size.height * 0.435),
        width: size.width * 0.045,
        height: size.height * 0.020,
      ),
      cheek,
    );

    final whisker = Paint()
      ..color = dark.withValues(alpha: 0.38)
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.39, size.height * 0.435),
        Offset(size.width * 0.26, size.height * 0.41), whisker);
    canvas.drawLine(Offset(size.width * 0.39, size.height * 0.458),
        Offset(size.width * 0.27, size.height * 0.465), whisker);
    canvas.drawLine(Offset(size.width * 0.61, size.height * 0.435),
        Offset(size.width * 0.74, size.height * 0.41), whisker);
    canvas.drawLine(Offset(size.width * 0.61, size.height * 0.458),
        Offset(size.width * 0.73, size.height * 0.465), whisker);
  }

  void _drawTriangle(
    Canvas canvas,
    Size size,
    double centerX,
    double topY,
    double rotation,
    Color base,
    Color light,
  ) {
    final path = Path()
      ..moveTo(size.width * centerX, size.height * (topY - 0.16))
      ..lineTo(size.width * (centerX - 0.12), size.height * (topY + 0.09))
      ..lineTo(size.width * (centerX + 0.12), size.height * (topY + 0.09))
      ..close();
    canvas.save();
    canvas.translate(size.width * centerX, size.height * topY);
    canvas.rotate(rotation);
    canvas.translate(-size.width * centerX, -size.height * topY);
    canvas.drawPath(path, Paint()..color = base);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * centerX, size.height * (topY - 0.08))
        ..lineTo(size.width * (centerX - 0.055), size.height * (topY + 0.06))
        ..lineTo(size.width * (centerX + 0.055), size.height * (topY + 0.06))
        ..close(),
      Paint()..color = light.withValues(alpha: 0.82),
    );
    canvas.restore();
  }

  void _drawBunnyEar(
    Canvas canvas,
    Size size,
    double centerX,
    double rotation,
    Paint body,
    Paint inner,
    int maturity,
    double headHeight,
  ) {
    final earHeight = headHeight * (0.78 + maturity * 0.018);
    final earWidth = size.width * (0.118 + maturity * 0.003);
    final tipWidth = earWidth * 0.62;
    final innerHeight = earHeight * 0.70;
    final innerWidth = earWidth * 0.46;
    final baseY = size.height * 0.016;
    final topY = baseY - earHeight;
    canvas.save();
    canvas.translate(size.width * centerX, size.height * 0.265);
    canvas.rotate(rotation);
    canvas.drawPath(
      Path()
        ..moveTo(-tipWidth / 2, topY + size.height * 0.018)
        ..quadraticBezierTo(0, topY - size.height * 0.010, tipWidth / 2,
            topY + size.height * 0.018)
        ..cubicTo(earWidth * 0.54, topY + earHeight * 0.38, earWidth * 0.50,
            baseY - size.height * 0.020, earWidth * 0.36, baseY)
        ..quadraticBezierTo(
            0, baseY + size.height * 0.028, -earWidth * 0.36, baseY)
        ..cubicTo(
            -earWidth * 0.50,
            baseY - size.height * 0.020,
            -earWidth * 0.54,
            topY + earHeight * 0.38,
            -tipWidth / 2,
            topY + size.height * 0.018)
        ..close(),
      body,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-innerWidth / 2, baseY - innerHeight * 0.92)
        ..quadraticBezierTo(0, baseY - innerHeight - size.height * 0.010,
            innerWidth / 2, baseY - innerHeight * 0.92)
        ..cubicTo(
            innerWidth * 0.64,
            baseY - innerHeight * 0.58,
            innerWidth * 0.52,
            baseY - innerHeight * 0.12,
            innerWidth * 0.30,
            baseY - size.height * 0.040)
        ..quadraticBezierTo(0, baseY - size.height * 0.012, -innerWidth * 0.30,
            baseY - size.height * 0.040)
        ..cubicTo(
            -innerWidth * 0.52,
            baseY - innerHeight * 0.12,
            -innerWidth * 0.64,
            baseY - innerHeight * 0.58,
            -innerWidth / 2,
            baseY - innerHeight * 0.92)
        ..close(),
      inner,
    );
    canvas.restore();
  }

  void _drawSpark(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    final path = Path();
    for (var index = 0; index < 8; index += 1) {
      final angle = (-math.pi / 2) + (math.pi * 2 * index / 8);
      final distance = index.isEven ? radius : radius * 0.42;
      final point = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.92));
  }

  void _drawLeaf(
      Canvas canvas, Size size, Offset center, double radius, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(center.dx + radius, center.dy,
          center.dx + radius * 0.10, center.dy + radius)
      ..quadraticBezierTo(
          center.dx - radius, center.dy, center.dx, center.dy - radius)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.70));
  }

  void _drawFlower(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()..color = color.withValues(alpha: 0.82);
    for (var i = 0; i < 5; i += 1) {
      final angle = i * math.pi * 2 / 5;
      canvas.drawCircle(
        Offset(
          center.dx + math.cos(angle) * radius * 0.72,
          center.dy + math.sin(angle) * radius * 0.72,
        ),
        radius * 0.42,
        paint,
      );
    }
    canvas.drawCircle(
        center, radius * 0.28, Paint()..color = const Color(0xFFE4C070));
  }

  void _drawCrescent(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()..color = color.withValues(alpha: 0.78);
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(
      Offset(center.dx + radius * 0.42, center.dy - radius * 0.10),
      radius * 0.88,
      Paint()..color = Color.lerp(color, Colors.white, 0.35)!,
    );
  }

  void _drawPaws(Canvas canvas, Size size, Color dark) {
    final paw = Paint()..color = dark.withValues(alpha: 0.42);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.39, size.height * 0.84),
        width: size.width * 0.12,
        height: size.height * 0.07,
      ),
      paw,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.61, size.height * 0.84),
        width: size.width * 0.12,
        height: size.height * 0.07,
      ),
      paw,
    );
  }

  void _drawBunnyBody(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Paint body,
  ) {
    final path = Path()
      ..moveTo(center.dx, center.dy - height * 0.50)
      ..cubicTo(
          center.dx + width * 0.36,
          center.dy - height * 0.48,
          center.dx + width * 0.49,
          center.dy - height * 0.06,
          center.dx + width * 0.46,
          center.dy + height * 0.25)
      ..cubicTo(
          center.dx + width * 0.40,
          center.dy + height * 0.53,
          center.dx - width * 0.40,
          center.dy + height * 0.53,
          center.dx - width * 0.46,
          center.dy + height * 0.25)
      ..cubicTo(
          center.dx - width * 0.49,
          center.dy - height * 0.06,
          center.dx - width * 0.36,
          center.dy - height * 0.48,
          center.dx,
          center.dy - height * 0.50)
      ..close();
    canvas.drawPath(path, body);
  }

  void _drawBunnyHead(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Paint body,
  ) {
    final path = Path()
      ..moveTo(center.dx, center.dy - height * 0.50)
      ..cubicTo(
          center.dx + width * 0.36,
          center.dy - height * 0.48,
          center.dx + width * 0.49,
          center.dy - height * 0.16,
          center.dx + width * 0.48,
          center.dy + height * 0.08)
      ..cubicTo(
          center.dx + width * 0.53,
          center.dy + height * 0.42,
          center.dx + width * 0.28,
          center.dy + height * 0.52,
          center.dx,
          center.dy + height * 0.50)
      ..cubicTo(
          center.dx - width * 0.28,
          center.dy + height * 0.52,
          center.dx - width * 0.53,
          center.dy + height * 0.42,
          center.dx - width * 0.48,
          center.dy + height * 0.08)
      ..cubicTo(
          center.dx - width * 0.49,
          center.dy - height * 0.16,
          center.dx - width * 0.36,
          center.dy - height * 0.48,
          center.dx,
          center.dy - height * 0.50)
      ..close();
    canvas.drawPath(path, body);
  }

  void _drawBunnyPaws(
    Canvas canvas,
    Size size,
    Color dark,
    Color light,
    int maturity,
  ) {
    final paw = Paint()..color = dark.withValues(alpha: 0.38);
    final forePaw = Paint()..color = light.withValues(alpha: 0.90);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.405, size.height * 0.675),
        width: size.width * 0.070,
        height: size.height * 0.150,
      ),
      forePaw,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.595, size.height * 0.675),
        width: size.width * 0.070,
        height: size.height * 0.150,
      ),
      forePaw,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.365, size.height * 0.845),
        width: size.width * (0.170 + maturity * 0.008),
        height: size.height * 0.088,
      ),
      paw,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.635, size.height * 0.845),
        width: size.width * (0.170 + maturity * 0.008),
        height: size.height * 0.088,
      ),
      paw,
    );
  }

  void _drawBunnyChestFluff(Canvas canvas, Size size, Color light) {
    final fluff = Paint()..color = light.withValues(alpha: 0.76);
    final path = Path()
      ..moveTo(size.width * 0.43, size.height * 0.59)
      ..quadraticBezierTo(size.width * 0.47, size.height * 0.64,
          size.width * 0.50, size.height * 0.60)
      ..quadraticBezierTo(size.width * 0.53, size.height * 0.64,
          size.width * 0.57, size.height * 0.59)
      ..quadraticBezierTo(size.width * 0.55, size.height * 0.70,
          size.width * 0.50, size.height * 0.73)
      ..quadraticBezierTo(size.width * 0.45, size.height * 0.70,
          size.width * 0.43, size.height * 0.59)
      ..close();
    canvas.drawPath(path, fluff);
  }

  void _drawBunnyCheekFluff(
    Canvas canvas,
    Size size,
    Paint body,
    int maturity,
  ) {
    if (maturity < StudyPetGrowthStage.young.index) return;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.335, size.height * 0.435),
        width: size.width * 0.060,
        height: size.height * 0.045,
      ),
      body,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.665, size.height * 0.435),
        width: size.width * 0.060,
        height: size.height * 0.045,
      ),
      body,
    );
  }

  void _drawBunnyFace(
    Canvas canvas,
    Size size,
    Color dark,
    bool blink,
    int maturity,
  ) {
    final eye = Paint()
      ..color = dark
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final eyeY = size.height * (maturity == 0 ? 0.375 : 0.365);
    if (blink) {
      canvas.drawLine(Offset(size.width * 0.405, eyeY),
          Offset(size.width * 0.460, eyeY), eye);
      canvas.drawLine(Offset(size.width * 0.540, eyeY),
          Offset(size.width * 0.595, eyeY), eye);
    } else {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.43, eyeY),
          width: size.width * 0.030,
          height: size.height * 0.040,
        ),
        eye,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.57, eyeY),
          width: size.width * 0.030,
          height: size.height * 0.040,
        ),
        eye,
      );
    }

    final cheek = Paint()
      ..color = const Color(0xFFFFC7D8).withValues(alpha: 0.35);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.415, size.height * 0.425),
        width: size.width * 0.044,
        height: size.height * 0.022,
      ),
      cheek,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.585, size.height * 0.425),
        width: size.width * 0.044,
        height: size.height * 0.022,
      ),
      cheek,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.410),
        width: size.width * 0.032,
        height: size.height * 0.024,
      ),
      Paint()..color = dark,
    );

    final mouth = Paint()
      ..color = dark
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.50, size.height * 0.43),
        Offset(size.width * 0.50, size.height * 0.455), mouth);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.475, size.height * 0.455),
        width: size.width * 0.052,
        height: size.height * 0.034,
      ),
      0.15,
      1.05,
      false,
      mouth,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.525, size.height * 0.455),
        width: size.width * 0.052,
        height: size.height * 0.034,
      ),
      math.pi - 1.20,
      1.05,
      false,
      mouth,
    );
  }

  void _drawFace(Canvas canvas, Size size, Color dark, bool blink) {
    final eye = Paint()
      ..color = dark
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (blink) {
      canvas.drawLine(Offset(size.width * 0.42, size.height * 0.37),
          Offset(size.width * 0.47, size.height * 0.37), eye);
      canvas.drawLine(Offset(size.width * 0.53, size.height * 0.37),
          Offset(size.width * 0.58, size.height * 0.37), eye);
    } else {
      canvas.drawCircle(Offset(size.width * 0.44, size.height * 0.37),
          size.width * 0.018, eye);
      canvas.drawCircle(Offset(size.width * 0.56, size.height * 0.37),
          size.width * 0.018, eye);
    }
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.43),
      size.width * 0.018,
      eye,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.48, size.height * 0.45),
        width: size.width * 0.07,
        height: size.height * 0.05,
      ),
      0.1,
      1.2,
      false,
      Paint()
        ..color = dark
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.52, size.height * 0.45),
        width: size.width * 0.07,
        height: size.height * 0.05,
      ),
      math.pi - 1.3,
      1.2,
      false,
      Paint()
        ..color = dark
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_StudyPetPainter oldDelegate) {
    return oldDelegate.pet != pet ||
        oldDelegate.growthStage != growthStage ||
        oldDelegate.idleValue != idleValue ||
        oldDelegate.outline != outline;
  }
}
