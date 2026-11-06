import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../models/chapter_progress.dart';
import '../models/learning_location.dart';
import '../models/progress_summary.dart';
import '../repositories/engagement_repository.dart';
import '../repositories/learning_repository.dart';
import '../repositories/student_progress_repository.dart';
import '../repositories/study_pet_repository.dart';
import 'chapter_overview_screen.dart';
import 'subject_screen.dart';
import '../models/subject.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    this.learningRepository,
    this.progressRepository,
    this.engagementRepository,
    this.petRepository,
    super.key,
  });

  final LearningRepository? learningRepository;
  final StudentProgressRepository? progressRepository;
  final EngagementRepository? engagementRepository;
  final StudyPetRepository? petRepository;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late final LearningRepository _learningRepository;
  late final StudentProgressRepository _progressRepository;
  late final EngagementRepository _engagementRepository;
  late final StudyPetRepository _petRepository;
  late Future<List<LearningLocation>> _learningLocations;

  @override
  void initState() {
    super.initState();
    _learningRepository = widget.learningRepository ?? LearningRepository();
    _progressRepository =
        widget.progressRepository ?? StudentProgressRepository();
    _engagementRepository =
        widget.engagementRepository ?? EngagementRepository();
    _petRepository = widget.petRepository ?? StudyPetRepository();
    _learningLocations = _learningRepository.getActiveLearningLocations();
  }

  void _retry() {
    setState(() {
      _learningLocations = _learningRepository.getActiveLearningLocations();
    });
  }

  void _startLearning(List<LearningLocation> locations) {
    final location = locations.isEmpty ? null : locations.first;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SubjectScreen(
          subject: Subject(
            id: location?.subjectId ?? 'math',
            displayName: location?.subjectName ?? 'Mathematics',
            shortName: location?.subjectName ?? 'Mathematics',
            contentStatus: 'available',
            iconName: location?.subjectId ?? 'math',
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
  }

  void _openChapter(_ProgressChapterItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => item.progress.parentKind == 'topic' ||
                item.progress.parentKind == 'subchapter'
            ? SubjectScreen(
                subject: Subject(
                  id: item.progress.subjectId,
                  displayName: item.subjectName,
                  shortName: item.subjectName,
                  contentStatus: 'available',
                  iconName: item.progress.subjectId,
                  themeColor: '#496A5A',
                  order: 1,
                ),
                repository: _learningRepository,
                progressRepository: _progressRepository,
                engagementRepository: _engagementRepository,
                petRepository: _petRepository,
              )
            : ChapterOverviewScreen(
                subjectId: item.progress.subjectId,
                subjectName: item.subjectName,
                chapter: item.chapter,
                repository: _learningRepository,
                progressRepository: _progressRepository,
                engagementRepository: _engagementRepository,
                petRepository: _petRepository,
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
        child: FutureBuilder<List<LearningLocation>>(
          future: _learningLocations,
          builder: (context, locationSnapshot) {
            if (locationSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (locationSnapshot.hasError) {
              return _ProgressState(
                icon: Icons.cloud_off_rounded,
                title: 'We could not load progress right now.',
                message: 'Please try again in a moment.',
                actionLabel: 'Retry',
                onAction: _retry,
              );
            }
            final locations =
                locationSnapshot.data ?? const <LearningLocation>[];
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
                  progress: streamData.progress
                      .where((item) => locations.any((location) =>
                          location.identityKey == item.identityKey))
                      .toList(),
                  totalActiveLearningLocations: locations.length,
                );
                final items = _buildChapterItems(
                  progress: streamData.progress,
                  locations: locations,
                );

                if (streamData.progress.isEmpty) {
                  return _EmptyProgressState(
                    onStartLearning: () => _startLearning(locations),
                  );
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
                        'Learning Progress',
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
    required List<LearningLocation> locations,
  }) {
    final locationsByIdentity = {
      for (final location in locations) location.identityKey: location,
    };
    final items = progress.map((chapterProgress) {
      final location = locationsByIdentity[chapterProgress.identityKey];
      final parentTitle = chapterProgress.parentTitle ??
          location?.parentTitle ??
          '${_labelFor(chapterProgress.parentKind)} ${chapterProgress.parentId}';
      final parentNumber = chapterProgress.parentNumber ??
          location?.parentNumber ??
          '${chapterProgress.parentOrder}';
      final parentOrder = chapterProgress.parentOrder > 0
          ? chapterProgress.parentOrder
          : location?.parentOrder ?? 9999;
      final chapter = Chapter(
        id: chapterProgress.containerId ?? chapterProgress.chapterId,
        chapterNumber: int.tryParse(
              chapterProgress.containerNumber ?? parentNumber,
            ) ??
            chapterProgress.parentOrder,
        title: chapterProgress.containerTitle ?? parentTitle,
        textbookChapterTitle: '',
        learningObjectives: const [],
        estimatedMinutes: 0,
        status: 'active',
        order: chapterProgress.parentOrder,
      );
      return _ProgressChapterItem(
        subjectName:
            location?.subjectName ?? _subjectNameFor(chapterProgress.subjectId),
        parentLabel:
            location?.structureLabel ?? _labelFor(chapterProgress.parentKind),
        parentNumber: parentNumber,
        parentTitle: parentTitle,
        parentOrder: parentOrder,
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
      return a.parentOrder.compareTo(b.parentOrder);
    });
    return items;
  }
}

class _ProgressChapterItem {
  const _ProgressChapterItem({
    required this.subjectName,
    required this.parentLabel,
    required this.parentNumber,
    required this.parentTitle,
    required this.parentOrder,
    required this.chapter,
    required this.progress,
  });

  final String subjectName;
  final String parentLabel;
  final String parentNumber;
  final String parentTitle;
  final int parentOrder;
  final Chapter chapter;
  final ChapterProgress progress;
}

String _labelFor(String kind) => switch (kind) {
      'topic' => 'Topic',
      'subchapter' => 'Subchapter',
      'section' => 'Section',
      'unit' => 'Unit',
      'lesson' => 'Lesson',
      _ => 'Chapter',
    };

String _subjectNameFor(String id) => switch (id) {
      'bahasa_melayu' => 'Bahasa Melayu',
      'english' => 'English',
      'math' => 'Mathematics',
      'science' => 'Science',
      'sejarah' => 'Sejarah',
      'geography' => 'Geography',
      'rbt' => 'RBT',
      'pendidikan_islam' => 'Pendidikan Islam',
      'pjk' => 'PJOK',
      'seni' => 'Seni',
      _ => id,
    };

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
              '${summary.chaptersCompleted} / ${summary.totalActiveLearningLocations} learning areas completed',
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
                label: 'Learning Areas Started',
                value: summary.chaptersStarted.toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.check_circle_rounded,
                label: 'Learning Areas Completed',
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
                          '${item.parentLabel} ${item.parentNumber}: ${item.parentTitle}',
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
