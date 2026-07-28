import 'package:flutter/material.dart';

import '../config/content_paths.dart';
import '../models/chapter.dart';
import '../models/chapter_progress.dart';
import '../models/progress_summary.dart';
import '../repositories/learning_repository.dart';
import '../repositories/student_progress_repository.dart';
import 'chapter_overview_screen.dart';
import 'subject_screen.dart';
import '../models/subject.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    this.learningRepository,
    this.progressRepository,
    super.key,
  });

  final LearningRepository? learningRepository;
  final StudentProgressRepository? progressRepository;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late final LearningRepository _learningRepository;
  late final StudentProgressRepository _progressRepository;
  late Future<List<Chapter>> _mathChapters;

  @override
  void initState() {
    super.initState();
    _learningRepository = widget.learningRepository ?? LearningRepository();
    _progressRepository =
        widget.progressRepository ?? StudentProgressRepository();
    _mathChapters = _learningRepository
        .getActiveChapters(ContentPaths.mathematicsSubjectId);
  }

  void _retry() {
    setState(() {
      _mathChapters = _learningRepository
          .getActiveChapters(ContentPaths.mathematicsSubjectId);
    });
  }

  void _startLearning() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SubjectScreen(
          subject: Subject(
            id: ContentPaths.mathematicsSubjectId,
            displayName: 'Mathematics',
            shortName: 'Mathematics',
            contentStatus: 'available',
            iconName: 'math',
            themeColor: '#496A5A',
            order: 1,
          ),
        ),
      ),
    );
  }

  void _openChapter(_ProgressChapterItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChapterOverviewScreen(
          subjectId: item.progress.subjectId,
          subjectName: item.subjectName,
          chapter: item.chapter,
          repository: _learningRepository,
          progressRepository: _progressRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Progress'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<Chapter>>(
          future: _mathChapters,
          builder: (context, chapterSnapshot) {
            if (chapterSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (chapterSnapshot.hasError) {
              return _ProgressState(
                icon: Icons.cloud_off_rounded,
                title: 'We could not load progress right now.',
                message: 'Please try again in a moment.',
                actionLabel: 'Retry',
                onAction: _retry,
              );
            }
            final chapters = chapterSnapshot.data ?? const <Chapter>[];
            return StreamBuilder<ProgressStreamData>(
              stream: _progressRepository.streamAllChapterProgress(),
              builder: (context, progressSnapshot) {
                if (progressSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !progressSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (progressSnapshot.hasError) {
                  return _ProgressState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Progress could not load.',
                    message: 'Your saved work is safe. Try again soon.',
                    actionLabel: 'Retry',
                    onAction: _retry,
                  );
                }
                final streamData = progressSnapshot.data ??
                    const ProgressStreamData(
                      progress: [],
                      isFromCache: false,
                    );
                final summary = ProgressSummary.fromProgress(
                  progress: streamData.progress,
                  totalActiveMathChapters: chapters.length,
                );
                final items = _buildChapterItems(
                  progress: streamData.progress,
                  chapters: chapters,
                );

                if (streamData.progress.isEmpty) {
                  return _EmptyProgressState(onStartLearning: _startLearning);
                }

                return RefreshIndicator(
                  onRefresh: () async => _retry(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                    children: [
                      Text(
                        'See how your learning journey is growing.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (streamData.isFromCache) ...[
                        const SizedBox(height: 12),
                        const _InlineNotice(
                          message:
                              'Showing saved progress from this device while StudySis reconnects.',
                        ),
                      ],
                      const SizedBox(height: 20),
                      _OverallProgressCard(summary: summary),
                      const SizedBox(height: 20),
                      Text(
                        'Learning Summary',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _SummaryGrid(summary: summary),
                      const SizedBox(height: 22),
                      Text(
                        'Performance',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _PerformanceCards(summary: summary),
                      const SizedBox(height: 22),
                      Text(
                        'Chapter Progress',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      for (final item in items) ...[
                        _ProgressChapterCard(
                          item: item,
                          onTap: () => _openChapter(item),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<_ProgressChapterItem> _buildChapterItems({
    required List<ChapterProgress> progress,
    required List<Chapter> chapters,
  }) {
    final chaptersById = {for (final chapter in chapters) chapter.id: chapter};
    final items = progress.map((chapterProgress) {
      final chapter = chaptersById[chapterProgress.chapterId] ??
          Chapter(
            id: chapterProgress.chapterId,
            chapterNumber: 0,
            title: 'Chapter ${chapterProgress.chapterId}',
            textbookChapterTitle: '',
            learningObjectives: const [],
            estimatedMinutes: 0,
            status: 'active',
            order: 9999,
          );
      return _ProgressChapterItem(
        subjectName:
            chapterProgress.subjectId == ContentPaths.mathematicsSubjectId
                ? 'Mathematics'
                : chapterProgress.subjectId,
        chapter: chapter,
        progress: chapterProgress,
      );
    }).toList();

    items.sort((a, b) {
      final aActivity = a.progress.lastActivityAt;
      final bActivity = b.progress.lastActivityAt;
      if (aActivity != null && bActivity != null) {
        final recent = bActivity.compareTo(aActivity);
        if (recent != 0) return recent;
      } else if (aActivity != null) {
        return -1;
      } else if (bActivity != null) {
        return 1;
      }
      return a.chapter.order.compareTo(b.chapter.order);
    });
    return items;
  }
}

class _ProgressChapterItem {
  const _ProgressChapterItem({
    required this.subjectName,
    required this.chapter,
    required this.progress,
  });

  final String subjectName;
  final Chapter chapter;
  final ChapterProgress progress;
}

class _OverallProgressCard extends StatelessWidget {
  const _OverallProgressCard({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final progress = summary.overallAverageProgress / 100;
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
                  'Overall Learning Progress',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${summary.overallAverageProgress}%',
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
            const SizedBox(height: 12),
            Text(
              '${summary.chaptersCompleted} / ${summary.totalActiveMathChapters} chapters completed',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.flag_rounded,
                label: 'Chapters Started',
                value: summary.chaptersStarted.toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.check_circle_rounded,
                label: 'Chapters Completed',
                value: summary.chaptersCompleted.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MetricCard(
          icon: Icons.auto_awesome_motion_rounded,
          label: 'Modules Completed',
          value: summary.modulesCompleted.toString(),
        ),
      ],
    );
  }
}

class _PerformanceCards extends StatelessWidget {
  const _PerformanceCards({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.edit_note_rounded,
                label: 'Average Practice Score',
                value: _scoreLabel(summary.averagePracticeScore),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.track_changes_rounded,
                label: 'Average Quiz Score',
                value: _scoreLabel(summary.averageQuizScore),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MetricCard(
          icon: Icons.favorite_rounded,
          label: 'Quiz Performance Status',
          value: summary.quizPerformanceStatus.label,
          supportingText: summary.quizPerformanceStatus.encouragement,
        ),
      ],
    );
  }

  String _scoreLabel(int? score) {
    if (score == null) return 'Not attempted yet';
    return '$score%';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.supportingText,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? supportingText;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF496A5A)),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (supportingText != null) ...[
              const SizedBox(height: 6),
              Text(
                supportingText!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressChapterCard extends StatelessWidget {
  const _ProgressChapterCard({
    required this.item,
    required this.onTap,
  });

  final _ProgressChapterItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = item.progress;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.subjectName,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.chapter.chapterNumber > 0
                              ? 'Chapter ${item.chapter.chapterNumber}: ${item.chapter.title}'
                              : item.chapter.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${progress.overallProgress}%',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress.overallProgress / 100,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE8ECE7),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TinyStatus(
                    label: progress.learnCompleted
                        ? 'Learn complete'
                        : 'Learn started',
                  ),
                  _TinyStatus(
                    label:
                        '${progress.flashcardsMasteredCount} flashcards mastered',
                  ),
                  _TinyStatus(
                    label: progress.practiceTotalQuestions > 0
                        ? 'Practice best ${progress.practiceBestPercentage}%'
                        : 'Practice not attempted',
                  ),
                  _TinyStatus(
                    label: progress.quizCompleted
                        ? 'Quiz best ${progress.quizBestPercentage}%'
                        : 'Quiz not attempted',
                  ),
                  _TinyStatus(
                    label: progress.quizCompleted
                        ? progress.quizPassed
                            ? 'Quiz passed'
                            : 'Needs Practice'
                        : 'Quiz waiting',
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

class _TinyStatus extends StatelessWidget {
  const _TinyStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE5EEE8),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF496A5A),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyProgressState extends StatelessWidget {
  const _EmptyProgressState({required this.onStartLearning});

  final VoidCallback onStartLearning;

  @override
  Widget build(BuildContext context) {
    return _ProgressState(
      icon: Icons.auto_stories_rounded,
      title: 'Your learning journey starts here.',
      message: 'Complete your first lesson to see your progress.',
      actionLabel: 'Start Learning',
      onAction: onStartLearning,
    );
  }
}

class _ProgressState extends StatelessWidget {
  const _ProgressState({
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
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
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
