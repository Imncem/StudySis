import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../models/flashcard.dart';
import '../repositories/learning_repository.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({
    required this.subjectName,
    required this.chapter,
    this.repository,
    super.key,
  });

  final String subjectName;
  final Chapter chapter;
  final LearningRepository? repository;

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  late final LearningRepository _repository;
  late Future<List<Flashcard>> _cards;
  final _verticalController = PageController();
  final Set<String> _completedCards = {};
  final Set<String> _bookmarkedCards = {};
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LearningRepository();
    _cards = _repository.getActiveFlashcards(widget.chapter.id);
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
            return Column(
              children: [
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
                      setState(() => _currentIndex = index);
                    },
                    scrollDirection: Axis.vertical,
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      return _FlashcardPage(
                        card: card,
                        isBookmarked: _bookmarkedCards.contains(card.id),
                        isCompleted: _completedCards.contains(card.id),
                        onBookmark: () => _bookmark(card),
                        onComplete: () => _complete(card),
                        onMuffin: _showMuffin,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _reload() {
    setState(() {
      _currentIndex = 0;
      _cards = _repository.getActiveFlashcards(widget.chapter.id);
    });
  }

  void _complete(Flashcard card) {
    setState(() => _completedCards.add(card.id));
    _showMessage('Got it');
  }

  void _bookmark(Flashcard card) {
    final wasSaved = _bookmarkedCards.contains(card.id);
    setState(() {
      if (wasSaved) {
        _bookmarkedCards.remove(card.id);
      } else {
        _bookmarkedCards.add(card.id);
      }
    });
    _showMessage(wasSaved ? 'Removed from review' : 'Saved for review');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showMuffin() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Muffin is getting ready.',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('These learning helpers will be available later.'),
              const SizedBox(height: 20),
              for (final label in const [
                'Explain simply',
                'Translate',
                'Give another example',
                'I’m still confused',
              ]) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _showMessage('Muffin is getting ready.');
                    },
                    child: Text(label),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
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
                      subjectName.toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      chapterTitle,
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

class _FlashcardPage extends StatelessWidget {
  const _FlashcardPage({
    required this.card,
    required this.isCompleted,
    required this.isBookmarked,
    required this.onComplete,
    required this.onMuffin,
    required this.onBookmark,
  });

  final Flashcard card;
  final bool isCompleted;
  final bool isBookmarked;
  final VoidCallback onComplete;
  final VoidCallback onMuffin;
  final VoidCallback onBookmark;

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
                children: [
                  _FlashcardSide(
                    label: 'QUESTION',
                    text: card.front,
                    hint: card.hint,
                    instruction: 'Swipe left to reveal answer',
                    color: const Color(0xFFE5EEE8),
                    icon: Icons.arrow_back_rounded,
                  ),
                  _FlashcardSide(
                    label: 'ANSWER',
                    text: card.back,
                    hint: card.hint,
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
                  icon: Icons.pets_rounded,
                  label: 'Muffin',
                  onPressed: onMuffin,
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
              child: Text('Hint: $hint',
                  style: Theme.of(context).textTheme.bodyMedium),
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
