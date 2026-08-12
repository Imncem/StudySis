import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../models/flashcard.dart';
import '../models/muffin.dart';
import '../models/page_translation.dart';
import '../models/saved_flashcard.dart';
import '../repositories/learning_repository.dart';
import '../services/muffin_context_registry.dart';
import '../services/muffin_service.dart';
import '../services/saved_flashcard_service.dart';
import '../widgets/muffin_assist_sheet.dart';
import '../widgets/page_translation_scope.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({
    required this.subjectId,
    required this.subjectName,
    required this.chapter,
    this.initialCompletedCardIds = const {},
    this.onCardCompleted,
    this.repository,
    this.muffinService,
    this.savedFlashcardService,
    super.key,
  });

  final String subjectId;
  final String subjectName;
  final Chapter chapter;
  final Set<String> initialCompletedCardIds;
  final ValueChanged<String>? onCardCompleted;
  final LearningRepository? repository;
  final MuffinService? muffinService;
  final SavedFlashcardService? savedFlashcardService;

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  late final LearningRepository _repository;
  late final SavedFlashcardService _savedFlashcardService;
  late Future<List<Flashcard>> _cards;
  final _verticalController = PageController();
  final _translationOwner = Object();
  final Set<String> _completedCards = {};
  final Set<String> _revealedCards = {};
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LearningRepository();
    _savedFlashcardService =
        widget.savedFlashcardService ?? SavedFlashcardServiceFactory.create();
    _cards = _repository.getActiveFlashcards(
      widget.chapter.id,
      subjectId: widget.subjectId,
    );
    _completedCards.addAll(widget.initialCompletedCardIds);
  }

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Flashcard>>(
          future: _cards,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _FlashcardEmptyState(
                message: 'We could not load flashcards right now.',
                onRetry: _reload,
              );
            }
            final cards = snapshot.data ?? const <Flashcard>[];
            if (cards.isEmpty) {
              return _FlashcardEmptyState(
                message: 'Flashcards are being prepared.',
                onRetry: _reload,
              );
            }
            final safeIndex = _currentIndex.clamp(0, cards.length - 1);
            final currentCard = cards[safeIndex];
            final currentAnswerVisible =
                _revealedCards.contains(currentCard.id);
            final displayedLanguage = _displayedLanguage(context);
            _registerTranslationContent(
              context,
              currentCard,
              currentAnswerVisible,
              safeIndex,
            );
            MuffinContextRegistry.instance.set(
              MuffinScreenContext(
                mode: MuffinMode.learn,
                subtitle: currentAnswerVisible
                    ? 'I can explain this flashcard.'
                    : 'I can help without revealing the answer.',
                context: _contextForCard(
                  currentCard,
                  currentAnswerVisible,
                  displayedLanguage,
                ).copyWith(
                  contextKey:
                      'flashcard_${widget.subjectId}_${widget.chapter.id}_card_${currentCard.id}_${currentAnswerVisible ? 'back' : 'front'}',
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
            return StreamBuilder<List<SavedFlashcardRef>>(
              stream: _savedFlashcardService.watchSavedFlashcards(),
              initialData: const <SavedFlashcardRef>[],
              builder: (context, savedSnapshot) {
                final bookmarkedCards = savedSnapshot.data
                        ?.where((ref) =>
                            ref.subjectId == widget.subjectId &&
                            ref.chapterId == widget.chapter.id)
                        .map((ref) => ref.cardId)
                        .toSet() ??
                    const <String>{};
                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: PageTranslationBanner(),
                    ),
                    _FlashcardHeader(
                      subjectName: widget.subjectName,
                      chapterTitle: widget.chapter.title,
                      current: safeIndex + 1,
                      total: cards.length,
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _verticalController,
                        itemCount: cards.length,
                        onPageChanged: (index) {
                          _resetVisibleCardContext();
                          setState(() => _currentIndex = index);
                        },
                        scrollDirection: Axis.vertical,
                        itemBuilder: (context, index) {
                          final card = cards[index];
                          return _FlashcardPage(
                            card: card,
                            isBookmarked: bookmarkedCards.contains(card.id),
                            isCompleted: _completedCards.contains(card.id),
                            onBookmark: () => _bookmark(
                              card,
                              isSaved: bookmarkedCards.contains(card.id),
                            ),
                            onComplete: () => _complete(card),
                            isAnswerVisible: _revealedCards.contains(card.id),
                            onSideChanged: (showingAnswer) {
                              if (!showingAnswer) return;
                              _resetVisibleCardContext();
                              setState(() => _revealedCards.add(card.id));
                            },
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

  void _registerTranslationContent(
    BuildContext context,
    Flashcard card,
    bool includeAnswer,
    int index,
  ) {
    final controller = PageTranslationScope.maybeOf(context);
    if (controller == null) return;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return;
    final fields = [
      PageTranslationField(
        id: 'subjectName',
        type: 'label',
        text: widget.subjectName.toUpperCase(),
      ),
      PageTranslationField(
        id: 'chapterTitle',
        type: 'heading',
        text: widget.chapter.title,
      ),
      PageTranslationField(
        id: 'front_${card.id}',
        type: 'question',
        text: card.front,
      ),
      if (card.hint.trim().isNotEmpty)
        PageTranslationField(
          id: 'hint_${card.id}',
          type: 'hint',
          text: 'Hint: ${card.hint}',
        ),
      if (includeAnswer)
        PageTranslationField(
          id: 'back_${card.id}',
          type: 'answer',
          text: card.back,
        ),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      controller.registerPage(
        ownerToken: _translationOwner,
        routeName: ModalRoute.of(context)?.settings.name,
        content: TranslatablePageContent(
          pageType: 'flashcards',
          pageId:
              'flashcard_${widget.subjectId}_${widget.chapter.id}_${card.id}_${includeAnswer ? 'back' : 'front'}',
          sourceLanguage: _detectLanguage(fields),
          fields: fields,
        ),
      );
    });
  }

  void _reload() {
    setState(() {
      _currentIndex = 0;
      _cards = _repository.getActiveFlashcards(
        widget.chapter.id,
        subjectId: widget.subjectId,
      );
    });
  }

  void _complete(Flashcard card) {
    setState(() => _completedCards.add(card.id));
    widget.onCardCompleted?.call(card.id);
    _showMessage('Got it');
  }

  Future<void> _bookmark(Flashcard card, {required bool isSaved}) async {
    try {
      if (isSaved) {
        await _savedFlashcardService.unsaveFlashcard(
          subjectId: widget.subjectId,
          chapterId: widget.chapter.id,
          cardId: card.id,
        );
      } else {
        await _savedFlashcardService.saveFlashcard(
          subjectId: widget.subjectId,
          chapterId: widget.chapter.id,
          cardId: card.id,
        );
      }
      if (!mounted) return;
      _showMessage(isSaved ? 'Removed from review' : 'Saved for review');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Saved flashcards could not be updated.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  MuffinContext _contextForCard(
    Flashcard card,
    bool includeAnswer,
    String displayedLanguage,
  ) {
    final originalContent = [
      card.front,
      if (includeAnswer) card.back,
      if (card.hint.trim().isNotEmpty) 'Hint: ${card.hint}',
    ].join('\n');
    return MuffinContext(
      studentProfileId: 'qidah',
      preferredLanguage: 'Mixed',
      subjectId: widget.subjectId,
      subjectTitle: widget.subjectName,
      chapterId: widget.chapter.id,
      chapterTitle: widget.chapter.title,
      mode: MuffinMode.learn,
      currentScreen: 'flashcards',
      cardId: card.id,
      displayedLanguage: displayedLanguage,
      currentQuestion: card.front,
      lessonBody: includeAnswer ? card.back : null,
      relevantNotes: [
        includeAnswer ? 'Current side: back' : 'Current side: front'
      ],
      relevantFlashcards: [originalContent],
      originalScreenContent: originalContent,
    );
  }

  void _resetVisibleCardContext() {
    PageTranslationScope.maybeOf(context)?.resetForPageChange();
    MuffinContextRegistry.instance.clear();
  }

  String _displayedLanguage(BuildContext context) {
    final state = PageTranslationScope.maybeOf(context)?.state;
    if (state?.isTranslated == true && state?.targetLanguage != null) {
      return state!.targetLanguage!;
    }
    return state?.sourceLanguage ?? TranslationLanguage.unknown;
  }
}

class _FlashcardHeader extends StatelessWidget {
  const _FlashcardHeader({
    required this.subjectName,
    required this.chapterTitle,
    required this.current,
    required this.total,
    required this.onBack,
  });

  final String subjectName;
  final String chapterTitle;
  final int current;
  final int total;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PageTranslationScope.text(
                        context,
                        'subjectName',
                        subjectName.toUpperCase(),
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      PageTranslationScope.text(
                        context,
                        'chapterTitle',
                        chapterTitle,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Text(
                'Card $current / $total',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: current / total,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8E3),
            ),
          ),
        ],
      ),
    );
  }
}

String _detectLanguage(List<PageTranslationField> fields) {
  final text = fields.map((field) => field.text.toLowerCase()).join(' ');
  final malaySignals = RegExp(
    r'\b(ialah|dan|yang|dengan|contoh|nombor|pola|bab|apakah|apa|jujukan|seterusnya|berikut|beza|sepunya|tetap)\b',
  ).allMatches(text).length;
  final englishSignals =
      RegExp(r'\b(the|and|with|example|number|pattern|chapter)\b')
          .allMatches(text)
          .length;
  if (malaySignals > englishSignals) return TranslationLanguage.malay;
  if (englishSignals > malaySignals) return TranslationLanguage.english;
  return TranslationLanguage.unknown;
}

MuffinContext _toMalay(MuffinContext context) {
  return context.copyWith(targetLanguage: 'Bahasa Melayu');
}

MuffinContext _toEnglish(MuffinContext context) {
  return context.copyWith(targetLanguage: 'English');
}

class _FlashcardPage extends StatelessWidget {
  const _FlashcardPage({
    required this.card,
    required this.isCompleted,
    required this.isBookmarked,
    required this.onComplete,
    required this.onBookmark,
    required this.onSideChanged,
    required this.isAnswerVisible,
  });

  final Flashcard card;
  final bool isCompleted;
  final bool isBookmarked;
  final VoidCallback onComplete;
  final VoidCallback onBookmark;
  final ValueChanged<bool> onSideChanged;
  final bool isAnswerVisible;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 18),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: PageView(
                onPageChanged: (index) => onSideChanged(index == 1),
                children: [
                  _FlashcardSide(
                    label: 'QUESTION',
                    text: PageTranslationScope.text(
                      context,
                      'front_${card.id}',
                      card.front,
                    ),
                    hint: PageTranslationScope.text(
                      context,
                      'hint_${card.id}',
                      card.hint.isEmpty ? '' : 'Hint: ${card.hint}',
                    ),
                    instruction: 'Swipe left to reveal answer',
                    color: const Color(0xFFE5EEE8),
                    icon: Icons.arrow_back_rounded,
                  ),
                  _FlashcardSide(
                    label: 'ANSWER',
                    text: isAnswerVisible
                        ? PageTranslationScope.text(
                            context,
                            'back_${card.id}',
                            card.back,
                          )
                        : card.back,
                    hint: PageTranslationScope.text(
                      context,
                      'hint_${card.id}',
                      card.hint.isEmpty ? '' : 'Hint: ${card.hint}',
                    ),
                    instruction: 'Swipe right to return',
                    color: const Color(0xFFFFF2E8),
                    icon: Icons.arrow_forward_rounded,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SideAction(
                  icon: isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.check_rounded,
                  label: isCompleted ? 'Got it' : 'Check',
                  active: isCompleted,
                  onPressed: onComplete,
                ),
                const SizedBox(height: 22),
                _SideAction(
                  icon: isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  label: 'Save',
                  active: isBookmarked,
                  onPressed: onBookmark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlashcardSide extends StatelessWidget {
  const _FlashcardSide({
    required this.label,
    required this.text,
    required this.hint,
    required this.instruction,
    required this.color,
    required this.icon,
  });

  final String label;
  final String text;
  final String hint;
  final String instruction;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(height: 1.35),
                ),
              ),
            ),
          ),
          if (hint.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(hint, style: Theme.of(context).textTheme.bodyMedium),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  instruction,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SideAction extends StatelessWidget {
  const _SideAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: active ? Theme.of(context).colorScheme.primary : Colors.white,
          shape: const CircleBorder(),
          child: IconButton(
            onPressed: onPressed,
            color: active ? Colors.white : const Color(0xFF496A5A),
            icon: Icon(icon),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _FlashcardEmptyState extends StatelessWidget {
  const _FlashcardEmptyState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.style_rounded, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
