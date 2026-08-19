import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/engagement.dart';
import '../models/study_pet.dart';
import '../repositories/engagement_repository.dart';
import '../repositories/study_pet_repository.dart';
import '../widgets/study_pet_visuals.dart';

class StudyPetScreen extends StatefulWidget {
  const StudyPetScreen({
    this.engagementRepository,
    this.petRepository,
    this.nowProvider,
    this.refreshInterval = const Duration(minutes: 1),
    super.key,
  });

  final EngagementRepository? engagementRepository;
  final StudyPetRepository? petRepository;
  final DateTime Function()? nowProvider;
  final Duration refreshInterval;

  @override
  State<StudyPetScreen> createState() => _StudyPetScreenState();
}

class _StudyPetScreenState extends State<StudyPetScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final EngagementRepository _engagementRepository;
  late final StudyPetRepository _petRepository;
  late final AnimationController _hatchController;
  Timer? _refreshTimer;
  StudyEggDefinition? _selectedEgg;
  bool _isSaving = false;
  bool _showNaming = false;
  String? _nameError;
  final _nameController = TextEditingController();

  DateTime get _now => widget.nowProvider?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _engagementRepository =
        widget.engagementRepository ?? EngagementRepository();
    _petRepository = widget.petRepository ?? StudyPetRepository();
    _hatchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(widget.refreshInterval, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _hatchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Pets')),
      body: StreamBuilder<EngagementState>(
        stream: _engagementRepository.watchState(),
        initialData: EngagementState.initial('today'),
        builder: (context, engagementSnapshot) {
          final engagement =
              engagementSnapshot.data ?? EngagementState.initial('today');
          return StreamBuilder<StudyPetState>(
            stream: _petRepository.watchState(),
            initialData: StudyPetState.empty,
            builder: (context, petSnapshot) {
              final pet = petSnapshot.data ?? StudyPetState.empty;
              final state = StudyPetViewState(
                engagement: engagement,
                pet: pet,
                now: _now,
              );
              return SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    if (!state.isUnlocked)
                      _LockedPetView(state: state)
                    else if (pet.stage == StudyPetStage.hatchling)
                      _HatchlingProfile(state: state)
                    else if (pet.stage == StudyPetStage.egg)
                      _EggIncubationView(
                        state: state,
                        hatchController: _hatchController,
                        showNaming: _showNaming,
                        nameController: _nameController,
                        nameError: _nameError,
                        isSaving: _isSaving,
                        onStartHatch: () => _startHatch(state),
                        onSaveName: () => _saveName(state),
                      )
                    else
                      _EggSelectionView(
                        selectedEgg: _selectedEgg,
                        isSaving: _isSaving,
                        onSelect: (egg) => setState(() => _selectedEgg = egg),
                        onStart: _selectedEgg == null
                            ? null
                            : () => _confirmEggSelection(
                                  context,
                                  _selectedEgg!,
                                  engagement,
                                ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmEggSelection(
    BuildContext context,
    StudyEggDefinition egg,
    EngagementState engagement,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose this egg?'),
        content: const Text(
          'Your choice will be locked once incubation begins.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Choose Another'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start Incubation'),
          ),
        ],
      ),
    );
    if (confirmed != true || _isSaving) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);
    try {
      await _petRepository.selectEgg(
        egg: egg,
        currentTotalXp: engagement.totalXp,
      );
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not start incubation: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _startHatch(StudyPetViewState state) async {
    if (!state.readyToHatch || _hatchController.isAnimating || _showNaming) {
      return;
    }
    if (!MediaQuery.disableAnimationsOf(context)) {
      HapticFeedback.lightImpact();
      await _hatchController.forward(from: 0);
    }
    if (mounted) setState(() => _showNaming = true);
  }

  Future<void> _saveName(StudyPetViewState state) async {
    if (_isSaving) return;
    String name;
    try {
      name = validatePetName(_nameController.text);
    } on FormatException catch (error) {
      setState(() => _nameError = error.message);
      return;
    }
    setState(() {
      _isSaving = true;
      _nameError = null;
    });
    try {
      await _petRepository.hatchEgg(
        petName: name,
        currentTotalXp: state.engagement.totalXp,
        now: _now,
      );
      if (mounted) {
        setState(() {
          _showNaming = false;
          _nameController.clear();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _nameError = error.toString());
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _LockedPetView extends StatelessWidget {
  const _LockedPetView({required this.state});

  final StudyPetViewState state;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unlock at Level 3',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
          const SizedBox(height: 8),
          const Text(
            "Keep studying and earning XP. When you reach Level 3, you'll be able to choose your own mystery egg.",
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: state.unlockProgress.clamp(0, 1),
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8E3),
          ),
          const SizedBox(height: 8),
          Text('⭐ ${state.xpTowardUnlock} / $petUnlockXp XP'),
          const SizedBox(height: 4),
          Text('${state.xpToUnlock} XP to go!'),
        ],
      ),
    );
  }
}

class _EggSelectionView extends StatelessWidget {
  const _EggSelectionView({
    required this.selectedEgg,
    required this.isSaving,
    required this.onSelect,
    required this.onStart,
  });

  final StudyEggDefinition? selectedEgg;
  final bool isSaving;
  final ValueChanged<StudyEggDefinition> onSelect;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Your Study Buddy',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
            'Each egg is a mystery. Study, earn XP and give it time to hatch.'),
        const SizedBox(height: 20),
        for (final egg in studyEggs) ...[
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: isSaving ? null : () => onSelect(egg),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    StudyEggAvatar(
                      egg: egg,
                      size: 74,
                      selected: selectedEgg?.id == egg.id,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            egg.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(egg.hint),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isSaving ? null : onStart,
            child: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Start Incubation'),
          ),
        ),
      ],
    );
  }
}

class _EggIncubationView extends StatelessWidget {
  const _EggIncubationView({
    required this.state,
    required this.hatchController,
    required this.showNaming,
    required this.nameController,
    required this.nameError,
    required this.isSaving,
    required this.onStartHatch,
    required this.onSaveName,
  });

  final StudyPetViewState state;
  final AnimationController hatchController;
  final bool showNaming;
  final TextEditingController nameController;
  final String? nameError;
  final bool isSaving;
  final VoidCallback onStartHatch;
  final VoidCallback onSaveName;

  @override
  Widget build(BuildContext context) {
    final egg = state.pet.egg ?? studyEggs.first;
    final pet = petForEgg(egg);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'YOUR EGG',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        AnimatedBuilder(
          animation: hatchController,
          builder: (context, child) {
            final value = hatchController.value;
            final shake = reducedMotion
                ? 0.0
                : math.sin(value * math.pi * 22) * (value < 0.7 ? 4 : 1.5);
            final glow = reducedMotion ? 0.0 : value.clamp(0.0, 1.0);
            return Transform.translate(
              offset: Offset(shake, 0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 170 + glow * 32,
                    height: 170 + glow * 32,
                    decoration: BoxDecoration(
                      color: Color(egg.primaryColor)
                          .withValues(alpha: 0.12 + glow * 0.18),
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (value >= 0.82)
                    Transform.scale(
                      scale: 0.8 + value * 0.25,
                      child: StudyPetAvatar(pet: pet, size: 138),
                    )
                  else
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        StudyEggAvatar(egg: egg, size: 138),
                        if (value > 0.45)
                          const Text(
                            '⌁',
                            style: TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF496A5A),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        Text(
          showNaming ? 'You hatched a ${pet.displayName}!' : egg.displayName,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('⭐ ${state.cappedHatchXp} / ${state.pet.hatchXpTarget} XP'),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: state.hatchXpProgress.clamp(0, 1),
                minHeight: 8,
                backgroundColor: const Color(0xFFE2E8E3),
              ),
              const SizedBox(height: 12),
              Text(state.timeReady
                  ? '⏳ Ready'
                  : '⏳ ${state.elapsedHours} hours have passed'),
              const SizedBox(height: 14),
              Text(_incubationMessage(state)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (showNaming)
          _NamingCard(
            controller: nameController,
            errorText: nameError,
            isSaving: isSaving,
            onSave: onSaveName,
          )
        else if (state.readyToHatch)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: hatchController.isAnimating ? null : onStartHatch,
              child: const Text('Hatch My Egg'),
            ),
          ),
      ],
    );
  }

  String _incubationMessage(StudyPetViewState state) {
    if (state.readyToHatch) return '✨ Ready to Hatch!';
    if (state.xpReady) {
      return 'Learning goal complete! Something is moving inside... Your egg needs a little more time.';
    }
    if (state.timeReady) {
      return 'Your egg is ready to grow! Earn ${state.remainingHatchXp} more XP to hatch it.';
    }
    return 'Keep studying. Your egg is growing with you.';
  }
}

class _NamingCard extends StatelessWidget {
  const _NamingCard({
    required this.controller,
    required this.errorText,
    required this.isSaving,
    required this.onSave,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Give your Study Buddy a name',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLength: 15,
            decoration: InputDecoration(
              labelText: 'Name your buddy',
              errorText: errorText,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isSaving ? null : onSave,
              child: const Text('Save Name'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HatchlingProfile extends StatelessWidget {
  const _HatchlingProfile({required this.state});

  final StudyPetViewState state;

  @override
  Widget build(BuildContext context) {
    final pet = state.pet.pet ?? studyPets.first;
    final name = state.pet.petName ?? pet.displayName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'YOUR STUDY BUDDY',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        StudyPetAvatar(pet: pet, size: 132),
        const SizedBox(height: 14),
        Text(name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Hatchling'),
        const SizedBox(height: 18),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('⭐ Growing with your learning'),
              const SizedBox(height: 8),
              Text('Keep studying together to help $name grow.'),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Icon(Icons.lock_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Customize'),
                  Spacer(),
                  Text('Coming soon'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}
