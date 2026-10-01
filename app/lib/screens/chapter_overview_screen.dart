import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../models/flashcard.dart';
import '../models/engagement.dart';
import '../models/learning_content.dart';
import '../models/practice_question.dart';
import '../models/quiz_question.dart';
import '../models/study_pet.dart';
import '../repositories/learning_repository.dart';
import '../models/chapter_progress.dart';
import '../repositories/engagement_repository.dart';
import '../repositories/student_progress_repository.dart';
import '../repositories/study_pet_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/xp_reward_overlay.dart';
import 'streak_celebration_screen.dart';
import 'flashcard_screen.dart';
import 'level_up_screen.dart';
import 'module_reader_screen.dart';
import 'practice_screen.dart';
import 'quiz_screen.dart';
import 'study_pet_screen.dart';

class ChapterOverviewScreen extends StatefulWidget {
  const ChapterOverviewScreen({
    required this.subjectId,
    required this.subjectName,
    required this.chapter,
    this.repository,
    this.progressRepository,
    this.engagementRepository,
    this.petRepository,
    super.key,
  });

  final String subjectId;
  final String subjectName;
  final Chapter chapter;
  final LearningRepository? repository;
  final StudentProgressRepository? progressRepository;
  final EngagementRepository? engagementRepository;
  final StudyPetRepository? petRepository;

  @override
  State<ChapterOverviewScreen> createState() => _ChapterOverviewScreenState();
}

class _ChapterOverviewScreenState extends State<ChapterOverviewScreen> {
  late final LearningRepository _repository;
  late final StudentProgressRepository _progressRepository;
  late final EngagementRepository _engagementRepository;
  late final StudyPetRepository _petRepository;
  late Future<_ChapterJourneyData> _journey;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LearningRepository();
    _progressRepository =
        widget.progressRepository ?? StudentProgressRepository();
    _engagementRepository =
        widget.engagementRepository ?? EngagementRepository();
    _petRepository = widget.petRepository ?? StudyPetRepository();
    _journey = _loadJourney();
  }

  Future<_ChapterJourneyData> _loadJourney() async {
    final notes = await _repository.getChapterNotesContent(
      subjectId: widget.subjectId,
      chapterId: widget.chapter.id,
    );
    final flashcards = await _repository.getActiveFlashcards(
      widget.chapter.id,
      subjectId: widget.subjectId,
    );
    final practiceQuestions = await _repository.getPublishedPracticeQuestions(
      subjectId: widget.subjectId,
      chapterId: widget.chapter.id,
    );
    final quizQuestions = await _repository.getActiveQuizQuestions(
      subjectId: widget.subjectId,
      chapterId: widget.chapter.id,
    );
    return _ChapterJourneyData(
      notes: notes,
      flashcards: flashcards,
      practiceQuestions: practiceQuestions,
      quizQuestions: quizQuestions,
    );
  }

  void _reload() {
    setState(() {
      _journey = _loadJourney();
    });
  }

  Future<void> _openLearn(
    LearningContent? notes,
    List<Flashcard> flashcards,
  ) async {
    if (notes == null) {
      _showComingSoon('Learn is being prepared.');
      return;
    }
    final action = await Navigator.of(context).push<ModuleReaderExitAction>(
      MaterialPageRoute<ModuleReaderExitAction>(
        settings: const RouteSettings(name: ModuleReaderScreen.routeName),
        builder: (_) => ModuleReaderScreen(learningContent: notes),
      ),
    );
    if (!mounted) return;
    final saved = await _persistProgress(
      () => _progressRepository.markLearnCompleted(
        subjectId: widget.subjectId,
        chapterId: widget.chapter.id,
      ),
      savedMessage: 'Learn progress saved.',
    );
    if (saved) {
      await _handleEngagementReward(
        activity: 'learn',
        message: 'Lesson complete!',
        credit: () => _engagementRepository.creditLearnCompletion(
          subjectId: widget.subjectId,
          chapterId: widget.chapter.id,
        ),
      );
    }
    if (!saved || action != ModuleReaderExitAction.goToFlashcards || !mounted) {
      return;
    }
    final latestProgress = await _progressRepository.getChapterProgress(
      subjectId: widget.subjectId,
      chapterId: widget.chapter.id,
    );
    if (!mounted) return;
    await _openFlashcards(flashcards, latestProgress);
  }

  Future<void> _openFlashcards(
    List<Flashcard> cards,
    ChapterProgress progress,
  ) async {
    final masteredIds = progress.masteredFlashcardIds.toSet();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: FlashcardScreen.routeName),
        builder: (_) => FlashcardScreen(
          subjectId: widget.subjectId,
          subjectName: widget.subjectName,
          chapter: widget.chapter,
          initialCompletedCardIds: masteredIds,
          onCardCompleted: (cardId) async {
            masteredIds.add(cardId);
            final saved = await _persistProgress(
              () => _progressRepository.updateFlashcardProgress(
                subjectId: widget.subjectId,
                chapterId: widget.chapter.id,
                masteredCount: masteredIds.length,
                totalCount: cards.length,
                masteredCardIds: masteredIds.toList(),
              ),
            );
            if (!saved) return;
            await _handleEngagementReward(
              activity: 'flashcards',
              message: 'Flashcards reviewed!',
              credit: () => _engagementRepository.creditFlashcardReview(
                subjectId: widget.subjectId,
                chapterId: widget.chapter.id,
                reviewedCardIds: masteredIds,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openPractice(
    List<PracticeQuestion> questions,
    ChapterProgress progress,
  ) async {
    if (!progress.flashcardsCompleted) {
      _showComingSoon('Finish Flashcards first to unlock Practice.');
      return;
    }
    if (questions.isEmpty) {
      _showComingSoon('Practice questions coming soon.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: PracticeScreen.routeName),
        builder: (_) => PracticeScreen(
          title: 'Chapter ${widget.chapter.chapterNumber} Practice',
          subjectId: widget.subjectId,
          subjectTitle: widget.subjectName,
          chapterId: widget.chapter.id,
          chapterTitle: widget.chapter.title,
          questionsFuture: Future.value(questions),
          onComplete: (result) async {
            final saved = await _persistProgress(
              () => _progressRepository.recordPracticeResult(
                subjectId: widget.subjectId,
                chapterId: widget.chapter.id,
                result: result,
              ),
              savedMessage: 'Practice progress saved.',
            );
            if (!saved) return;
            await _handleEngagementReward(
              activity: 'practice',
              message: 'Practice complete!',
              credit: () => _engagementRepository.creditPracticeQuestions(
                subjectId: widget.subjectId,
                chapterId: widget.chapter.id,
                completedQuestionCount: result.totalQuestions,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openQuiz(
    List<QuizQuestion> questions,
    ChapterProgress progress,
  ) async {
    if (!progress.practiceCompleted) {
      _showComingSoon('Finish Practice first to unlock Quiz.');
      return;
    }
    if (questions.isEmpty) {
      _showComingSoon('Quiz questions coming soon.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: QuizScreen.routeName),
        builder: (_) => QuizScreen(
          chapter: widget.chapter,
          subjectId: widget.subjectId,
          subjectTitle: widget.subjectName,
          title: 'Chapter ${widget.chapter.chapterNumber} Quiz',
          questionsFuture: Future.value(questions),
          onComplete: (result) async {
            final saved = await _persistProgress(
              () => _progressRepository.recordQuizResult(
                subjectId: widget.subjectId,
                chapterId: widget.chapter.id,
                result: result,
              ),
              savedMessage: 'Quiz progress saved.',
            );
            if (!saved) return;
            await _handleEngagementReward(
              activity: 'quiz',
              message: 'Quiz complete!',
              credit: () => _engagementRepository.creditQuizCompletion(
                subjectId: widget.subjectId,
                chapterId: widget.chapter.id,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleEngagementReward({
    required String activity,
    required String message,
    required Future<EngagementCreditResult> Function() credit,
  }) async {
    try {
      final result = await credit();
      if (result.xpAwarded > 0) {
        debugPrint(
          '[StudySis][engagement] XP AWARD '
          'activity=$activity '
          'awardedXp=${result.xpAwarded} '
          'previousXp=${result.previousTotalXp} '
          'newXp=${result.newTotalXp} '
          'previousLevel=${result.previousLevel} '
          'newLevel=${result.newLevel}',
        );
      }
      if (!mounted) return;
      await XpRewardOverlay.show(
        context,
        awardedXp: result.xpAwarded,
        message: message,
      );
      if (!mounted) return;
      if (result.streakNewlySecured) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StreakCelebrationScreen(
              streakDays: result.state.currentStreak,
              xpReward: result.xpAwarded > 0 ? result.xpAwarded : null,
            ),
          ),
        );
      }
      if (!mounted || !result.levelUp) return;
      await _showLevelUp(result);
    } catch (error, stackTrace) {
      debugPrint('[StudySis][engagement] credit failed: $error');
      debugPrint('[StudySis][engagement] stackTrace=$stackTrace');
    }
  }

  Future<void> _showLevelUp(EngagementCreditResult result) async {
    final unlocksStudyPets = result.previousLevel < petUnlockLevel &&
        result.newLevel >= petUnlockLevel;
    final action = await Navigator.of(context).push<LevelUpAction>(
      MaterialPageRoute<LevelUpAction>(
        builder: (_) => LevelUpScreen(
          newLevel: result.newLevel,
          totalXp: result.newTotalXp,
          unlocksStudyPets: unlocksStudyPets,
        ),
      ),
    );
    if (!mounted || !unlocksStudyPets) return;
    try {
      await _petRepository.acknowledgeUnlock();
    } catch (error, stackTrace) {
      debugPrint('[StudySis][pet] unlock acknowledgement failed: $error');
      debugPrint('[StudySis][pet] stackTrace=$stackTrace');
    }
    if (!mounted || action?.wantsChoosePet != true) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: StudyPetScreen.routeName),
        builder: (_) => StudyPetScreen(
          engagementRepository: _engagementRepository,
          petRepository: _petRepository,
        ),
      ),
    );
  }

  Future<bool> _persistProgress(
    Future<void> Function() write, {
    String? savedMessage,
  }) async {
    try {
      await write();
      if (!mounted || savedMessage == null) return true;
      _showComingSoon(savedMessage);
      return true;
    } catch (error, stackTrace) {
      debugPrint('[StudySis][progress][overview] save failed: $error');
      debugPrint('[StudySis][progress][overview] stackTrace=$stackTrace');
      if (!mounted) return false;
      _showComingSoon('Progress could not be saved. Please try again.');
      return false;
    }
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final subjectTheme = StudySisSubjectTheme.forSubject(
      id: widget.subjectId,
      displayName: widget.subjectName,
    );
    final accent = subjectTheme.accent(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Chapter Overview'),
      ),
      body: SafeArea(
        child: FutureBuilder<_ChapterJourneyData>(
          future: _journey,
          builder: (context, snapshot) {
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;
            final data = snapshot.data;
            final hasLearn = data?.notes != null;
            final flashcardTotal = data?.flashcards.length ?? 0;
            final practiceTotal = data?.practiceQuestions.length ?? 0;
            final quizTotal = data?.quizQuestions.length ?? 0;

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: StreamBuilder<ChapterProgress>(
                stream: _progressRepository.streamChapterProgress(
                  subjectId: widget.subjectId,
                  chapterId: widget.chapter.id,
                ),
                builder: (context, progressSnapshot) {
                  final progress = progressSnapshot.data ??
                      ChapterProgress.empty(
                        subjectId: widget.subjectId,
                        chapterId: widget.chapter.id,
                      );
                  final progressValue = progress.overallProgress / 100;
                  final learnCompleted = progress.learnCompleted;
                  final flashcardsCompleted = progress.flashcardsCompleted;
                  final practiceCompleted = progress.practiceCompleted;
                  final quizCompleted = progress.quizCompleted;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: StudySisDecorations.playfulCard(
                          context,
                          subjectTheme,
                          radius: 26,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Center(
                                child: Text(
                                  widget.chapter.chapterNumber.toString(),
                                  style: TextStyle(
                                    color: subjectTheme.onPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.subjectName.toUpperCase(),
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Chapter ${widget.chapter.chapterNumber}: ${widget.chapter.title}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      _ProgressCard(
                        percent: progress.overallProgress,
                        progress: progressValue,
                        subjectTheme: subjectTheme,
                      ),
                      if (progressSnapshot.connectionState ==
                          ConnectionState.waiting) ...[
                        const SizedBox(height: 8),
                        const _InlineNotice(
                          message: 'Checking saved progress...',
                        ),
                      ] else if (progressSnapshot.hasError) ...[
                        const SizedBox(height: 8),
                        const _InlineNotice(
                          message:
                              'Saved progress could not load. Showing starter state.',
                        ),
                      ],
                      const SizedBox(height: 12),
                      const _MuffinCard(),
                      const SizedBox(height: 24),
                      Text(
                        'Learning Journey',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (snapshot.hasError)
                        _ErrorJourneyCard(onRetry: _reload)
                      else ...[
                        _JourneyCard(
                          icon: Icons.menu_book_rounded,
                          title: 'Learn',
                          description: 'Read and understand the lesson.',
                          subjectTheme: subjectTheme,
                          status: learnCompleted
                              ? 'Completed'
                              : hasLearn
                                  ? 'Continue'
                                  : 'Preparing',
                          onTap: () => _openLearn(
                            data?.notes,
                            data?.flashcards ?? const [],
                          ),
                        ),
                        _JourneyCard(
                          icon: Icons.psychology_rounded,
                          title: 'Flashcards',
                          description: 'Remember the important ideas.',
                          subjectTheme: subjectTheme,
                          status:
                              '${progress.flashcardsMasteredCount} / $flashcardTotal mastered',
                          locked: !learnCompleted,
                          onTap: () => learnCompleted
                              ? _openFlashcards(
                                  data?.flashcards ?? const [],
                                  progress,
                                )
                              : _showComingSoon(
                                  'Finish Learn first to unlock Flashcards.',
                                ),
                        ),
                        _JourneyCard(
                          icon: Icons.edit_note_rounded,
                          title: 'Practice',
                          description: 'Guided exercises.',
                          subjectTheme: subjectTheme,
                          status: practiceCompleted
                              ? 'Latest ${progress.practiceLatestPercentage}% · Best ${progress.practiceBestPercentage}%'
                              : flashcardsCompleted && practiceTotal > 0
                                  ? '$practiceTotal questions'
                                  : flashcardsCompleted
                                      ? 'Coming soon'
                                      : 'Locked',
                          locked: !flashcardsCompleted,
                          onTap: () => _openPractice(
                            data?.practiceQuestions ?? const [],
                            progress,
                          ),
                        ),
                        _JourneyCard(
                          icon: Icons.track_changes_rounded,
                          title: 'Quiz',
                          description: 'Timed challenge.',
                          subjectTheme: subjectTheme,
                          status: quizCompleted
                              ? 'Latest ${progress.quizLatestPercentage}% · Best ${progress.quizBestPercentage}% · ${progress.quizPassed ? 'Pass' : 'Needs Revision'}'
                              : practiceCompleted && quizTotal > 0
                                  ? '$quizTotal questions'
                                  : practiceCompleted
                                      ? 'Coming soon'
                                      : 'Locked',
                          locked: !practiceCompleted,
                          onTap: () => _openQuiz(
                            data?.quizQuestions ?? const [],
                            progress,
                          ),
                        ),
                        _JourneyCard(
                          icon: Icons.emoji_events_rounded,
                          title: 'Challenge',
                          description: 'Mixed chapter questions.',
                          subjectTheme: subjectTheme,
                          status: 'Locked',
                          locked: true,
                          onTap: () =>
                              _showComingSoon('Challenge is coming soon.'),
                        ),
                      ],
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChapterJourneyData {
  const _ChapterJourneyData({
    required this.notes,
    required this.flashcards,
    required this.practiceQuestions,
    required this.quizQuestions,
  });

  final LearningContent? notes;
  final List<Flashcard> flashcards;
  final List<PracticeQuestion> practiceQuestions;
  final List<QuizQuestion> quizQuestions;
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.percent,
    required this.progress,
    required this.subjectTheme,
  });

  final int percent;
  final double progress;
  final StudySisSubjectTheme subjectTheme;

  @override
  Widget build(BuildContext context) {
    final accent = subjectTheme.accent(context);
    return Card(
      child: Container(
        decoration: StudySisDecorations.playfulCard(context, subjectTheme),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Overall chapter progress',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '$percent%',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.65),
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MuffinCard extends StatelessWidget {
  const _MuffinCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            Text('🐶', style: TextStyle(fontSize: 34)),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                "Ready for today's lesson?",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.subjectTheme,
    required this.status,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final StudySisSubjectTheme subjectTheme;
  final String status;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final accent = subjectTheme.accent(context);
    final soft = subjectTheme.softSurface(context);
    final mutedColor = locked ? const Color(0xFF8A918B) : accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: locked ? const Color(0xFFF1EFEA) : soft,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(icon, color: mutedColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      _StatusBadge(
                        label: status,
                        locked: locked,
                        subjectTheme: subjectTheme,
                      ),
                    ],
                  ),
                ),
                Icon(
                  locked
                      ? Icons.lock_outline_rounded
                      : Icons.chevron_right_rounded,
                  color: mutedColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.locked,
    required this.subjectTheme,
  });

  final String label;
  final bool locked;
  final StudySisSubjectTheme subjectTheme;

  @override
  Widget build(BuildContext context) {
    final accent = subjectTheme.accent(context);
    final soft = subjectTheme.softSurface(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: locked ? const Color(0xFFF1EFEA) : soft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: locked ? const Color(0xFF756F66) : accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorJourneyCard extends StatelessWidget {
  const _ErrorJourneyCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42),
            const SizedBox(height: 12),
            const Text('We could not load this chapter right now.'),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
