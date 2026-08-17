import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/muffin_mascot_icon.dart';

class StreakCelebrationScreen extends StatefulWidget {
  const StreakCelebrationScreen({
    required this.streakDays,
    this.xpReward,
    super.key,
  });

  final int streakDays;
  final int? xpReward;

  @override
  State<StreakCelebrationScreen> createState() =>
      _StreakCelebrationScreenState();
}

class _StreakCelebrationScreenState extends State<StreakCelebrationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _hapticTimer;
  bool _sentHaptic = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..forward();
    _hapticTimer = Timer(const Duration(milliseconds: 500), _sendHaptic);
  }

  @override
  void dispose() {
    _controller.dispose();
    _hapticTimer?.cancel();
    super.dispose();
  }

  void _sendHaptic() {
    if (!mounted || _sentHaptic) return;
    _sentHaptic = true;
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final copy = _StreakCelebrationCopy.forDays(widget.streakDays);
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final backgroundOpacity = reducedMotion
        ? const AlwaysStoppedAnimation<double>(1)
        : CurvedAnimation(
            parent: _controller,
            curve: const Interval(0, 0.2, curve: Curves.easeOut),
          );
    final flameScale = reducedMotion
        ? const AlwaysStoppedAnimation<double>(1)
        : TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween<double>(begin: 0, end: 1.15)
                  .chain(CurveTween(curve: Curves.easeOutBack)),
              weight: 70,
            ),
            TweenSequenceItem(
              tween: Tween<double>(begin: 1.15, end: 1)
                  .chain(CurveTween(curve: Curves.easeOut)),
              weight: 30,
            ),
          ]).animate(
            CurvedAnimation(
              parent: _controller,
              curve: const Interval(0.1, 0.42),
            ),
          );
    final flameGlow = reducedMotion
        ? const AlwaysStoppedAnimation<double>(0.18)
        : TweenSequence<double>([
            TweenSequenceItem(
                tween: Tween<double>(begin: 0, end: 0.28), weight: 45),
            TweenSequenceItem(
                tween: Tween<double>(begin: 0.28, end: 0.12), weight: 55),
          ]).animate(
            CurvedAnimation(
              parent: _controller,
              curve: const Interval(0.18, 0.58, curve: Curves.easeOut),
            ),
          );
    final streakScale = reducedMotion
        ? const AlwaysStoppedAnimation<double>(1)
        : Tween<double>(begin: 0.76, end: 1).animate(
            CurvedAnimation(
              parent: _controller,
              curve: const Interval(0.26, 0.58, curve: Curves.elasticOut),
            ),
          );
    final streakFade = _fade(0.26, 0.46, reducedMotion);
    final muffinFade = _fade(0.54, 0.72, reducedMotion);
    final muffinSlide =
        _slide(0.54, 0.78, reducedMotion, const Offset(0, 0.18));
    final rewardFade = _fade(0.66, 0.82, reducedMotion);
    final rewardSlide =
        _slide(0.66, 0.86, reducedMotion, const Offset(0, 0.16));
    final buttonFade = _fade(0.78, 0.96, reducedMotion);
    final buttonSlide = _slide(0.78, 1, reducedMotion, const Offset(0, 0.18));

    return Scaffold(
      backgroundColor: const Color(0xFFFFF6EA),
      body: FadeTransition(
        opacity: backgroundOpacity,
        child: Stack(
          children: [
            if (!reducedMotion)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _ConfettiBurstPainter(_controller.value),
                      );
                    },
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const Spacer(),
                    AnimatedBuilder(
                      animation: flameGlow,
                      builder: (context, child) {
                        return Container(
                          width: 118,
                          height: 118,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFFD08A)
                                .withValues(alpha: flameGlow.value),
                          ),
                          child: child,
                        );
                      },
                      child: ScaleTransition(
                        scale: flameScale,
                        child: const Text(
                          '\u{1F525}',
                          style: TextStyle(fontSize: 86, height: 1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FadeTransition(
                      opacity: streakFade,
                      child: ScaleTransition(
                        scale: streakScale,
                        child: Column(
                          children: [
                            Text(
                              copy.title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              copy.subtitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeTransition(
                      opacity: muffinFade,
                      child: SlideTransition(
                        position: muffinSlide,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              _AnimatedMuffinMascot(
                                animation: _controller,
                                reducedMotion: reducedMotion,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  copy.muffinMessage,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (widget.xpReward != null && widget.xpReward! > 0)
                      FadeTransition(
                        opacity: rewardFade,
                        child: SlideTransition(
                          position: rewardSlide,
                          child: _RewardChip(xpReward: widget.xpReward!),
                        ),
                      ),
                    const Spacer(),
                    FadeTransition(
                      opacity: buttonFade,
                      child: SlideTransition(
                        position: buttonSlide,
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Continue'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Animation<double> _fade(double begin, double end, bool reducedMotion) {
    if (reducedMotion) return const AlwaysStoppedAnimation<double>(1);
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
  }

  Animation<Offset> _slide(
    double begin,
    double end,
    bool reducedMotion,
    Offset offset,
  ) {
    if (reducedMotion) return const AlwaysStoppedAnimation<Offset>(Offset.zero);
    return Tween<Offset>(begin: offset, end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      ),
    );
  }
}

class _AnimatedMuffinMascot extends StatelessWidget {
  const _AnimatedMuffinMascot({
    required this.animation,
    required this.reducedMotion,
  });

  final Animation<double> animation;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    if (reducedMotion) return const MuffinMascotIcon(size: 38);
    final mascotMotion = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.52, 0.76, curve: Curves.easeOutBack),
    );
    return AnimatedBuilder(
      animation: mascotMotion,
      builder: (context, child) {
        final value = mascotMotion.value;
        final hop = math.sin(value * math.pi) * -8;
        final rotation = (1 - value) * -0.1;
        return Transform.translate(
          offset: Offset(0, hop),
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: 0.86 + (value * 0.14),
              child: child,
            ),
          ),
        );
      },
      child: const MuffinMascotIcon(size: 38),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.xpReward});

  final int xpReward;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8B8),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFE1B35B)),
      ),
      child: Text(
        '\u{2B50} +$xpReward XP',
        style: const TextStyle(
          color: Color(0xFF7A4E18),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StreakCelebrationCopy {
  const _StreakCelebrationCopy({
    required this.title,
    required this.subtitle,
    required this.muffinMessage,
  });

  final String title;
  final String subtitle;
  final String muffinMessage;

  static _StreakCelebrationCopy forDays(int days) {
    if (days == 1) {
      return const _StreakCelebrationCopy(
        title: '1 DAY STREAK',
        subtitle: 'Your streak starts today!',
        muffinMessage: "Nice start! Let's come back tomorrow.",
      );
    }
    if (days == 7) {
      return const _StreakCelebrationCopy(
        title: '7 DAY STREAK',
        subtitle: 'One whole week!',
        muffinMessage:
            "Seven days of showing up. That's something to be proud of!",
      );
    }
    if (days == 14) {
      return const _StreakCelebrationCopy(
        title: '14 DAY STREAK',
        subtitle: 'Two weeks strong!',
        muffinMessage: "Nice work! Let's keep it going tomorrow.",
      );
    }
    if (days == 30) {
      return const _StreakCelebrationCopy(
        title: '30 DAY STREAK',
        subtitle: '30 days of consistent learning!',
        muffinMessage: "Nice work! Let's keep it going tomorrow.",
      );
    }
    return _StreakCelebrationCopy(
      title: '$days DAY STREAK',
      subtitle: 'You showed up again today!',
      muffinMessage: "Nice work! Let's keep it going tomorrow.",
    );
  }
}

class _ConfettiBurstPainter extends CustomPainter {
  const _ConfettiBurstPainter(this.timeline);

  final double timeline;

  static const _colors = [
    Color(0xFF496A5A),
    Color(0xFFE1B35B),
    Color(0xFFA45E37),
    Color(0xFFB7D0BE),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const start = 0.42;
    const end = 0.72;
    if (timeline < start || timeline > end) return;
    final burst = ((timeline - start) / (end - start)).clamp(0.0, 1.0);
    final opacity = math.sin(burst * math.pi).clamp(0.0, 1.0);
    final center = Offset(size.width / 2, size.height * 0.34);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < 20; i++) {
      final angle = (-math.pi * 0.92) + (math.pi * 1.84 * i / 19);
      final distance = 34 + (burst * (70 + (i % 5) * 7));
      final position = center +
          Offset(
            math.cos(angle) * distance,
            math.sin(angle) * distance + (burst * burst * 26),
          );
      paint.color = _colors[i % _colors.length].withValues(alpha: opacity);
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(angle + burst * 1.8);
      if (i.isEven) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-3, -7, 6, 14),
            const Radius.circular(2),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, 3.5, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiBurstPainter oldDelegate) {
    return oldDelegate.timeline != timeline;
  }
}
