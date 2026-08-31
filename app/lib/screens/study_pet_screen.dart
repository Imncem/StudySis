import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/engagement.dart';
import '../models/pet_cosmetic.dart';
import '../models/study_pet.dart';
import '../repositories/engagement_repository.dart';
import '../repositories/pet_economy_repository.dart';
import '../repositories/study_pet_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/study_pet_habitat.dart';
import '../widgets/study_pet_hero.dart';
import '../widgets/study_pet_visuals.dart';

class StudyPetScreen extends StatefulWidget {
  const StudyPetScreen({
    this.engagementRepository,
    this.petRepository,
    this.petEconomyRepository,
    this.nowProvider,
    this.refreshInterval = const Duration(minutes: 1),
    super.key,
  });

  static const routeName = 'study_pet';

  final EngagementRepository? engagementRepository;
  final StudyPetRepository? petRepository;
  final PetEconomyRepository? petEconomyRepository;
  final DateTime Function()? nowProvider;
  final Duration refreshInterval;

  @override
  State<StudyPetScreen> createState() => _StudyPetScreenState();
}

class _StudyPetScreenState extends State<StudyPetScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final EngagementRepository _engagementRepository;
  late final StudyPetRepository _petRepository;
  late final PetEconomyRepository _petEconomyRepository;
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
    _petEconomyRepository =
        widget.petEconomyRepository ?? PetEconomyRepository();
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
              return StreamBuilder<PetEconomyState>(
                stream: _petEconomyRepository.watchState(),
                initialData: PetEconomyState.empty,
                builder: (context, economySnapshot) {
                  final economy = economySnapshot.data ?? PetEconomyState.empty;
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
                          _HatchlingProfile(
                            state: state,
                            petRepository: _petRepository,
                            equippedCosmetics: economy.equippedCosmeticIds,
                          )
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
                            onSelect: (egg) =>
                                setState(() => _selectedEgg = egg),
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
        title: Text('Choose ${egg.displayName}?'),
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
    if (!kIsWeb && !MediaQuery.disableAnimationsOf(context)) {
      HapticFeedback.lightImpact();
    }
    if (!MediaQuery.disableAnimationsOf(context)) {
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
    return Column(
      children: [
        const StudyPetHero(
          title: 'Mystery Study Buddy',
          subtitle: 'A gentle companion is waiting for your learning journey.',
          stageLabel: 'Locked until Level 3',
          kind: StudyPetHeroKind.locked,
        ),
        const SizedBox(height: 18),
        _StatusCard(
          title: 'Unlock at Level 3',
          icon: Icons.lock_open_rounded,
          accent: StudySisColors.studyPetAccent(context),
          children: [
            const Text(
              "Keep studying and earning XP. When you reach Level 3, you can choose your own mystery egg.",
            ),
            const SizedBox(height: 16),
            _ProgressLine(
              label: 'Level 3 progress',
              value: '${state.xpTowardUnlock} / $petUnlockXp XP',
              progress: state.unlockProgress,
              color: StudySisColors.studyPetAccent(context),
            ),
            const SizedBox(height: 10),
            Text(
              state.xpToUnlock == 0
                  ? 'Ready to unlock.'
                  : '${state.xpToUnlock} XP to go!',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StudyPetHero(
          title: 'Choose Your Study Buddy',
          subtitle: 'Pick one mystery egg. It will grow as you learn.',
          stageLabel: 'Egg Selection',
          kind: StudyPetHeroKind.locked,
          compact: true,
        ),
        const SizedBox(height: 18),
        for (final egg in studyEggs) ...[
          _EggChoiceCard(
            egg: egg,
            selected: selectedEgg?.id == egg.id,
            enabled: !isSaving,
            onTap: () => onSelect(egg),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: isSaving ? null : onStart,
          icon: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_rounded),
          label: const Text('Start Incubation'),
        ),
      ],
    );
  }
}

class _EggChoiceCard extends StatelessWidget {
  const _EggChoiceCard({
    required this.egg,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final StudyEggDefinition egg;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Color(egg.primaryColor);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.50)
                  : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              StudyEggAvatar(
                egg: egg,
                size: 82,
                selected: selected,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      egg.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_personalityHint(egg)),
                    const SizedBox(height: 8),
                    Text(
                      egg.hint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? accent : Theme.of(context).disabledColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _personalityHint(StudyEggDefinition egg) {
    return switch (egg.id) {
      StudyEggId.spark => 'Energetic, clever, and adventurous.',
      StudyEggId.sprout => 'Gentle, calm, and caring.',
      StudyEggId.starlight => 'Curious, dreamy, and magical.',
    };
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StudyPetHero(
          title: showNaming
              ? 'You hatched a ${pet.displayName}!'
              : egg.displayName,
          subtitle: showNaming
              ? 'Your new buddy is ready for a name.'
              : 'Your egg is growing with your learning.',
          stageLabel: showNaming ? 'Hatching' : _incubationStageLabel(state),
          kind: StudyPetHeroKind.egg,
          egg: egg,
          hatchAnimation: hatchController,
        ),
        const SizedBox(height: 18),
        _StatusCard(
          title: 'Incubation progress',
          icon: Icons.egg_alt_rounded,
          accent: Color(egg.primaryColor),
          children: [
            _ProgressLine(
              label: 'Learning energy',
              value: '${state.cappedHatchXp} / ${state.pet.hatchXpTarget} XP',
              progress: state.hatchXpProgress,
              color: Color(egg.primaryColor),
            ),
            const SizedBox(height: 14),
            _ProgressLine(
              label: 'Time together',
              value: state.timeReady
                  ? 'Ready'
                  : '${state.elapsedHours} / ${state.hatchDelay.inHours} hours',
              progress: _timeProgress(state),
              color: StudySisColors.progressAccent(context),
            ),
            const SizedBox(height: 14),
            Text(
              _incubationMessage(state),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
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
          FilledButton.icon(
            onPressed: hatchController.isAnimating ? null : onStartHatch,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Hatch My Egg'),
          ),
      ],
    );
  }

  double _timeProgress(StudyPetViewState state) {
    final delay = state.hatchDelay.inMinutes;
    if (delay <= 0) return 1;
    return (state.elapsedSinceSelection.inMinutes / delay).clamp(0, 1);
  }

  String _incubationStageLabel(StudyPetViewState state) {
    if (state.readyToHatch) return 'Hatching soon';
    return 'Incubating';
  }

  String _incubationMessage(StudyPetViewState state) {
    if (state.readyToHatch) {
      return 'Your egg is ready. Tap Hatch My Egg when you are ready.';
    }
    if (state.xpReady) {
      return 'Learning energy is full. It needs a little more real time before hatching.';
    }
    if (state.timeReady) {
      return 'The egg has had enough time. Earn ${state.remainingHatchXp} more XP to hatch it.';
    }
    return 'A little more time and XP before it hatches.';
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
    return _StatusCard(
      title: 'Give your Study Buddy a name',
      icon: Icons.edit_rounded,
      accent: StudySisColors.studyPetAccent(context),
      children: [
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
    );
  }
}

class _HatchlingProfile extends StatefulWidget {
  const _HatchlingProfile({
    required this.state,
    required this.petRepository,
    required this.equippedCosmetics,
  });

  final StudyPetViewState state;
  final StudyPetRepository petRepository;
  final Map<String, String?> equippedCosmetics;

  @override
  State<_HatchlingProfile> createState() => _HatchlingProfileState();
}

class _HatchlingProfileState extends State<_HatchlingProfile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idleController;
  StudyPetHabitat? _optimisticHabitat;
  bool _isSavingHabitat = false;
  bool _isEvolving = false;
  bool _baselineRequested = false;

  StudyPetHabitat get _selectedHabitat =>
      _optimisticHabitat ?? widget.state.pet.habitatTheme;

  bool get _isAutomatedWidgetTest {
    return WidgetsBinding.instance.runtimeType
        .toString()
        .contains('AutomatedTestWidgetsFlutterBinding');
  }

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );
  }

  @override
  void didUpdateWidget(_HatchlingProfile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.pet.habitatTheme == _optimisticHabitat) {
      _optimisticHabitat = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_idleController.isAnimating) return;
    if (MediaQuery.disableAnimationsOf(context) || _isAutomatedWidgetTest) {
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
    final pet = widget.state.pet.pet ?? studyPets.first;
    final name = widget.state.pet.petName ?? pet.displayName;
    final selectedHabitat = _selectedHabitat;
    _ensureGrowthBaseline();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedBuilder(
          animation: _idleController,
          builder: (context, _) {
            return AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 280),
              child: StudyPetHabitatView(
                key: ValueKey(selectedHabitat),
                habitat: selectedHabitat,
                pet: pet,
                petName: name,
                growthStage: widget.state.pet.growthStage,
                idleValue: _idleController.value,
                equippedCosmetics: widget.equippedCosmetics,
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        StudyPetHabitatSelector(
          selected: selectedHabitat,
          enabled: !_isSavingHabitat,
          onSelected: (habitat) => _selectHabitat(habitat),
        ),
        const SizedBox(height: 18),
        _StatusCard(
          title: 'Growth',
          icon: Icons.favorite_rounded,
          accent: Color(pet.primaryColor),
          children: [
            _GrowthStatus(
              state: widget.state,
              pet: pet,
              petName: name,
              isEvolving: _isEvolving,
              onEvolve: _isEvolving ? null : _evolvePet,
            ),
          ],
        ),
      ],
    );
  }

  void _ensureGrowthBaseline() {
    if (_baselineRequested ||
        !widget.state.pet.hasHatchling ||
        widget.state.pet.xpBaselineAtHatch != null) {
      return;
    }
    _baselineRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await widget.petRepository.ensureGrowthBaseline(
          currentTotalXp: widget.state.engagement.totalXp,
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not prepare growth progress: $error')),
        );
      }
    });
  }

  Future<void> _selectHabitat(StudyPetHabitat habitat) async {
    final previous = _selectedHabitat;
    if (habitat == previous || _isSavingHabitat) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _optimisticHabitat = habitat;
      _isSavingHabitat = true;
    });
    try {
      await widget.petRepository.updateHabitat(habitat);
    } catch (error) {
      if (!mounted) return;
      setState(() => _optimisticHabitat = previous);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save habitat: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSavingHabitat = false);
    }
  }

  Future<void> _evolvePet() async {
    if (_isEvolving || !widget.state.readyToEvolve) return;
    final pet = widget.state.pet.pet ?? studyPets.first;
    final previousStage = widget.state.pet.growthStage;
    final nextStage = widget.state.nextGrowthRequirement?.stage;
    if (nextStage == null) return;
    final name = widget.state.pet.petName ?? pet.displayName;
    setState(() => _isEvolving = true);
    try {
      await widget.petRepository.evolvePet(now: widget.state.now);
      if (!mounted) return;
      if (!kIsWeb && !MediaQuery.disableAnimationsOf(context)) {
        HapticFeedback.lightImpact();
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _EvolutionCelebrationScreen(
            pet: pet,
            petName: name,
            oldStage: previousStage,
            newStage: nextStage,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not evolve Study Buddy: $error')),
      );
    } finally {
      if (mounted) setState(() => _isEvolving = false);
    }
  }
}

class _GrowthStatus extends StatelessWidget {
  const _GrowthStatus({
    required this.state,
    required this.pet,
    required this.petName,
    required this.isEvolving,
    required this.onEvolve,
  });

  final StudyPetViewState state;
  final StudyPetDefinition pet;
  final String petName;
  final bool isEvolving;
  final VoidCallback? onEvolve;

  @override
  Widget build(BuildContext context) {
    final requirement = state.nextGrowthRequirement;
    final accent = Color(pet.primaryColor);
    if (state.isFinalGrowthStage || requirement == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FINAL FORM',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            pet.stageName(StudyPetGrowthStage.adult),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          const Text('Your Study Buddy has fully grown!'),
          const SizedBox(height: 12),
          const Text('Growth progress: Complete'),
        ],
      );
    }
    if (!state.hasGrowthBaseline) {
      return const Text('Preparing growth progress...');
    }
    final xpComplete = state.growthXp >= requirement.requiredXp;
    final timeComplete =
        state.elapsedSinceHatch >= requirement.requiredDuration;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pet.stageName(requirement.stage),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 12),
        _ProgressLine(
          label: 'Learning energy',
          value: '${state.cappedGrowthXp} / ${requirement.requiredXp} XP'
              '${xpComplete ? ' ✓' : ''}',
          progress: state.growthXpProgress,
          color: accent,
        ),
        const SizedBox(height: 14),
        _ProgressLine(
          label: 'Time together',
          value: '${state.cappedGrowthDays} / ${requirement.requiredDays} days'
              '${timeComplete ? ' ✓' : ''}',
          progress: state.growthTimeProgress,
          color: StudySisColors.progressAccent(context),
        ),
        const SizedBox(height: 14),
        Text(
          _growthMessage(state, requirement, petName),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (state.readyToEvolve) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isEvolving ? null : onEvolve,
              icon: isEvolving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text('Evolve $petName'),
            ),
          ),
        ],
      ],
    );
  }

  String _growthMessage(
    StudyPetViewState state,
    StudyPetGrowthRequirement requirement,
    String petName,
  ) {
    if (state.readyToEvolve) {
      return '$petName is ready for the next stage!';
    }
    if (state.growthXp >= requirement.requiredXp) {
      return '$petName has enough learning energy. Spend a little more time together!';
    }
    if (state.elapsedSinceHatch >= requirement.requiredDuration) {
      return '$petName is ready to grow, but needs ${state.remainingGrowthXp} more XP from learning.';
    }
    return '$petName needs ${state.remainingGrowthXp} more XP and ${state.remainingGrowthDays} more day${state.remainingGrowthDays == 1 ? '' : 's'} to grow.';
  }
}

class _EvolutionCelebrationScreen extends StatefulWidget {
  const _EvolutionCelebrationScreen({
    required this.pet,
    required this.petName,
    required this.oldStage,
    required this.newStage,
  });

  final StudyPetDefinition pet;
  final String petName;
  final StudyPetGrowthStage oldStage;
  final StudyPetGrowthStage newStage;

  @override
  State<_EvolutionCelebrationScreen> createState() =>
      _EvolutionCelebrationScreenState();
}

class _EvolutionCelebrationScreenState
    extends State<_EvolutionCelebrationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(widget.pet.primaryColor);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final title = '${widget.petName.toUpperCase()} EVOLVED!';
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = reducedMotion ? 1.0 : _controller.value;
            final reveal = Curves.easeOut.transform(progress.clamp(0, 1));
            final petScale = reducedMotion
                ? 1.0
                : 0.84 +
                    Curves.elasticOut.transform(
                          ((progress - 0.15) / 0.65).clamp(0, 1),
                        ) *
                        0.22;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              decoration: StudySisDecorations.softAccentSurface(
                context,
                accent: accent,
                surface: Theme.of(context).colorScheme.surface,
                radius: 0,
              ),
              child: Opacity(
                opacity: reveal,
                child: Column(
                  children: [
                    const Spacer(),
                    SizedBox(
                      height: 230,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          for (var i = 0; i < 10; i++)
                            Transform.rotate(
                              angle: i * 0.62,
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  -80 *
                                      Curves.easeOut.transform(
                                        ((progress - 0.20) / 0.55).clamp(0, 1),
                                      ),
                                ),
                                child: Icon(
                                  _particleIcon(),
                                  color: accent.withValues(alpha: 0.34),
                                  size: 16 + (i % 3) * 3,
                                ),
                              ),
                            ),
                          Transform.scale(
                            scale: petScale,
                            child: StudyPetCompanionVisual(
                              pet: widget.pet,
                              growthStage: widget.newStage,
                              size: 170,
                              idleValue: progress,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: accent,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.pet.stageName(widget.newStage),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your learning helped ${widget.petName} grow!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: progress >= 0.65 || reducedMotion
                            ? () => Navigator.of(context).pop()
                            : null,
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _particleIcon() {
    return switch (widget.pet.id) {
      StudyPetId.fox => Icons.local_fire_department_rounded,
      StudyPetId.bunny => Icons.eco_rounded,
      StudyPetId.cat => Icons.star_rounded,
    };
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: StudySisDecorations.softAccentSurface(
          context,
          accent: accent,
          surface: Color.lerp(
                accent,
                Theme.of(context).colorScheme.surface,
                StudySisColors.isDark(context) ? 0.80 : 0.88,
              ) ??
              Theme.of(context).colorScheme.surface,
          radius: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 8,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            color: color,
          ),
        ),
      ],
    );
  }
}
