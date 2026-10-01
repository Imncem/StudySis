import 'package:flutter/material.dart';

import '../models/engagement.dart';
import '../models/learning_content.dart';
import '../models/muffin_wallet.dart';
import '../models/page_translation.dart';
import '../models/saved_flashcard.dart';
import '../models/student.dart';
import '../models/study_pet.dart';
import '../models/subject.dart';
import '../repositories/engagement_repository.dart';
import '../repositories/learning_repository.dart';
import '../repositories/student_progress_repository.dart';
import '../repositories/study_pet_repository.dart';
import '../services/firestore_service.dart';
import '../services/muffin_context_registry.dart';
import '../services/muffin_wallet_service.dart';
import '../services/saved_flashcard_service.dart';
import '../theme/app_theme.dart';
import '../widgets/page_translation_scope.dart';
import '../widgets/study_pet_visuals.dart';
import '../widgets/studysis_decorative_background.dart';
import 'progress_screen.dart';
import 'saved_flashcards_screen.dart';
import 'study_pet_screen.dart';
import 'subject_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    this.firestoreService,
    this.learningRepository,
    this.walletService,
    this.savedFlashcardService,
    this.engagementRepository,
    this.progressRepository,
    this.petRepository,
    this.studentStream,
    this.subjectsStream,
    this.nowProvider,
    super.key,
  });

  final FirestoreService? firestoreService;
  final LearningRepository? learningRepository;
  final MuffinWalletService? walletService;
  final SavedFlashcardService? savedFlashcardService;
  final EngagementRepository? engagementRepository;
  final StudentProgressRepository? progressRepository;
  final StudyPetRepository? petRepository;
  final Stream<Student>? studentStream;
  final Stream<List<Subject>>? subjectsStream;
  final DateTime Function()? nowProvider;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _translationOwner = Object();
  late final LearningRepository _learningRepository;
  late final MuffinWalletService _walletService;
  late final SavedFlashcardService _savedFlashcardService;
  late final EngagementRepository _engagementRepository;
  late final StudentProgressRepository _progressRepository;
  late final StudyPetRepository _petRepository;
  late Future<LearningContent?> _nextContent;
  bool _isOpeningModule = false;
  bool _petUnlockPromptShowing = false;
  bool _petUnlockPromptShownThisSession = false;

  @override
  void initState() {
    super.initState();
    _learningRepository = widget.learningRepository ?? LearningRepository();
    _walletService =
        widget.walletService ?? MuffinWalletServiceFactory.create();
    _savedFlashcardService =
        widget.savedFlashcardService ?? SavedFlashcardServiceFactory.create();
    _engagementRepository =
        widget.engagementRepository ?? EngagementRepository();
    _progressRepository =
        widget.progressRepository ?? StudentProgressRepository();
    _petRepository = widget.petRepository ?? StudyPetRepository();
    MuffinContextRegistry.instance.resetToHome();
    _nextContent = _learningRepository.getFirstAvailableContent();
  }

  Future<void> _refresh() async {
    final nextContent = _learningRepository.getFirstAvailableContent();
    setState(() {
      _nextContent = nextContent;
    });
    await nextContent;
  }

  Future<void> _continueLearning() async {
    if (_isOpeningModule) return;
    setState(() => _isOpeningModule = true);
    try {
      final content = await _learningRepository.getFirstAvailableContent();
      if (!mounted) return;
      setState(() {
        _nextContent = Future.value(content);
      });
      if (content == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Learning modules are being prepared.'),
          ),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SubjectScreen(
            subject: Subject(
              id: 'math',
              displayName: content.subjectName,
              shortName: content.subjectName,
              contentStatus: 'available',
              iconName: 'math',
              themeColor: '#496A5A',
              order: 1,
            ),
            repository: _learningRepository,
            progressRepository: _progressRepository,
            engagementRepository: _engagementRepository,
            petRepository: _petRepository,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the module: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningModule = false);
    }
  }

  void _registerTranslationContent(BuildContext context) {
    final controller = PageTranslationScope.maybeOf(context);
    if (controller == null) return;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      controller.registerPage(
        ownerToken: _translationOwner,
        routeName: ModalRoute.of(context)?.settings.name,
        content: const TranslatablePageContent(
          pageType: 'home',
          pageId: 'home_dashboard',
          sourceLanguage: TranslationLanguage.english,
          fields: [
            PageTranslationField(
              id: 'greeting',
              type: 'heading',
              text: 'Hi Qidah',
            ),
            PageTranslationField(
              id: 'encouragement',
              type: 'paragraph',
              text: "Let's take one gentle step today.",
            ),
            PageTranslationField(
              id: 'continueTitle',
              type: 'heading',
              text: 'Continue learning',
            ),
            PageTranslationField(
              id: 'myDayTitle',
              type: 'heading',
              text: 'My Day',
            ),
            PageTranslationField(
              id: 'muffinBitesTitle',
              type: 'heading',
              text: 'Muffin Bites',
            ),
            PageTranslationField(
              id: 'savedFlashcardsTitle',
              type: 'heading',
              text: 'Saved Flashcards',
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StudySisDecorativeBackground(
        density: StudySisPatternDensity.medium,
        child: SafeArea(
          child: StreamBuilder<Student>(
            stream: widget.studentStream ??
                (widget.firestoreService ?? FirestoreService()).watchQidah(),
            builder: (context, studentSnapshot) {
              if (studentSnapshot.hasError) {
                return _ErrorState(message: studentSnapshot.error.toString());
              }
              if (!studentSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              _registerTranslationContent(context);
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  children: [
                    const PageTranslationBanner(),
                    const _HomeGreetingHero(),
                    const SizedBox(height: 22),
                    _MyDayCard(
                      engagementRepository: _engagementRepository,
                      walletService: _walletService,
                      petRepository: _petRepository,
                      continueContent: _nextContent,
                      isOpeningContinue: _isOpeningModule,
                      nowProvider: widget.nowProvider,
                      onUnlockedUnacknowledged: _showPetUnlockCelebration,
                      onContinueLearning: _continueLearning,
                      onOpenProgress: _openProgress,
                      onOpenStudyPet: _openStudyPet,
                    ),
                    const SizedBox(height: 14),
                    _SavedFlashcardsDashboardSection(
                      savedFlashcardService: _savedFlashcardService,
                      learningRepository: _learningRepository,
                      engagementRepository: _engagementRepository,
                      petRepository: _petRepository,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openProgress() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProgressScreen(
          learningRepository: _learningRepository,
          progressRepository: _progressRepository,
          engagementRepository: _engagementRepository,
          petRepository: _petRepository,
        ),
      ),
    );
  }

  Future<void> _openStudyPet() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: StudyPetScreen.routeName),
        builder: (_) => StudyPetScreen(
          engagementRepository: _engagementRepository,
          petRepository: _petRepository,
          nowProvider: widget.nowProvider,
        ),
      ),
    );
  }

  Future<void> _showPetUnlockCelebration() async {
    if (_petUnlockPromptShowing || _petUnlockPromptShownThisSession) return;
    _petUnlockPromptShowing = true;
    _petUnlockPromptShownThisSession = true;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 NEW FEATURE UNLOCKED'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Study Pets',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            SizedBox(height: 10),
            Text("You've reached Level 3!"),
            SizedBox(height: 8),
            Text(
              'Choose a mystery egg and raise a Study Buddy by learning together.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('later'),
            child: const Text('Maybe Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('choose'),
            child: const Text('Choose My Egg'),
          ),
        ],
      ),
    );
    try {
      await _petRepository.acknowledgeUnlock();
    } finally {
      _petUnlockPromptShowing = false;
    }
    if (!mounted) return;
    if (action == 'choose') {
      await _openStudyPet();
    }
  }
}

class _HomeGreetingHero extends StatelessWidget {
  const _HomeGreetingHero();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surface.withValues(alpha: 0.90),
            Color.lerp(
                  StudySisColors.progressSurface(context),
                  scheme.surface,
                  0.42,
                ) ??
                scheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: const StudySisDecorativeBackground(
        hero: true,
        density: StudySisPatternDensity.low,
        child: _HomeGreetingText(),
      ),
    );
  }
}

class _HomeGreetingText extends StatelessWidget {
  const _HomeGreetingText();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          PageTranslationScope.text(context, 'greeting', 'Hi Qidah'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(
          PageTranslationScope.text(
            context,
            'encouragement',
            "Let's take one gentle step today.",
          ),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _MyDayCard extends StatelessWidget {
  const _MyDayCard({
    required this.engagementRepository,
    required this.walletService,
    required this.petRepository,
    required this.continueContent,
    required this.isOpeningContinue,
    required this.onOpenProgress,
    required this.onOpenStudyPet,
    required this.onContinueLearning,
    required this.onUnlockedUnacknowledged,
    required this.nowProvider,
  });

  final EngagementRepository engagementRepository;
  final MuffinWalletService walletService;
  final StudyPetRepository petRepository;
  final Future<LearningContent?> continueContent;
  final bool isOpeningContinue;
  final VoidCallback onOpenProgress;
  final VoidCallback onOpenStudyPet;
  final VoidCallback onContinueLearning;
  final VoidCallback onUnlockedUnacknowledged;
  final DateTime Function()? nowProvider;

  DateTime get _now => nowProvider?.call() ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<EngagementState>(
      stream: engagementRepository.watchState(),
      initialData: EngagementState.initial('today'),
      builder: (context, engagementSnapshot) {
        final engagement =
            engagementSnapshot.data ?? EngagementState.initial('today');
        return StreamBuilder<MuffinWallet>(
          stream: walletService.watchWallet(),
          initialData: MuffinWallet.full,
          builder: (context, walletSnapshot) {
            final wallet = walletSnapshot.data ?? MuffinWallet.full;
            return StreamBuilder<StudyPetState>(
              stream: petRepository.watchState(),
              initialData: StudyPetState.empty,
              builder: (context, petSnapshot) {
                final pet = petSnapshot.data ?? StudyPetState.empty;
                final petState = StudyPetViewState(
                  engagement: engagement,
                  pet: pet,
                  now: _now,
                );
                if (petState.shouldShowUnlockCelebration) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onUnlockedUnacknowledged();
                  });
                }
                return Card(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          PageTranslationScope.text(
                            context,
                            'myDayTitle',
                            'My Day',
                          ),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _MyDayStatusTile(
                                icon: Icons.local_fire_department_rounded,
                                iconColor: StudySisColors.streakAccent(context),
                                surfaceColor:
                                    StudySisColors.streakSurface(context),
                                emphasize: engagement.currentStreak > 0,
                                label: 'Streak',
                                value: '${engagement.currentStreak} day streak',
                                subtitle: engagement.todayStreakSecured
                                    ? 'Secured today'
                                    : 'Keep it going',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MyDayStatusTile(
                                icon: Icons.cookie_rounded,
                                iconColor: StudySisColors.muffinAccent(context),
                                surfaceColor:
                                    StudySisColors.muffinSurface(context),
                                showCrumbs: true,
                                label: 'Muffin Bites',
                                value:
                                    '\u{1F36A} ${wallet.currentBites} / ${wallet.maxBites}',
                                subtitle: _muffinStatusText(wallet),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _MyDayProgressSection(
                          label: "Today's Goal",
                          value:
                              '${engagement.clampedTodayStudyPoints} / ${engagement.dailyStudyTarget}',
                          progress: engagement.dailyStudyTarget <= 0
                              ? 1
                              : engagement.clampedTodayStudyPoints /
                                  engagement.dailyStudyTarget,
                          message: _goalMessage(engagement),
                          barColor: engagement.todayStreakSecured
                              ? StudySisColors.progressAccent(context)
                              : scheme.primary,
                          leadingIcon: engagement.todayStreakSecured
                              ? Icons.check_circle_rounded
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _MyDayProgressSection(
                          label: 'Level ${engagement.level}',
                          value:
                              '${engagement.totalXp} / ${engagement.xpForNextLevel} XP',
                          progress: engagement.levelProgress,
                          barColor: StudySisColors.xpAccent(context),
                          leadingIcon: Icons.star_rounded,
                        ),
                        if (engagement.level < petUnlockLevel) ...[
                          const SizedBox(height: 14),
                          _MyDayStudyBuddyRow(
                            state: petState,
                            onTap: onOpenStudyPet,
                          ),
                        ],
                        const SizedBox(height: 10),
                        _MyDayContinueLearningRow(
                          content: continueContent,
                          isOpening: isOpeningContinue,
                          onTap: onContinueLearning,
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: onOpenProgress,
                            icon: const Icon(Icons.insights_rounded),
                            label: const Text('View Progress'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _goalMessage(EngagementState state) {
    if (state.todayStreakSecured ||
        state.todayStudyPoints >= state.dailyStudyTarget) {
      return "Today's streak is secured!";
    }
    return 'Complete a learning activity to keep your streak going.';
  }

  String _muffinStatusText(MuffinWallet wallet) {
    if (wallet.isDailyLimitReached) {
      return 'Muffin is resting for today. More help will be available after the daily reset.';
    }
    if (!wallet.hasBites) {
      return 'Muffin is recharging. Check back a little later.';
    }
    if (wallet.currentBites == 1) {
      return 'Muffin is getting a little tired.';
    }
    return 'Muffin is ready to help!';
  }
}

class _MyDayStatusTile extends StatelessWidget {
  const _MyDayStatusTile({
    required this.icon,
    required this.iconColor,
    required this.surfaceColor,
    required this.label,
    required this.value,
    required this.subtitle,
    this.emphasize = false,
    this.showCrumbs = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color surfaceColor;
  final String label;
  final String value;
  final String subtitle;
  final bool emphasize;
  final bool showCrumbs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: StudySisDecorations.softAccentSurface(
        context,
        accent: iconColor,
        surface: surfaceColor,
      ),
      child: Stack(
        children: [
          if (showCrumbs) ...[
            Positioned(
              right: 8,
              top: 4,
              child: _TinyDot(color: iconColor.withValues(alpha: 0.22)),
            ),
            Positioned(
              right: 25,
              bottom: 5,
              child: _TinyDot(color: iconColor.withValues(alpha: 0.16)),
            ),
          ],
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: emphasize
                      ? [
                          BoxShadow(
                            color: iconColor.withValues(alpha: 0.26),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: iconColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TinyDot extends StatelessWidget {
  const _TinyDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _GradientProgressBar extends StatelessWidget {
  const _GradientProgressBar({
    required this.value,
    required this.color,
  });

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = value.clamp(0, 1).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: 7,
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: clamped,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color,
                  Color.lerp(
                        color,
                        StudySisColors.xpAccent(context),
                        0.36,
                      ) ??
                      color,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MyDayProgressSection extends StatelessWidget {
  const _MyDayProgressSection({
    required this.label,
    required this.value,
    required this.progress,
    this.message,
    this.barColor,
    this.leadingIcon,
  });

  final String label;
  final String value;
  final double progress;
  final String? message;
  final Color? barColor;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(
                leadingIcon,
                size: 16,
                color: barColor ?? scheme.primary,
              ),
              const SizedBox(width: 5),
            ],
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
        _GradientProgressBar(
          value: progress,
          color: barColor ?? scheme.primary,
        ),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(message!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _MyDayStudyBuddyRow extends StatelessWidget {
  const _MyDayStudyBuddyRow({
    required this.state,
    required this.onTap,
  });

  final StudyPetViewState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = _details();
    final accent = StudySisColors.studyPetAccent(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: StudySisDecorations.softAccentSurface(
          context,
          accent: accent,
          surface: StudySisColors.studyPetSurface(context),
        ),
        child: Row(
          children: [
            SizedBox(width: 46, child: Center(child: details.visual)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR STUDY BUDDY',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    details.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (details.meta != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      details.meta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              details.action,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  _StudyBuddyDetails _details() {
    final pet = state.pet.pet;
    final egg = state.pet.egg;
    if (!state.isUnlocked) {
      return _StudyBuddyDetails(
        visual: const Icon(
          Icons.lock_rounded,
          color: Color(0xFF496A5A),
          size: 30,
        ),
        title: '\u{1F512} Study Pets',
        subtitle: 'Unlock at Level 3 - ${state.xpToUnlock} XP to go',
        meta: '\u{2B50} ${state.xpTowardUnlock} / $petUnlockXp XP',
        action: 'View',
      );
    }
    if (state.pet.stage == StudyPetStage.hatchling && pet != null) {
      final requirement = state.nextGrowthRequirement;
      return _StudyBuddyDetails(
        visual: StudyPetAvatar(
          pet: pet,
          growthStage: state.pet.growthStage,
          size: 42,
        ),
        title: '${pet.icon} ${state.pet.petName ?? pet.displayName}',
        subtitle: state.isFinalGrowthStage
            ? '${pet.stageName(state.pet.growthStage)} · Final Form'
            : state.readyToEvolve
                ? 'Ready to evolve!'
                : requirement == null
                    ? 'Growing with you.'
                    : '${state.cappedGrowthXp} / ${requirement.requiredXp} growth XP',
        action: 'View',
      );
    }
    if (state.pet.stage == StudyPetStage.egg && egg != null) {
      return _StudyBuddyDetails(
        visual: StudyEggAvatar(egg: egg, size: 42),
        title: egg.displayName,
        subtitle: state.readyToHatch
            ? 'Ready to hatch!'
            : '${state.cappedHatchXp} / ${state.pet.hatchXpTarget} XP - Growing',
        action: 'View',
      );
    }
    return _StudyBuddyDetails(
      visual: const Icon(
        Icons.egg_alt_rounded,
        color: Color(0xFFA45E37),
        size: 30,
      ),
      title: '\u{1F381} Study Pets Unlocked!',
      subtitle: 'Ready! Choose your mystery egg',
      action: 'Choose Egg',
    );
  }
}

class _MyDayContinueLearningRow extends StatelessWidget {
  const _MyDayContinueLearningRow({
    required this.content,
    required this.isOpening,
    required this.onTap,
  });

  final Future<LearningContent?> content;
  final bool isOpening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LearningContent?>(
      future: content,
      builder: (context, snapshot) {
        final learningContent = snapshot.data;
        final subjectTheme = StudySisSubjectTheme.forSubject(
          id: learningContent?.subjectName ?? 'math',
          displayName: learningContent?.subjectName,
        );
        final accent = subjectTheme.accent(context);
        final soft = subjectTheme.softSurface(context);
        final hasError = snapshot.hasError;
        final title = learningContent == null
            ? 'Learning modules'
            : 'Chapter ${learningContent.chapter.chapterNumber} - '
                '${learningContent.module.title}';
        final subtitle = snapshot.connectionState == ConnectionState.waiting
            ? 'Finding your next module...'
            : hasError
                ? 'Could not check modules'
                : learningContent == null
                    ? 'Being prepared'
                    : '${learningContent.module.typeLabel} - '
                        '${learningContent.module.estimatedMinutes} min';
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isOpening ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color.lerp(
                soft,
                Theme.of(context).colorScheme.surface,
                StudySisColors.isDark(context) ? 0.18 : 0.38,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 9),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Continue Learning',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOpening ? 'Opening...' : subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: accent),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StudyBuddyDetails {
  const _StudyBuddyDetails({
    required this.visual,
    required this.title,
    required this.subtitle,
    required this.action,
    this.meta,
  });

  final Widget visual;
  final String title;
  final String subtitle;
  final String action;
  final String? meta;
}

class _SavedFlashcardsDashboardSection extends StatelessWidget {
  const _SavedFlashcardsDashboardSection({
    required this.savedFlashcardService,
    required this.learningRepository,
    required this.engagementRepository,
    required this.petRepository,
  });

  final SavedFlashcardService savedFlashcardService;
  final LearningRepository learningRepository;
  final EngagementRepository engagementRepository;
  final StudyPetRepository petRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SavedFlashcardRef>>(
      stream: savedFlashcardService.watchSavedFlashcards(),
      initialData: const <SavedFlashcardRef>[],
      builder: (context, snapshot) {
        final refs = snapshot.data ?? const <SavedFlashcardRef>[];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SavedFlashcardsScreen(
                    learningRepository: learningRepository,
                    savedFlashcardService: savedFlashcardService,
                    engagementRepository: engagementRepository,
                    petRepository: petRepository,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          PageTranslationScope.text(
                            context,
                            'savedFlashcardsTitle',
                            'Saved Flashcards',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Text(
                        'View all',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.bookmark_rounded,
                        color: Color(0xFFA45E37),
                      ),
                      const SizedBox(width: 8),
                      Text('${refs.length} saved flashcards'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    refs.isEmpty
                        ? "Save useful cards while studying and they'll appear here."
                        : 'Ready for a quick review.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 16),
            Text('We could not load StudySis',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
