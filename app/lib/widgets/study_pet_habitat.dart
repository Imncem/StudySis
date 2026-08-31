import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/study_pet.dart';
import '../theme/app_theme.dart';
import 'pet_cosmetic_overlay.dart';
import 'study_pet_visuals.dart';

class StudyPetHabitatView extends StatelessWidget {
  const StudyPetHabitatView({
    required this.habitat,
    required this.pet,
    required this.petName,
    required this.growthStage,
    required this.idleValue,
    this.equippedCosmetics = const {},
    this.compact = false,
    super.key,
  });

  final StudyPetHabitat habitat;
  final StudyPetDefinition pet;
  final String petName;
  final StudyPetGrowthStage growthStage;
  final double idleValue;
  final Map<String, String?> equippedCosmetics;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final height = compact ? 120.0 : width.clamp(360.0, 460.0);
    final basePetSize = compact ? 42.0 : width.clamp(118.0, 158.0);
    final petSize = !compact && pet.id == StudyPetId.bunny
        ? basePetSize * 1.18
        : basePetSize;
    final petAspectScale = compact
        ? const Size(1, 1)
        : switch (pet.id) {
            StudyPetId.fox => const Size(0.84, 1.08),
            StudyPetId.bunny => const Size(0.92, 1.04),
            StudyPetId.cat => const Size(0.90, 1.04),
          };
    final bob = reducedMotion ? 0.0 : math.sin(idleValue * math.pi * 2) * 6;
    final breathe =
        reducedMotion ? 1.0 : 1.0 + math.sin(idleValue * math.pi * 2) * 0.015;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '$petName habitat, ${habitat.displayName}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 18 : 30),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            border: Border.all(
              color: Color(pet.primaryColor).withValues(alpha: 0.12),
            ),
            boxShadow: compact
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: StudySisColors.isDark(context) ? 0.24 : 0.10,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  painter: StudyPetHabitatPainter(
                    habitat: habitat,
                    isDark: StudySisColors.isDark(context),
                    ambienceValue: reducedMotion ? 0.0 : idleValue,
                  ),
                ),
              ),
              if (!compact)
                Positioned(
                  top: 22,
                  left: 18,
                  right: 18,
                  child: Column(
                    children: [
                      Text(
                        petName,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          shadows: const [
                            Shadow(
                              color: Color(0x66000000),
                              offset: Offset(0, 1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Your fantasy study companion is growing with you.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.94),
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(
                              color: Color(0x66000000),
                              offset: Offset(0, 1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: compact ? 24 : 44,
                child: Transform.translate(
                  offset: Offset(0, bob),
                  child: Transform.scale(
                    scaleX: petAspectScale.width * breathe,
                    scaleY: petAspectScale.height * breathe,
                    child: PetCosmeticOverlay(
                      pet: pet,
                      growthStage: growthStage,
                      equippedCosmetics: equippedCosmetics,
                      size: petSize,
                      child: StudyPetCompanionVisual(
                        pet: pet,
                        growthStage: growthStage,
                        size: petSize,
                        idleValue: idleValue,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: compact ? 22 : 80,
                right: compact ? 22 : 80,
                bottom: compact ? 21 : 42,
                child: Container(
                  height: compact ? 8 : 16,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(
                      alpha: StudySisColors.isDark(context) ? 0.26 : 0.16,
                    ),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              if (!compact)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.76),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        '${habitat.displayName}  �  ${growthStage.displayName}',
                        style: TextStyle(
                          color: Color.lerp(
                            Color(pet.primaryColor),
                            Colors.black,
                            0.28,
                          ),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class StudyPetHabitatSelector extends StatelessWidget {
  const StudyPetHabitatSelector({
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    super.key,
  });

  final StudyPetHabitat selected;
  final ValueChanged<StudyPetHabitat> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose your habitat',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: StudyPetHabitat.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final habitat = StudyPetHabitat.values[index];
              return _HabitatOptionCard(
                habitat: habitat,
                selected: selected == habitat,
                enabled: enabled,
                onTap: () => onSelected(habitat),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HabitatOptionCard extends StatelessWidget {
  const _HabitatOptionCard({
    required this.habitat,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final StudyPetHabitat habitat;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = StudySisColors.studyPetAccent(context);
    return SizedBox(
      width: 126,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? accent : Colors.transparent,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CustomPaint(
                      painter: StudyPetHabitatPainter(
                        habitat: habitat,
                        isDark: StudySisColors.isDark(context),
                        ambienceValue: 0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        habitat.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 18,
                      color:
                          selected ? accent : Theme.of(context).disabledColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StudyPetHabitatPainter extends CustomPainter {
  const StudyPetHabitatPainter({
    required this.habitat,
    required this.isDark,
    required this.ambienceValue,
  });

  final StudyPetHabitat habitat;
  final bool isDark;
  final double ambienceValue;

  @override
  void paint(Canvas canvas, Size size) {
    switch (habitat) {
      case StudyPetHabitat.forest:
        _drawForest(canvas, size);
      case StudyPetHabitat.farm:
        _drawFarm(canvas, size);
      case StudyPetHabitat.house:
        _drawHouse(canvas, size);
      case StudyPetHabitat.garden:
        _drawGarden(canvas, size);
    }
  }

  void _drawForest(Canvas canvas, Size size) {
    _background(canvas, size,
        isDark ? const Color(0xFF263548) : const Color(0xFFAEDBCD));
    final distant = Paint()
      ..color = isDark ? const Color(0xFF365142) : const Color(0xFF76A984);
    for (var i = 0; i < 7; i++) {
      final x = size.width * (i / 6);
      _tree(canvas, Offset(x, size.height * 0.42), size.width * 0.11, distant);
    }
    final mid = Paint()
      ..color = isDark ? const Color(0xFF47705B) : const Color(0xFF3F8A65);
    _tree(canvas, Offset(size.width * 0.13, size.height * 0.55),
        size.width * 0.17, mid);
    _tree(canvas, Offset(size.width * 0.82, size.height * 0.56),
        size.width * 0.18, mid);
    _ground(canvas, size,
        isDark ? const Color(0xFF395C43) : const Color(0xFF87B96E));
    _blocks(canvas, size, const [
      (0.12, 0.82, 0.07, 0.05, Color(0xFFFFD8E2)),
      (0.22, 0.76, 0.08, 0.06, Color(0xFFE4C070)),
      (0.72, 0.78, 0.10, 0.07, Color(0xFF537A4F)),
      (0.83, 0.81, 0.06, 0.05, Color(0xFFFFF0A8)),
    ]);
    _sparkle(canvas, size, 0.35, 0.36);
    _sparkle(canvas, size, 0.68, 0.30);
  }

  void _drawFarm(Canvas canvas, Size size) {
    _background(canvas, size,
        isDark ? const Color(0xFF4A445B) : const Color(0xFFFFDCA8));
    _hill(canvas, size, 0.0, 0.58,
        isDark ? const Color(0xFF586842) : const Color(0xFF98C56C));
    _hill(canvas, size, 0.35, 0.54,
        isDark ? const Color(0xFF6C7448) : const Color(0xFFB0D77A));
    final barn = Paint()
      ..color = isDark ? const Color(0xFF8E5A4F) : const Color(0xFFC96E5D);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.12, size.height * 0.45, size.width * 0.18,
            size.height * 0.14),
        barn);
    canvas.drawPath(
        Path()
          ..moveTo(size.width * 0.10, size.height * 0.45)
          ..lineTo(size.width * 0.21, size.height * 0.34)
          ..lineTo(size.width * 0.32, size.height * 0.45)
          ..close(),
        Paint()..color = const Color(0xFF7E473B));
    _fence(canvas, size, 0.48);
    _ground(canvas, size,
        isDark ? const Color(0xFF596D42) : const Color(0xFF8CC36C));
    _blocks(canvas, size, const [
      (0.66, 0.78, 0.11, 0.05, Color(0xFFD9A441)),
      (0.78, 0.78, 0.05, 0.09, Color(0xFF6EA24E)),
      (0.86, 0.78, 0.05, 0.09, Color(0xFF6EA24E)),
    ]);
  }

  void _drawHouse(Canvas canvas, Size size) {
    _background(canvas, size,
        isDark ? const Color(0xFF403549) : const Color(0xFFFFDCC9));
    canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.66, size.width, size.height * 0.34),
        Paint()
          ..color = isDark ? const Color(0xFF6B4B3F) : const Color(0xFFC9875D));
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.10, size.height * 0.24, size.width * 0.20,
            size.height * 0.18),
        Paint()
          ..color = isDark ? const Color(0xFF8CB2CC) : const Color(0xFFBDE7F7));
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.62, size.height * 0.26, size.width * 0.24,
            size.height * 0.05),
        Paint()..color = const Color(0xFF7A5147));
    _blocks(canvas, size, const [
      (0.64, 0.20, 0.04, 0.06, Color(0xFFE9B44C)),
      (0.70, 0.20, 0.04, 0.06, Color(0xFF7DBA8D)),
      (0.76, 0.20, 0.04, 0.06, Color(0xFF8799D6)),
      (0.18, 0.70, 0.22, 0.08, Color(0xFFE8B8A8)),
      (0.80, 0.53, 0.05, 0.13, Color(0xFF7DBA8D)),
    ]);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.46, size.height * 0.70, size.width * 0.24,
            size.height * 0.08),
        Paint()
          ..color = isDark ? const Color(0xFF7E6AA4) : const Color(0xFFBFA7DE));
  }

  void _drawGarden(Canvas canvas, Size size) {
    _background(canvas, size,
        isDark ? const Color(0xFF34445A) : const Color(0xFFBEE7F2));
    _hill(canvas, size, 0.0, 0.62,
        isDark ? const Color(0xFF476D61) : const Color(0xFFA7D889));
    _fence(canvas, size, 0.58);
    _ground(canvas, size,
        isDark ? const Color(0xFF4E755B) : const Color(0xFF9DD879));
    _blocks(canvas, size, const [
      (0.12, 0.76, 0.06, 0.06, Color(0xFFFFC3D7)),
      (0.22, 0.74, 0.06, 0.06, Color(0xFFFFE18A)),
      (0.32, 0.76, 0.06, 0.06, Color(0xFFEEE8FA)),
      (0.72, 0.74, 0.08, 0.06, Color(0xFFFFC3D7)),
      (0.55, 0.86, 0.10, 0.04, Color(0xFFE6DACB)),
      (0.66, 0.88, 0.10, 0.04, Color(0xFFE6DACB)),
    ]);
    final flutter =
        (math.sin(ambienceValue * math.pi * 2) * size.height * 0.02);
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.72, size.height * 0.32 + flutter,
            size.width * 0.03, size.width * 0.02),
        Paint()..color = const Color(0xFFE28A45));
    canvas.drawRect(
        Rect.fromLTWH(size.width * 0.75, size.height * 0.32 - flutter,
            size.width * 0.03, size.width * 0.02),
        Paint()..color = const Color(0xFFE28A45));
  }

  void _background(Canvas canvas, Size size, Color color) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
  }

  void _ground(Canvas canvas, Size size, Color color) {
    canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.72, size.width, size.height * 0.28),
        Paint()..color = color);
    canvas.drawRect(
        Rect.fromLTWH(0, size.height * 0.70, size.width, size.height * 0.035),
        Paint()..color = Colors.white.withValues(alpha: 0.18));
  }

  void _tree(Canvas canvas, Offset base, double width, Paint paint) {
    canvas.drawRect(
        Rect.fromLTWH(base.dx - width * 0.12, base.dy - width * 0.25,
            width * 0.24, width * 0.55),
        Paint()..color = const Color(0xFF6B4A3A));
    canvas.drawRect(
        Rect.fromLTWH(base.dx - width * 0.50, base.dy - width * 0.85, width,
            width * 0.38),
        paint);
    canvas.drawRect(
        Rect.fromLTWH(base.dx - width * 0.38, base.dy - width * 1.08,
            width * 0.76, width * 0.34),
        paint);
    canvas.drawRect(
        Rect.fromLTWH(base.dx - width * 0.25, base.dy - width * 1.28,
            width * 0.50, width * 0.30),
        paint);
  }

  void _hill(Canvas canvas, Size size, double left, double top, Color color) {
    canvas.drawOval(
        Rect.fromLTWH(size.width * left, size.height * top, size.width * 0.70,
            size.height * 0.28),
        Paint()..color = color);
  }

  void _fence(Canvas canvas, Size size, double top) {
    final paint = Paint()..color = const Color(0xFFE4C79E);
    canvas.drawRect(
        Rect.fromLTWH(0, size.height * top, size.width, size.height * 0.025),
        paint);
    for (var i = 0; i < 8; i++) {
      final x = size.width * (i / 7);
      canvas.drawRect(
          Rect.fromLTWH(x, size.height * (top - 0.06), size.width * 0.025,
              size.height * 0.13),
          paint);
    }
  }

  void _sparkle(Canvas canvas, Size size, double x, double y) {
    final value =
        0.45 + (math.sin((ambienceValue + x) * math.pi * 2) + 1) * 0.22;
    canvas.drawRect(
        Rect.fromLTWH(size.width * x, size.height * y, size.width * 0.018,
            size.width * 0.018),
        Paint()..color = Colors.white.withValues(alpha: value));
  }

  void _blocks(Canvas canvas, Size size,
      List<(double, double, double, double, Color)> blocks) {
    for (final block in blocks) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * block.$1,
          size.height * block.$2,
          size.width * block.$3,
          size.height * block.$4,
        ),
        Paint()..color = block.$5,
      );
    }
  }

  @override
  bool shouldRepaint(StudyPetHabitatPainter oldDelegate) {
    return oldDelegate.habitat != habitat ||
        oldDelegate.isDark != isDark ||
        oldDelegate.ambienceValue != ambienceValue;
  }
}
