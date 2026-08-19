import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class XpRewardOverlay extends StatefulWidget {
  const XpRewardOverlay({
    required this.awardedXp,
    required this.message,
    this.onComplete,
    super.key,
  });

  final int awardedXp;
  final String message;
  final VoidCallback? onComplete;

  static Future<void> show(
    BuildContext context, {
    required int awardedXp,
    required String message,
    Duration duration = const Duration(milliseconds: 1800),
  }) async {
    if (awardedXp <= 0) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final completer = Completer<void>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => XpRewardOverlay(
        awardedXp: awardedXp,
        message: message,
        onComplete: () {
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    overlay.insert(entry);
    HapticFeedback.lightImpact();
    await Future.any([
      Future<void>.delayed(duration),
      completer.future,
    ]);
    entry.remove();
  }

  @override
  State<XpRewardOverlay> createState() => _XpRewardOverlayState();
}

class _XpRewardOverlayState extends State<XpRewardOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..forward().whenComplete(() => widget.onComplete?.call());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final fade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 18),
      TweenSequenceItem(tween: ConstantTween(1), weight: 58),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 24),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    final scale = reducedMotion
        ? const AlwaysStoppedAnimation<double>(1)
        : TweenSequence<double>([
            TweenSequenceItem(tween: Tween(begin: 0.86, end: 1.1), weight: 25),
            TweenSequenceItem(tween: Tween(begin: 1.1, end: 1), weight: 25),
            TweenSequenceItem(tween: ConstantTween(1), weight: 50),
          ]).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
          );
    final slide = reducedMotion
        ? const AlwaysStoppedAnimation<Offset>(Offset.zero)
        : Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: const Offset(0, -0.08),
          ).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    return IgnorePointer(
      child: SafeArea(
        child: Center(
          child: FractionalTranslation(
            translation: const Offset(0, -0.35),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Opacity(
                opacity: fade.value,
                child: FractionalTranslation(
                  translation: slide.value,
                  child: Transform.scale(scale: scale.value, child: child),
                ),
              ),
              child: Semantics(
                label: '${widget.awardedXp} XP earned.',
                liveRegion: true,
                child: Card(
                  elevation: 10,
                  color: const Color(0xFFFFF6E9),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFD49A3A),
                          size: 34,
                        ),
                        Text(
                          '+${widget.awardedXp} XP',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFA45E37),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
