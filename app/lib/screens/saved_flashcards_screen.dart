import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../models/engagement.dart';
import '../models/flashcard.dart';
import '../models/muffin.dart';
import '../models/saved_flashcard.dart';
import '../models/study_pet.dart';
import '../repositories/engagement_repository.dart';
import '../repositories/learning_repository.dart';
import '../repositories/study_pet_repository.dart';
import '../services/muffin_context_registry.dart';
import '../services/saved_flashcard_service.dart';
import '../widgets/muffin_assist_sheet.dart';
import '../widgets/xp_reward_overlay.dart';
import 'level_up_screen.dart';
import 'streak_celebration_screen.dart';
import 'study_pet_screen.dart';

class SavedFlashcardsScreen extends StatefulWidget {
  const SavedFlashcardsScreen({
    this.learningRepository,
    this.savedFlashcardService,
    this.engagementRepository,
    this.petRepository,
    super.key,
  });

  final LearningRepository? learningRepository;
  final SavedFlashcardService? savedFlashcardService;
  final EngagementRepository? engagementRepository;
  final StudyPetRepository? petRepository;

  @override
  State<SavedFlashcardsScreen> createState() => _SavedFlashcardsScreenState();
}

class _SavedFlashcardsScreenState extends State<SavedFlashcardsScreen> {
  late final LearningRepository _learningRepository;
  late final SavedFlashcardService _savedFlashcardService;
  late final EngagementRepository _engagementRepository;
  late final StudyPetRepository _petRepository;
  final _pageController = PageController();
  final Set<String> _revealed = {};
  final Set<String> _reviewedSavedCards = {};
  int _currentIndex = 0;
  String? _registeredContextKey;

  @override
  void initState() {
    super.initState();
    _learningRepository = widget.learningRepository ?? LearningRepository();
    _savedFlashcardService =
        widget.savedFlashcardService ?? SavedFlashcardServiceFactory.create();
    _engagementRepository =
        widget.engagementRepository ?? EngagementRepository();
    _petRepository = widget.petRepository ?? StudyPetRepository();
  }

  @override
  void dispose() {
    if (MuffinContextRegistry.instance.current.value?.context.contextKey ==
        _registeredContextKey) {
      MuffinContextRegistry.instance.resetToHome();
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Flashcards'),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: StreamBuilder<List<SavedFlashcardRef>>(
          stream: _savedFlashcardService.watchSavedFlashcards(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _SavedFlashcardsState(
                icon: Icons.cloud_off_rounded,
                title: 'Saved flashcards could not load.',
                message: 'Your learning progress is safe. Try again soon.',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final refs = snapshot.data ?? const <SavedFlashcardRef>[];
            if (refs.isEmpty) return const _EmptySavedFlashcardsState();
            return FutureBuilder<List<SavedFlashcardItem>>(
              future: _resolve(refs),
              builder: (context, itemSnapshot) {
                if (!itemSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = itemSnapshot.data ?? const <SavedFlashcardItem>[];
                if (items.isEmpty) return const _EmptySavedFlashcardsState();
                final safeIndex = _currentIndex.clamp(0, items.length - 1);
                if (safeIndex != _currentIndex) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _currentIndex = safeIndex);
                  });
                }
                _registerMuffinContext(items[safeIndex]);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${items[safeIndex].subjectName} - ${items[safeIndex].chapter.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            '${safeIndex + 1} / ${items.length}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        scrollDirection: Axis.vertical,
                        itemCount: items.length,
                        onPageChanged: (index) {
                          setState(() => _currentIndex = index);
                        },
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _SavedFlashcardDeckCard(
                            item: item,
                            isRevealed: _revealed.contains(item.documentId),
                            onToggleReveal: () {
                              var shouldCredit = false;
                              setState(() {
                                if (!_revealed.add(item.documentId)) {
                                  _revealed.remove(item.documentId);
                                } else {
                                  _reviewedSavedCards.add(item.documentId);
                                  shouldCredit = true;
                                }
                              });
                              if (shouldCredit) _creditSavedFlashcardReview();
                            },
                            onUnsave: () => _unsave(item),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<List<SavedFlashcardItem>> _resolve(
      List<SavedFlashcardRef> refs) async {
    final items = <SavedFlashcardItem>[];
    for (final ref in refs) {
      final subjectName =
          await _learningRepository.getSubjectName(ref.subjectId);
      final chapter = await _learningRepository.getChapter(
        subjectId: ref.subjectId,
        chapterId: ref.chapterId,
      );
      final card = await _learningRepository.getFlashcard(
        subjectId: ref.subjectId,
        chapterId: ref.chapterId,
        cardId: ref.cardId,
      );
      if (chapter == null || card == null) continue;
      items.add(SavedFlashcardItem(
        ref: ref,
        subjectName: subjectName,
        chapter: chapter,
        card: card,
      ));
    }
    return items;
  }

  Future<void> _unsave(SavedFlashcardItem item) async {
    await _savedFlashcardService.unsaveFlashcard(
      subjectId: item.ref.subjectId,
      chapterId: item.ref.chapterId,
      cardId: item.ref.cardId,
    );
    setState(() => _revealed.remove(item.documentId));
  }

  Future<void> _creditSavedFlashcardReview() async {
    try {
      final result = await _engagementRepository.creditSavedFlashcardReview(
        reviewedSavedCardIds: _reviewedSavedCards,
      );
      if (result.xpAwarded > 0) {
        debugPrint(
          '[StudySis][engagement] XP AWARD '
          'activity=saved_flashcards '
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
        message: 'Saved cards reviewed!',
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
      debugPrint('[StudySis][engagement] saved review credit failed: $error');
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

  void _registerMuffinContext(SavedFlashcardItem item) {
    final isRevealed = _revealed.contains(item.documentId);
    final contextKey =
        'saved_flashcard_${item.ref.subjectId}_${item.ref.chapterId}_${item.ref.cardId}_${isRevealed ? 'back' : 'front'}';
    if (_registeredContextKey == contextKey) return;
    _registeredContextKey = contextKey;
    final originalContent = [
      item.card.front,
      if (isRevealed) item.card.back,
      if (item.card.hint.trim().isNotEmpty) 'Hint: ${item.card.hint}',
    ].join('\n');
    MuffinContextRegistry.instance.set(
      MuffinScreenContext(
        mode: MuffinMode.learn,
        subtitle: isRevealed
            ? 'I can explain this saved flashcard.'
            : 'I can help without revealing the answer.',
        context: MuffinContext(
          studentProfileId: 'qidah',
          preferredLanguage: 'Mixed',
          subjectId: item.ref.subjectId,
          subjectTitle: item.subjectName,
          chapterId: item.ref.chapterId,
          chapterTitle: item.chapter.title,
          mode: MuffinMode.learn,
          currentScreen: 'saved_flashcards',
          cardId: item.ref.cardId,
          contextKey: contextKey,
          currentQuestion: item.card.front,
          lessonBody: isRevealed ? item.card.back : null,
          relevantNotes: [
            isRevealed ? 'Current side: back' : 'Current side: front'
          ],
          relevantFlashcards: [originalContent],
          originalScreenContent: originalContent,
        ),
        actions: [
          const MuffinActionConfig(
            action: MuffinAction.explainSimply,
            label: 'Explain this card',
          ),
          MuffinActionConfig(
            action: MuffinAction.translate,
            label: 'Translate this card',
            contextOverride: _toMalay,
          ),
          MuffinActionConfig(
            action: MuffinAction.translate,
            label: 'Translate this card to English',
            contextOverride: _toEnglish,
          ),
          const MuffinActionConfig(
            action: MuffinAction.anotherExample,
            label: 'Give another example',
          ),
          const MuffinActionConfig(
            action: MuffinAction.stillConfused,
            label: "I'm still confused",
          ),
        ],
      ),
    );
  }
}

MuffinContext _toMalay(MuffinContext context) {
  return context.copyWith(targetLanguage: 'Bahasa Melayu');
}

MuffinContext _toEnglish(MuffinContext context) {
  return context.copyWith(targetLanguage: 'English');
}

class SavedFlashcardItem {
  const SavedFlashcardItem({
    required this.ref,
    required this.subjectName,
    required this.chapter,
    required this.card,
  });

  final SavedFlashcardRef ref;
  final String subjectName;
  final Chapter chapter;
  final Flashcard card;

  String get documentId => ref.documentId;
}

class _SavedFlashcardDeckCard extends StatelessWidget {
  const _SavedFlashcardDeckCard({
    required this.item,
    required this.isRevealed,
    required this.onToggleReveal,
    required this.onUnsave,
  });

  final SavedFlashcardItem item;
  final bool isRevealed;
  final VoidCallback onToggleReveal;
  final VoidCallback onUnsave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onToggleReveal,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color:
                isRevealed ? const Color(0xFFFFF2E8) : const Color(0xFFE5EEE8),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isRevealed ? 'ANSWER' : 'QUESTION',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Remove saved flashcard',
                    onPressed: onUnsave,
                    icon: const Icon(Icons.bookmark_remove_rounded),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Text(
                      isRevealed ? item.card.back : item.card.front,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(height: 1.35),
                    ),
                  ),
                ),
              ),
              if (!isRevealed && item.card.hint.trim().isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('Hint: ${item.card.hint}'),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                      isRevealed
                          ? Icons.refresh_rounded
                          : Icons.touch_app_rounded,
                      size: 16),
                  const SizedBox(width: 6),
                  Text(
                    isRevealed
                        ? 'Tap to show question'
                        : 'Tap to reveal answer',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySavedFlashcardsState extends StatelessWidget {
  const _EmptySavedFlashcardsState();

  @override
  Widget build(BuildContext context) {
    return const _SavedFlashcardsState(
      icon: Icons.bookmark_border_rounded,
      title: 'No saved flashcards yet',
      message: "Save useful cards while studying and they'll appear here.",
    );
  }
}

class _SavedFlashcardsState extends StatelessWidget {
  const _SavedFlashcardsState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
