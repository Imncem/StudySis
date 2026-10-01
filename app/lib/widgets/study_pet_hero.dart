import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/study_pet.dart';
import '../theme/app_theme.dart';
import 'study_pet_visuals.dart';

enum StudyPetHeroKind { locked, egg, pet }

class StudyPetHero extends StatefulWidget {
  const StudyPetHero({
    required this.title,
    required this.stageLabel,
    required this.kind,
    this.subtitle,
    this.egg,
    this.pet,
    this.petName,
    this.growthStage = StudyPetGrowthStage.hatchling,
    this.hatchAnimation,
    this.compact = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String stageLabel;
  final StudyPetHeroKind kind;
  final StudyEggDefinition? egg;
  final StudyPetDefinition? pet;
  final String? petName;
  final StudyPetGrowthStage growthStage;
  final Animation<double>? hatchAnimation;
  final bool compact;

  @override
  State<StudyPetHero> createState() => _StudyPetHeroState();
}

class _StudyPetHeroState extends State<StudyPetHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idleController;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_idleController.isAnimating) return;
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducedMotion || _isAutomatedWidgetTest) {
      _idleController.value = 0.18;
      return;
    }
    _idleController.repeat();
  }

  @override
  void dispose() {
    _idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final scheme = Theme.of(context).colorScheme;
    final accent = _accent(context);
    final surface = _surface(context);
    final visualSize = widget.compact ? 152.0 : 210.0;
    final animations = [
      _idleController,
      if (widget.hatchAnimation != null) widget.hatchAnimation!,
    ];

    return Semantics(
      label: widget.petName == null
          ? widget.title
          : '${widget.petName}, ${widget.stageLabel}',
      child: Container(
        padding: EdgeInsets.fromLTRB(18, widget.compact ? 18 : 22, 18, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              surface,
              Color.lerp(surface, scheme.surface, 0.46) ?? scheme.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: accent.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(
                  alpha: StudySisColors.isDark(context) ? 0.10 : 0.16),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            SizedBox(height: widget.compact ? 14 : 18),
            AnimatedBuilder(
              animation: Listenable.merge(animations),
              builder: (context, _) {
                final idle = reducedMotion ? 0.0 : _idleController.value;
                final hatch = widget.hatchAnimation?.value ?? 0.0;
                final bob =
                    reducedMotion ? 0.0 : math.sin(idle * math.pi * 2) * 7;
                final breathe = reducedMotion
                    ? 1.0
                    : 1.0 + math.sin(idle * math.pi * 2) * 0.018;
                final hatchShake = reducedMotion
                    ? 0.0
                    : math.sin(hatch * math.pi * 22) * (hatch < 0.7 ? 4 : 1.4);
                return SizedBox(
                  height: visualSize + 20,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _HeroHalo(
                        color: accent,
                        size: visualSize,
                        idleValue: idle,
                      ),
                      _TwinkleRing(
                        color: accent,
                        size: visualSize,
                        idleValue: idle,
                        enabled: !reducedMotion,
                      ),
                      Transform.translate(
                        offset: Offset(hatchShake, bob),
                        child: Transform.scale(
                          scale: breathe,
                          child: _visualFor(idle, hatch, visualSize),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: accent.withValues(alpha: 0.14)),
              ),
              child: Text(
                widget.stageLabel,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visualFor(double idle, double hatch, double size) {
    if (widget.kind == StudyPetHeroKind.locked) {
      return StudyPetMysteryVisual(size: size * 0.82);
    }
    if (widget.kind == StudyPetHeroKind.egg) {
      final egg = widget.egg ?? studyEggs.first;
      if (hatch >= 0.82) {
        return StudyPetCompanionVisual(
          pet: petForEgg(egg),
          growthStage: StudyPetGrowthStage.hatchling,
          size: size * 0.86,
          idleValue: idle,
        );
      }
      return StudyEggAvatar(
        egg: egg,
        size: size * 0.72,
        selected: true,
        hero: true,
        crackProgress: hatch,
      );
    }
    return StudyPetCompanionVisual(
      pet: widget.pet ?? studyPets.first,
      growthStage: widget.growthStage,
      size: size * 0.88,
      idleValue: idle,
    );
  }

  Color _accent(BuildContext context) {
    if (widget.egg != null) return Color(widget.egg!.primaryColor);
    if (widget.pet != null) return Color(widget.pet!.primaryColor);
    return StudySisColors.studyPetAccent(context);
  }

  Color _surface(BuildContext context) {
    if (widget.egg != null) return Color(widget.egg!.secondaryColor);
    return StudySisColors.studyPetSurface(context);
  }

  bool get _isAutomatedWidgetTest {
    return WidgetsBinding.instance.runtimeType
        .toString()
        .contains('AutomatedTestWidgetsFlutterBinding');
  }
}

class _HeroHalo extends StatelessWidget {
  const _HeroHalo({
    required this.color,
    required this.size,
    required this.idleValue,
  });

  final Color color;
  final double size;
  final double idleValue;

  @override
  Widget build(BuildContext context) {
    final pulse = 1 + math.sin(idleValue * math.pi * 2) * 0.02;
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.scale(
          scale: pulse,
          child: Container(
            width: size * 0.92,
            height: size * 0.92,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Container(
          width: size * 0.64,
          height: size * 0.64,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.10)),
          ),
        ),
        Positioned(
          bottom: size * 0.02,
          child: Container(
            width: size * 0.58,
            height: size * 0.12,
            decoration: BoxDecoration(
              color: Colors.black.withValues(
                  alpha: StudySisColors.isDark(context) ? 0.28 : 0.10),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ],
    );
  }
}

class _TwinkleRing extends StatelessWidget {
  const _TwinkleRing({
    required this.color,
    required this.size,
    required this.idleValue,
    required this.enabled,
  });

  final Color color;
  final double size;
  final double idleValue;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          _sparkle(0.13, 0.18, 0),
          _sparkle(0.78, 0.20, 0.35),
          _sparkle(0.17, 0.72, 0.70),
          _sparkle(0.82, 0.68, 0.12),
        ],
      ),
    );
  }

  Widget _sparkle(double left, double top, double phase) {
    final value = (math.sin((idleValue + phase) * math.pi * 2) + 1) / 2;
    return Positioned(
      left: size * left,
      top: size * top,
      child: Transform.scale(
        scale: 0.72 + value * 0.34,
        child: Icon(
          Icons.auto_awesome_rounded,
          size: 13 + value * 5,
          color: color.withValues(alpha: 0.34 + value * 0.42),
        ),
      ),
    );
  }
}
