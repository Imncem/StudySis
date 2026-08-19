import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/study_pet.dart';

class LevelUpAction {
  const LevelUpAction._(this.wantsChoosePet);

  final bool wantsChoosePet;

  static const continueOnly = LevelUpAction._(false);
  static const choosePet = LevelUpAction._(true);
}

class LevelUpScreen extends StatefulWidget {
  const LevelUpScreen({
    required this.newLevel,
    required this.totalXp,
    this.unlocksStudyPets = false,
    super.key,
  });

  final int newLevel;
  final int totalXp;
  final bool unlocksStudyPets;

  @override
  State<LevelUpScreen> createState() => _LevelUpScreenState();
}

class _LevelUpScreenState extends State<LevelUpScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..forward();
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final scale = reducedMotion
        ? const AlwaysStoppedAnimation<double>(1)
        : Tween<double>(begin: 0.85, end: 1).animate(
            CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
          );
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F3EA),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 58,
                      color: Color(0xFFD49A3A),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'LEVEL UP!',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'LEVEL ${widget.newLevel}',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF496A5A),
                              ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.unlocksStudyPets
                          ? "You've reached Level $petUnlockLevel!"
                          : 'Your learning journey is getting stronger!',
                      textAlign: TextAlign.center,
                    ),
                    if (widget.unlocksStudyPets) ...[
                      const SizedBox(height: 18),
                      const _FeatureUnlockCard(),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFD49A3A),
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.totalXp} XP',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    if (widget.unlocksStudyPets)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context)
                                  .pop(LevelUpAction.continueOnly),
                              child: const Text('Maybe Later'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.of(context)
                                  .pop(LevelUpAction.choosePet),
                              child: const Text('Choose My Egg'),
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context)
                              .pop(LevelUpAction.continueOnly),
                          child: const Text('Continue'),
                        ),
                      ),
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

class _FeatureUnlockCard extends StatelessWidget {
  const _FeatureUnlockCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: const Column(
          children: [
            Icon(Icons.card_giftcard_rounded, color: Color(0xFFD49A3A)),
            SizedBox(height: 8),
            Text(
              'NEW FEATURE UNLOCKED',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 8),
            Text(
              'Study Pets',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            SizedBox(height: 8),
            Text(
              'You can now choose your own mystery egg!',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
