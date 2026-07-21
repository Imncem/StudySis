import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../models/flashcard.dart';
import '../models/learning_content.dart';
import '../repositories/learning_repository.dart';
import 'flashcard_screen.dart';
import 'module_reader_screen.dart';

class ChapterOverviewScreen extends StatefulWidget {
  const ChapterOverviewScreen({
    required this.subjectId,
    required this.subjectName,
    required this.chapter,
    this.repository,
    super.key,
  });

  final String subjectId;
  final String subjectName;
  final Chapter chapter;
  final LearningRepository? repository;

  @override
  State<ChapterOverviewScreen> createState() => _ChapterOverviewScreenState();
}

class _ChapterOverviewScreenState extends State<ChapterOverviewScreen> {
  late final LearningRepository _repository;
  late Future<_ChapterJourneyData> _journey;
  final Set<String> _completedModules = {};
  final Set<String> _masteredFlashcards = {};

  static const _moduleCount = 5;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LearningRepository();
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
    return _ChapterJourneyData(notes: notes, flashcards: flashcards);
  }

  void _reload() {
    setState(() {
      _journey = _loadJourney();
    });
  }

  Future<void> _openLearn(LearningContent? notes) async {
    if (notes == null) {
      _showComingSoon('Learn is being prepared.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ModuleReaderScreen(learningContent: notes),
      ),
    );
    if (!mounted) return;
    setState(() => _completedModules.add('learn'));
  }

  Future<void> _openFlashcards(List<Flashcard> cards) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FlashcardScreen(
          subjectId: widget.subjectId,
          subjectName: widget.subjectName,
          chapter: widget.chapter,
          initialCompletedCardIds: _masteredFlashcards,
          onCardCompleted: (cardId) {
            setState(() => _masteredFlashcards.add(cardId));
          },
        ),
      ),
    );
    if (!mounted || cards.isEmpty) return;
    if (_masteredFlashcards.length >= cards.length) {
      setState(() => _completedModules.add('flashcards'));
    }
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
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
            final data = snapshot.data;
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;
            final progress = _completedModules.length / _moduleCount;
            final percent = (progress * 100).round();
            final hasLearn = data?.notes != null;
            final flashcardTotal = data?.flashcards.length ?? 0;

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  Text(
                    widget.subjectName.toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chapter ${widget.chapter.chapterNumber}: ${widget.chapter.title}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 22),
                  _ProgressCard(percent: percent, progress: progress),
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
                      status: _completedModules.contains('learn')
                          ? 'Completed'
                          : hasLearn
                              ? 'Continue'
                              : 'Preparing',
                      onTap: () => _openLearn(data?.notes),
                    ),
                    _JourneyCard(
                      icon: Icons.psychology_rounded,
                      title: 'Flashcards',
                      description: 'Remember the important ideas.',
                      status:
                          '${_masteredFlashcards.length} / $flashcardTotal mastered',
                      onTap: () =>
                          _openFlashcards(data?.flashcards ?? const []),
                    ),
                    _JourneyCard(
                      icon: Icons.edit_note_rounded,
                      title: 'Practice',
                      description: 'Guided exercises.',
                      status: _completedModules.contains('learn')
                          ? 'Coming soon'
                          : 'Locked',
                      locked: !_completedModules.contains('learn'),
                      onTap: () => _showComingSoon('Practice is coming soon.'),
                    ),
                    _JourneyCard(
                      icon: Icons.track_changes_rounded,
                      title: 'Quiz',
                      description: 'Timed challenge.',
                      status: 'Locked',
                      locked: true,
                      onTap: () => _showComingSoon('Quiz is coming soon.'),
                    ),
                    _JourneyCard(
                      icon: Icons.emoji_events_rounded,
                      title: 'Challenge',
                      description: 'Mixed chapter questions.',
                      status: 'Locked',
                      locked: true,
                      onTap: () => _showComingSoon('Challenge is coming soon.'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChapterJourneyData {
  const _ChapterJourneyData({required this.notes, required this.flashcards});

  final LearningContent? notes;
  final List<Flashcard> flashcards;
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.percent, required this.progress});

  final int percent;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFE5EEE8),
      child: Padding(
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

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String status;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final mutedColor =
        locked ? const Color(0xFF8A918B) : const Color(0xFF496A5A);
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
                    color: locked
                        ? const Color(0xFFF1EFEA)
                        : const Color(0xFFE5EEE8),
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
                      _StatusBadge(label: status, locked: locked),
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
  const _StatusBadge({required this.label, required this.locked});

  final String label;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: locked ? const Color(0xFFF1EFEA) : const Color(0xFFE5EEE8),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: locked ? const Color(0xFF756F66) : const Color(0xFF496A5A),
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
