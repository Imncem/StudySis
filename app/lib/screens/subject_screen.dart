import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../models/subject.dart';
import '../repositories/engagement_repository.dart';
import '../repositories/learning_repository.dart';
import '../repositories/student_progress_repository.dart';
import '../repositories/study_pet_repository.dart';
import 'chapter_overview_screen.dart';

class SubjectScreen extends StatefulWidget {
  const SubjectScreen({
    required this.subject,
    this.repository,
    this.progressRepository,
    this.engagementRepository,
    this.petRepository,
    super.key,
  });

  final Subject subject;
  final LearningRepository? repository;
  final StudentProgressRepository? progressRepository;
  final EngagementRepository? engagementRepository;
  final StudyPetRepository? petRepository;

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  late final LearningRepository _repository;
  late Future<List<Chapter>> _chapters;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LearningRepository();
    _chapters = _repository.getActiveChapters(widget.subject.id);
  }

  void _reload() {
    setState(() {
      _chapters = _repository.getActiveChapters(widget.subject.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.subject.displayName),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Text(
                widget.subject.shortName.toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subject.displayName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a chapter to begin the learning journey.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FutureBuilder<List<Chapter>>(
                future: _chapters,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _SubjectStateCard(
                      icon: Icons.cloud_off_rounded,
                      message: 'We could not load chapters right now.',
                      actionLabel: 'Try again',
                      onAction: _reload,
                    );
                  }
                  final chapters = snapshot.data ?? const <Chapter>[];
                  if (chapters.isEmpty) {
                    return const _SubjectStateCard(
                      icon: Icons.auto_stories_rounded,
                      message: 'Chapters are being prepared.',
                    );
                  }
                  return Column(
                    children: [
                      for (final chapter in chapters) ...[
                        _ChapterCard(
                          chapter: chapter,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ChapterOverviewScreen(
                                  subjectId: widget.subject.id,
                                  subjectName: widget.subject.displayName,
                                  chapter: chapter,
                                  repository: _repository,
                                  progressRepository: widget.progressRepository,
                                  engagementRepository:
                                      widget.engagementRepository,
                                  petRepository: widget.petRepository,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.chapter, required this.onTap});

  final Chapter chapter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5EEE8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    chapter.chapterNumber.toString(),
                    style: const TextStyle(
                      color: Color(0xFF496A5A),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
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
                      chapter.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${chapter.estimatedMinutes} min chapter',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectStateCard extends StatelessWidget {
  const _SubjectStateCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
