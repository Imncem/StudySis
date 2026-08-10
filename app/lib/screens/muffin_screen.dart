import 'package:flutter/material.dart';

import '../models/chapter_progress.dart';
import '../models/muffin.dart';
import '../repositories/student_progress_repository.dart';
import '../services/muffin_service.dart';
import '../widgets/muffin_assist_sheet.dart';

class MuffinScreen extends StatefulWidget {
  const MuffinScreen({
    this.progressRepository,
    this.muffinService,
    super.key,
  });

  final StudentProgressRepository? progressRepository;
  final MuffinService? muffinService;

  @override
  State<MuffinScreen> createState() => _MuffinScreenState();
}

class _MuffinScreenState extends State<MuffinScreen> {
  late final StudentProgressRepository _progressRepository;
  late Future<List<ChapterProgress>> _progressFuture;

  @override
  void initState() {
    super.initState();
    _progressRepository =
        widget.progressRepository ?? StudentProgressRepository();
    _progressFuture = _progressRepository.getAllChapterProgress();
  }

  void _retry() {
    setState(() {
      _progressFuture = _progressRepository.getAllChapterProgress();
    });
  }

  void _openMuffin(ChapterProgress progress, MuffinAction action) {
    final context = MuffinContext(
      studentProfileId: 'qidah',
      preferredLanguage: 'Mixed',
      subjectId: progress.subjectId,
      subjectTitle:
          progress.subjectId == 'math' ? 'Mathematics' : progress.subjectId,
      chapterId: progress.chapterId,
      chapterTitle: progress.chapterId,
      mode: MuffinMode.practice,
      currentScreen: 'muffin_home',
      practiceBestScore: progress.practiceBestPercentage,
      quizBestScore: progress.quizBestPercentage,
      quizPassed: progress.quizPassed,
      masteredFlashcardCount: progress.flashcardsMasteredCount,
    );
    showModalBottomSheet<void>(
      context: this.context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => MuffinAssistSheet(
        title: 'Muffin',
        subtitle: 'I can use your latest chapter as light context.',
        mode: MuffinMode.practice,
        context: context,
        service: widget.muffinService,
        actions: [
          MuffinActionConfig(
            action: action,
            label: _labelForAction(action),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Muffin'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<ChapterProgress>>(
          future: _progressFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _MuffinState(
                icon: Icons.cloud_off_rounded,
                title: 'Muffin could not load right now.',
                message: 'Your learning progress is safe. Please try again.',
                actionLabel: 'Retry',
                onAction: _retry,
              );
            }
            final progress = snapshot.data ?? const <ChapterProgress>[];
            if (progress.isEmpty) {
              return const _MuffinState(
                icon: Icons.auto_stories_rounded,
                title:
                    'Start a lesson first so Muffin can help with your learning.',
                message: 'Muffin uses your current chapter to stay focused.',
              );
            }
            progress.sort((a, b) {
              final aActivity = a.lastActivityAt;
              final bActivity = b.lastActivityAt;
              if (aActivity == null && bActivity == null) return 0;
              if (aActivity == null) return 1;
              if (bActivity == null) return -1;
              return bActivity.compareTo(aActivity);
            });
            final latest = progress.first;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                Text(
                  'Choose a focused Muffin action.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 18),
                _MuffinActionCard(
                  title: 'Explain my current chapter',
                  subtitle: 'A simple explanation using your latest progress.',
                  onTap: () => _openMuffin(latest, MuffinAction.explainConcept),
                ),
                _MuffinActionCard(
                  title: 'What should I revise?',
                  subtitle: 'A gentle suggestion from saved scores.',
                  onTap: () => _openMuffin(latest, MuffinAction.smallHint),
                ),
                _MuffinActionCard(
                  title: 'Translate a difficult term',
                  subtitle: 'Use the lesson language support.',
                  onTap: () => _openMuffin(latest, MuffinAction.explainConcept),
                ),
                _MuffinActionCard(
                  title: 'Create a quick practice question',
                  subtitle: 'One temporary generated question.',
                  onTap: () => _openMuffin(
                    latest,
                    MuffinAction.generateSimilarQuestion,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _labelForAction(MuffinAction action) {
    switch (action) {
      case MuffinAction.askMuffin:
        return 'Ask Muffin';
      case MuffinAction.explainConcept:
        return 'Explain this chapter';
      case MuffinAction.smallHint:
        return 'Suggest what to revise';
      case MuffinAction.generateSimilarQuestion:
        return 'Create a quick practice question';
      case MuffinAction.explainSimply:
      case MuffinAction.translate:
      case MuffinAction.anotherExample:
      case MuffinAction.stillConfused:
      case MuffinAction.identifyPattern:
      case MuffinAction.guideQuestion:
        return 'Ask Muffin';
    }
  }
}

class _MuffinActionCard extends StatelessWidget {
  const _MuffinActionCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                const Icon(Icons.psychology_rounded, color: Color(0xFF496A5A)),
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
                      Text(subtitle),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MuffinState extends StatelessWidget {
  const _MuffinState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF496A5A)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
