import 'package:flutter/material.dart';

import '../models/pet_cosmetic.dart';
import '../models/study_pet.dart';

class PetCosmeticOverlay extends StatelessWidget {
  const PetCosmeticOverlay({
    required this.pet,
    required this.growthStage,
    required this.equippedCosmetics,
    required this.child,
    required this.size,
    this.previewContext = PetCosmeticPreviewContext.heroPreview,
    super.key,
  });

  final StudyPetDefinition pet;
  final StudyPetGrowthStage growthStage;
  final Map<String, String?> equippedCosmetics;
  final Widget child;
  final double size;
  final PetCosmeticPreviewContext previewContext;

  @override
  Widget build(BuildContext context) {
    final head = petCosmeticById(equippedCosmetics['head']);
    final face = petCosmeticById(equippedCosmetics['face']);
    final neck = petCosmeticById(equippedCosmetics['neck']);
    final anchors = PetCosmeticAnchors.forPet(
      pet.id,
      growthStage,
      previewContext,
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          child,
          if (neck != null)
            _PlacedCosmetic(
              anchor: anchors.anchorFor(neck),
              size: size,
              child: _CosmeticArt(cosmetic: neck),
            ),
          if (face != null)
            _PlacedCosmetic(
              anchor: anchors.anchorFor(face),
              size: size,
              child: _CosmeticArt(cosmetic: face),
            ),
          if (head != null)
            _PlacedCosmetic(
              anchor: anchors.anchorFor(head),
              size: size,
              child: _CosmeticArt(cosmetic: head),
            ),
        ],
      ),
    );
  }
}

enum PetCosmeticPreviewContext {
  shopPreview,
  heroPreview,
}

class PetCosmeticAnchors {
  const PetCosmeticAnchors({
    required this.petId,
    required this.growthStage,
    required this.previewContext,
  });

  final StudyPetId petId;
  final StudyPetGrowthStage growthStage;
  final PetCosmeticPreviewContext previewContext;

  static PetCosmeticAnchors forPet(
    StudyPetId petId,
    StudyPetGrowthStage growthStage,
    PetCosmeticPreviewContext previewContext,
  ) {
    return PetCosmeticAnchors(
      petId: petId,
      growthStage: growthStage,
      previewContext: previewContext,
    );
  }

  CosmeticAnchor anchorFor(PetCosmeticDefinition cosmetic) {
    final anchor = switch (petId) {
      StudyPetId.fox => _foxAnchor(cosmetic),
      StudyPetId.bunny => _bunnyAnchor(cosmetic),
      StudyPetId.cat => _catAnchor(cosmetic),
    };
    return previewContext == PetCosmeticPreviewContext.shopPreview
        ? anchor.shopAdjusted
        : anchor;
  }

  CosmeticAnchor _foxAnchor(PetCosmeticDefinition cosmetic) {
    final stageShift = switch (growthStage) {
      StudyPetGrowthStage.hatchling => -0.015,
      StudyPetGrowthStage.young => 0,
      StudyPetGrowthStage.evolved => -0.010,
      StudyPetGrowthStage.adult => -0.016,
    };
    return switch (cosmetic.id) {
      'round_glasses' => CosmeticAnchor(
          dx: 0.505,
          dy: 0.415 + stageShift,
          scale: 0.170,
        ),
      'study_headphones' => CosmeticAnchor(
          dx: 0.50,
          dy: 0.305 + stageShift,
          scale: 0.455,
        ),
      'leaf_bow' => CosmeticAnchor(
          dx: 0.395,
          dy: 0.245 + stageShift,
          scale: 0.205,
          rotation: -0.18,
        ),
      'star_scarf' => CosmeticAnchor(
          dx: 0.50,
          dy: 0.595 + stageShift,
          scale: 0.250,
        ),
      'wizard_hat' => CosmeticAnchor(
          dx: 0.50,
          dy: 0.205 + stageShift,
          scale: 0.285,
          rotation: -0.04,
        ),
      'graduation_cap' => CosmeticAnchor(
          dx: 0.505,
          dy: 0.255 + stageShift,
          scale: 0.305,
        ),
      _ => _slotFallback(cosmetic.slot),
    };
  }

  CosmeticAnchor _bunnyAnchor(PetCosmeticDefinition cosmetic) {
    final maturityLift = growthStage.index * 0.010;
    return switch (cosmetic.id) {
      'round_glasses' => CosmeticAnchor(
          dx: 0.50,
          dy: 0.405 - maturityLift * 0.35,
          scale: 0.182,
        ),
      'study_headphones' => CosmeticAnchor(
          dx: 0.50,
          dy: 0.325 - maturityLift,
          scale: 0.410,
        ),
      'leaf_bow' => CosmeticAnchor(
          dx: 0.405,
          dy: 0.270 - maturityLift,
          scale: 0.215,
          rotation: -0.15,
        ),
      'star_scarf' => CosmeticAnchor(
          dx: 0.50,
          dy: 0.605,
          scale: 0.250,
        ),
      'wizard_hat' => CosmeticAnchor(
          dx: 0.50,
          dy: 0.235 - maturityLift,
          scale: 0.285,
          rotation: -0.03,
        ),
      'graduation_cap' => CosmeticAnchor(
          dx: 0.50,
          dy: 0.285 - maturityLift,
          scale: 0.300,
        ),
      _ => _slotFallback(cosmetic.slot),
    };
  }

  CosmeticAnchor _catAnchor(PetCosmeticDefinition cosmetic) {
    final stageShift = switch (growthStage) {
      StudyPetGrowthStage.hatchling => -0.005,
      StudyPetGrowthStage.young => 0,
      StudyPetGrowthStage.evolved => -0.008,
      StudyPetGrowthStage.adult => -0.012,
    };
    return switch (cosmetic.id) {
      'round_glasses' => CosmeticAnchor(
          dx: 0.50,
          dy: 0.425 + stageShift,
          scale: 0.190,
        ),
      'study_headphones' => CosmeticAnchor(
          dx: 0.50,
          dy: 0.320 + stageShift,
          scale: 0.415,
        ),
      'leaf_bow' => CosmeticAnchor(
          dx: 0.390,
          dy: 0.265 + stageShift,
          scale: 0.205,
          rotation: -0.18,
        ),
      'star_scarf' => CosmeticAnchor(
          dx: 0.50,
          dy: 0.585 + stageShift,
          scale: 0.248,
        ),
      'wizard_hat' => CosmeticAnchor(
          dx: 0.50,
          dy: 0.225 + stageShift,
          scale: 0.280,
          rotation: -0.04,
        ),
      'graduation_cap' => CosmeticAnchor(
          dx: 0.50,
          dy: 0.275 + stageShift,
          scale: 0.305,
        ),
      _ => _slotFallback(cosmetic.slot),
    };
  }

  CosmeticAnchor _slotFallback(PetCosmeticSlot slot) {
    return switch (slot) {
      PetCosmeticSlot.head =>
        const CosmeticAnchor(dx: 0.50, dy: 0.26, scale: 0.300),
      PetCosmeticSlot.face =>
        const CosmeticAnchor(dx: 0.50, dy: 0.415, scale: 0.185),
      PetCosmeticSlot.neck =>
        const CosmeticAnchor(dx: 0.50, dy: 0.590, scale: 0.250),
    };
  }
}

class CosmeticAnchor {
  const CosmeticAnchor({
    required this.dx,
    required this.dy,
    required this.scale,
    this.rotation = 0,
  });

  final double dx;
  final double dy;
  final double scale;
  final double rotation;

  CosmeticAnchor get shopAdjusted {
    return CosmeticAnchor(
      dx: dx,
      dy: dy + 0.004,
      scale: scale * 1.06,
      rotation: rotation,
    );
  }
}

class _PlacedCosmetic extends StatelessWidget {
  const _PlacedCosmetic({
    required this.anchor,
    required this.size,
    required this.child,
  });

  final CosmeticAnchor anchor;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cosmeticSize = size * anchor.scale;
    return Positioned(
      left: size * anchor.dx - cosmeticSize / 2,
      top: size * anchor.dy - cosmeticSize / 2,
      width: cosmeticSize,
      height: cosmeticSize,
      child: Transform.rotate(angle: anchor.rotation, child: child),
    );
  }
}

class _CosmeticArt extends StatelessWidget {
  const _CosmeticArt({
    required this.cosmetic,
  });

  final PetCosmeticDefinition cosmetic;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CosmeticPainter(cosmetic));
  }
}

class _CosmeticPainter extends CustomPainter {
  const _CosmeticPainter(this.cosmetic);

  final PetCosmeticDefinition cosmetic;

  @override
  void paint(Canvas canvas, Size size) {
    switch (cosmetic.id) {
      case 'leaf_bow':
        _bow(canvas, size);
      case 'round_glasses':
        _glasses(canvas, size);
      case 'star_scarf':
        _scarf(canvas, size);
      case 'study_headphones':
        _headphones(canvas, size);
      case 'wizard_hat':
        _wizardHat(canvas, size);
      case 'graduation_cap':
        _graduationCap(canvas, size);
    }
  }

  void _bow(Canvas canvas, Size size) {
    final green = Paint()..color = const Color(0xFF74B77B);
    final knot = Paint()..color = const Color(0xFF4F8F58);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.48, size.height * 0.50)
        ..quadraticBezierTo(size.width * 0.12, size.height * 0.18,
            size.width * 0.12, size.height * 0.70)
        ..quadraticBezierTo(size.width * 0.34, size.height * 0.64,
            size.width * 0.48, size.height * 0.50)
        ..close(),
      green,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.52, size.height * 0.50)
        ..quadraticBezierTo(size.width * 0.88, size.height * 0.18,
            size.width * 0.88, size.height * 0.70)
        ..quadraticBezierTo(size.width * 0.66, size.height * 0.64,
            size.width * 0.52, size.height * 0.50)
        ..close(),
      green,
    );
    canvas.drawCircle(
        Offset(size.width * 0.50, size.height * 0.50), size.width * 0.12, knot);
  }

  void _glasses(Canvas canvas, Size size) {
    final frame = Paint()
      ..color = const Color(0xFF4A5B58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawCircle(Offset(size.width * 0.34, size.height * 0.50),
        size.width * 0.18, frame);
    canvas.drawCircle(Offset(size.width * 0.66, size.height * 0.50),
        size.width * 0.18, frame);
    canvas.drawLine(Offset(size.width * 0.48, size.height * 0.50),
        Offset(size.width * 0.52, size.height * 0.50), frame);
  }

  void _scarf(Canvas canvas, Size size) {
    final scarf = Paint()..color = const Color(0xFF8067C7);
    final gold = Paint()..color = const Color(0xFFFFD76A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.16,
          size.height * 0.38,
          size.width * 0.68,
          size.height * 0.18,
        ),
        Radius.circular(size.width * 0.12),
      ),
      scarf,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.58, size.height * 0.52)
        ..lineTo(size.width * 0.78, size.height * 0.84)
        ..lineTo(size.width * 0.62, size.height * 0.88)
        ..lineTo(size.width * 0.50, size.height * 0.55)
        ..close(),
      scarf,
    );
    canvas.drawCircle(Offset(size.width * 0.44, size.height * 0.47),
        size.width * 0.035, gold);
  }

  void _headphones(Canvas canvas, Size size) {
    final band = Paint()
      ..color = const Color(0xFF3E5F8A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final pad = Paint()..color = const Color(0xFF8DBBE8);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.50, size.height * 0.52),
        width: size.width * 0.74,
        height: size.height * 0.74,
      ),
      3.35,
      3.05,
      false,
      band,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.16, size.height * 0.48, size.width * 0.15,
            size.height * 0.28),
        Radius.circular(size.width * 0.06),
      ),
      pad,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.69, size.height * 0.48, size.width * 0.15,
            size.height * 0.28),
        Radius.circular(size.width * 0.06),
      ),
      pad,
    );
  }

  void _wizardHat(Canvas canvas, Size size) {
    final hat = Paint()..color = const Color(0xFF4E3C85);
    final band = Paint()..color = const Color(0xFFFFD76A);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.50, size.height * 0.06)
        ..lineTo(size.width * 0.27, size.height * 0.72)
        ..lineTo(size.width * 0.72, size.height * 0.72)
        ..close(),
      hat,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            size.width * 0.18, size.height * 0.66, size.width * 0.64, 5),
        const Radius.circular(99),
      ),
      band,
    );
  }

  void _graduationCap(Canvas canvas, Size size) {
    final cap = Paint()..color = const Color(0xFF263248);
    final tassel = Paint()
      ..color = const Color(0xFFFFC15A)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.50, size.height * 0.20)
        ..lineTo(size.width * 0.92, size.height * 0.42)
        ..lineTo(size.width * 0.50, size.height * 0.64)
        ..lineTo(size.width * 0.08, size.height * 0.42)
        ..close(),
      cap,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.30, size.height * 0.53, size.width * 0.40,
            size.height * 0.18),
        Radius.circular(size.width * 0.04),
      ),
      cap,
    );
    canvas.drawLine(Offset(size.width * 0.68, size.height * 0.44),
        Offset(size.width * 0.82, size.height * 0.72), tassel);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.72),
        size.width * 0.035, Paint()..color = const Color(0xFFFFC15A));
  }

  @override
  bool shouldRepaint(_CosmeticPainter oldDelegate) {
    return oldDelegate.cosmetic != cosmetic;
  }
}
