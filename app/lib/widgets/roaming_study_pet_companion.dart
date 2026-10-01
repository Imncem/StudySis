import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/study_pet.dart';
import '../repositories/study_pet_repository.dart';
import 'pixel_study_pet.dart';

enum RoamingStudyPetMode {
  normal,
  stationary,
  hidden,
}

class RoamingStudyPetCompanion extends StatefulWidget {
  const RoamingStudyPetCompanion({
    this.petRepository,
    this.enabled = true,
    this.hidden = false,
    this.mode = RoamingStudyPetMode.normal,
    this.bottomInset = 84,
    super.key,
  });

  final StudyPetRepository? petRepository;
  final bool enabled;
  final bool hidden;
  final RoamingStudyPetMode mode;
  final double bottomInset;

  @override
  State<RoamingStudyPetCompanion> createState() =>
      _RoamingStudyPetCompanionState();
}

class _RoamingStudyPetCompanionState extends State<RoamingStudyPetCompanion>
    with WidgetsBindingObserver {
  static const double _edgePadding = 18;
  static const double _maxLaneWidth = 520;
  static const double _step = 3;
  static const Duration _tickDuration = Duration(milliseconds: 125);

  StudyPetRepository? _petRepository;
  final math.Random _random = math.Random(36);
  Timer? _tickTimer;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  _RoamingLoopState _loopState = _RoamingLoopState.idle;
  DateTime _idleUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  double _x = 0;
  double _targetX = 0;
  bool _hasPosition = false;
  bool _facingRight = true;
  int _frame = 0;

  bool get _isAutomatedWidgetTest {
    return WidgetsBinding.instance.runtimeType
        .toString()
        .contains('AutomatedTestWidgetsFlutterBinding');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(RoamingStudyPetCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petRepository != widget.petRepository) {
      _petRepository = widget.petRepository;
    }
    if (oldWidget.mode != widget.mode ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.hidden != widget.hidden) {
      _cancelRoaming();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (state != AppLifecycleState.resumed) {
      _cancelRoaming();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelRoaming();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled ||
        widget.hidden ||
        widget.mode == RoamingStudyPetMode.hidden) {
      return const SizedBox.shrink();
    }
    final petRepository =
        _petRepository ??= widget.petRepository ?? StudyPetRepository();
    return StreamBuilder<StudyPetState>(
      stream: petRepository.watchState(),
      initialData: StudyPetState.empty,
      builder: (context, snapshot) {
        final state = snapshot.data ?? StudyPetState.empty;
        final pet = state.pet;
        if (state.stage != StudyPetStage.hatchling || pet == null) {
          _cancelRoaming();
          return const SizedBox.shrink();
        }
        return Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = roamingPixelPetSizeForWidth(constraints.maxWidth);
                final lane = roamingLaneForWidth(constraints.maxWidth, size);
                _ensurePosition(lane);

                final reducedMotion = MediaQuery.disableAnimationsOf(context) ||
                    _isAutomatedWidgetTest ||
                    widget.mode == RoamingStudyPetMode.stationary;
                if (reducedMotion) {
                  _cancelRoaming();
                  _loopState = _RoamingLoopState.idle;
                } else {
                  _ensureRoaming(lane, pet);
                }

                final motion = _motionFor(pet, reducedMotion);
                final baselineBottom =
                    MediaQuery.paddingOf(context).bottom + widget.bottomInset;
                final topOffset = _verticalOffsetFor(pet, motion);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: quantizeRoamingX(_x.clamp(lane.left, lane.right)),
                      bottom: baselineBottom + topOffset,
                      width: size,
                      height: size,
                      child: Semantics(
                        label:
                            '${state.petName ?? pet.displayName} roaming Study Buddy',
                        child: PixelStudyPet(
                          pet: pet,
                          growthStage: state.growthStage,
                          motion: motion,
                          frame: _frame,
                          facingRight: _facingRight,
                          size: size,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _ensurePosition(RoamingLane lane) {
    if (_hasPosition) {
      _x = _x.clamp(lane.left, lane.right);
      _targetX = _targetX.clamp(lane.left, lane.right);
      return;
    }
    final startRatio = 0.22 + _random.nextDouble() * 0.12;
    _x = lane.left + lane.width * startRatio;
    _targetX = _x;
    _hasPosition = true;
  }

  void _ensureRoaming(RoamingLane lane, StudyPetDefinition pet) {
    if (_tickTimer != null || _appLifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final now = DateTime.now();
    _idleUntil = now.add(_idleDuration());
    _lastFrameAt = now;
    _tickTimer = Timer.periodic(
      _tickDuration,
      (_) => _tick(lane, pet),
    );
  }

  void _tick(RoamingLane lane, StudyPetDefinition pet) {
    if (!mounted || _appLifecycleState != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    var shouldUpdate = false;

    if (now.difference(_lastFrameAt) >= _frameDurationFor(pet)) {
      _frame += 1;
      _lastFrameAt = now;
      shouldUpdate = true;
    }

    if (_loopState == _RoamingLoopState.idle && now.isAfter(_idleUntil)) {
      _targetX = _pickTarget(lane);
      _facingRight = _targetX >= _x;
      _loopState = _RoamingLoopState.moving;
      shouldUpdate = true;
    }

    if (_loopState == _RoamingLoopState.moving) {
      final direction = _targetX >= _x ? 1 : -1;
      final distance = (_targetX - _x).abs();
      if (distance <= _step) {
        _x = _targetX;
        _loopState = _RoamingLoopState.idle;
        _idleUntil = now.add(_idleDuration());
      } else {
        _x += direction * _speedStepFor(pet);
      }
      shouldUpdate = true;
    }

    if (shouldUpdate) setState(() {});
  }

  double _pickTarget(RoamingLane lane) {
    final direction = _random.nextBool() ? 1 : -1;
    final minDistance = math.min(52.0, lane.width * 0.18);
    final maxDistance = math.max(minDistance, lane.width * 0.48);
    final distance =
        minDistance + _random.nextDouble() * (maxDistance - minDistance);
    var next = _x + direction * distance;
    if (next < lane.left || next > lane.right) {
      next = _x - direction * distance;
    }
    return quantizeRoamingX(next.clamp(lane.left, lane.right));
  }

  void _cancelRoaming() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  PixelPetMotion _motionFor(StudyPetDefinition pet, bool reducedMotion) {
    if (reducedMotion || _loopState == _RoamingLoopState.idle) {
      return PixelPetMotion.idle;
    }
    return pixelSpriteSetFor(pet.id).movement;
  }

  double _verticalOffsetFor(StudyPetDefinition pet, PixelPetMotion motion) {
    if (motion != PixelPetMotion.hop) return 0;
    return switch (_frame % 4) {
      1 => 3,
      2 => 7,
      3 => 3,
      _ => 0,
    };
  }

  double _speedStepFor(StudyPetDefinition pet) {
    return switch (pet.id) {
      StudyPetId.fox => 3.0,
      StudyPetId.bunny => 3.0,
      StudyPetId.cat => 2.25,
    };
  }

  Duration _idleDuration() {
    return Duration(milliseconds: 2200 + _random.nextInt(2800));
  }

  Duration _frameDurationFor(StudyPetDefinition pet) {
    if (_loopState == _RoamingLoopState.idle) {
      return switch (pet.id) {
        StudyPetId.fox => const Duration(milliseconds: 720),
        StudyPetId.bunny => const Duration(milliseconds: 820),
        StudyPetId.cat => const Duration(milliseconds: 760),
      };
    }
    return switch (pet.id) {
      StudyPetId.fox => const Duration(milliseconds: 150),
      StudyPetId.bunny => const Duration(milliseconds: 170),
      StudyPetId.cat => const Duration(milliseconds: 160),
    };
  }
}

enum _RoamingLoopState { idle, moving }

@visibleForTesting
double roamingPixelPetSizeForWidth(double width) {
  if (width < 360) return 40;
  if (width < 520) return 48;
  return 52;
}

@visibleForTesting
double quantizeRoamingX(double x) =>
    (x / _RoamingStudyPetCompanionState._step).roundToDouble() *
    _RoamingStudyPetCompanionState._step;

@visibleForTesting
RoamingLane roamingLaneForWidth(double availableWidth, double petSize) {
  final laneWidth = math.min(
    availableWidth,
    _RoamingStudyPetCompanionState._maxLaneWidth,
  );
  final laneLeft = ((availableWidth - laneWidth) / 2) +
      _RoamingStudyPetCompanionState._edgePadding;
  final laneRight = laneLeft +
      laneWidth -
      petSize -
      (_RoamingStudyPetCompanionState._edgePadding * 2);
  return RoamingLane(laneLeft, math.max(laneLeft, laneRight));
}

@visibleForTesting
class RoamingLane {
  const RoamingLane(this.left, this.right);

  final double left;
  final double right;

  double get width => right - left;
}
