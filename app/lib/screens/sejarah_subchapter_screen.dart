import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../models/learning_module.dart';
import '../models/subchapter.dart';
import '../repositories/learning_repository.dart';
import '../theme/app_theme.dart';
import 'flashcard_screen.dart';
import 'module_reader_screen.dart';
import 'practice_screen.dart';
import 'quiz_screen.dart';

class SejarahSubchapterScreen extends StatefulWidget {
  const SejarahSubchapterScreen({
    required this.chapter,
    required this.subjectName,
    required this.repository,
    super.key,
  });

  final Chapter chapter;
  final String subjectName;
  final LearningRepository repository;

  @override
  State<SejarahSubchapterScreen> createState() =>
      _SejarahSubchapterScreenState();
}

class _SejarahSubchapterScreenState extends State<SejarahSubchapterScreen> {
  late Future<List<Subchapter>> _subchapters;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _subchapters = widget.repository.getActiveSubchapters(
      subjectId: 'sejarah',
      chapterId: widget.chapter.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = StudySisSubjectTheme.forSubject(
      id: 'sejarah',
      displayName: widget.subjectName,
    );
    return Scaffold(
      appBar: AppBar(title: Text('Chapter ${widget.chapter.chapterNumber}')),
      body: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: FutureBuilder<List<Subchapter>>(
          future: _subchapters,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _MessageList(message: 'Subchapters could not be loaded.');
            }
            final items = snapshot.data ?? const <Subchapter>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                Text(widget.chapter.title,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text('Choose a subchapter to continue.',
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 22),
                if (items.isEmpty)
                  const _EmptyCard(message: 'Subchapters are being prepared.'),
                for (final item in items) ...[
                  _NavigationCard(
                    leading: item.number,
                    title: item.title,
                    theme: theme,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SejarahModulesScreen(
                          chapter: widget.chapter,
                          subchapter: item,
                          subjectName: widget.subjectName,
                          repository: widget.repository,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class SejarahModulesScreen extends StatefulWidget {
  const SejarahModulesScreen({
    required this.chapter,
    required this.subchapter,
    required this.subjectName,
    required this.repository,
    super.key,
  });

  final Chapter chapter;
  final Subchapter subchapter;
  final String subjectName;
  final LearningRepository repository;

  @override
  State<SejarahModulesScreen> createState() => _SejarahModulesScreenState();
}

class _SejarahModulesScreenState extends State<SejarahModulesScreen> {
  late Future<List<LearningModule>> _modules;

  @override
  void initState() {
    super.initState();
    _modules = widget.repository.getActiveSubchapterModules(
      subjectId: 'sejarah',
      chapterId: widget.chapter.id,
      subchapterId: widget.subchapter.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = StudySisSubjectTheme.forSubject(
      id: 'sejarah',
      displayName: widget.subjectName,
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.subchapter.number)),
      body: FutureBuilder<List<LearningModule>>(
        future: _modules,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const _MessageList(
                message: 'Learning modules could not be loaded.');
          }
          final modules = snapshot.data ?? const <LearningModule>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              Text(widget.subchapter.title,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text('Learning modules',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 22),
              if (modules.isEmpty)
                const _EmptyCard(
                    message: 'Learning modules are being prepared.'),
              for (final module in modules) ...[
                _NavigationCard(
                  leading: _moduleGlyph(module.type),
                  title: module.title,
                  subtitle:
                      '${module.typeLabel} · ${module.estimatedMinutes} min',
                  theme: theme,
                  onTap: () => _openModule(module),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _openModule(LearningModule module) async {
    final repository = widget.repository;
    final location = (
      subjectId: 'sejarah',
      chapterId: widget.chapter.id,
      subchapterId: widget.subchapter.id,
      moduleId: module.id,
    );
    Widget? screen;
    if (module.type == 'notes') {
      final content = await repository.getSubchapterNotesContent(
        subjectId: location.subjectId,
        chapterId: location.chapterId,
        subchapterId: location.subchapterId,
        moduleId: location.moduleId,
      );
      if (content != null) {
        screen = ModuleReaderScreen(learningContent: content);
      }
    } else if (module.type == 'flashcards') {
      screen = FlashcardScreen(
        subjectId: location.subjectId,
        subjectName: widget.subjectName,
        chapter: widget.chapter,
        repository: repository,
        cardsFuture: repository.getActiveSubchapterFlashcards(
          subjectId: location.subjectId,
          chapterId: location.chapterId,
          subchapterId: location.subchapterId,
          moduleId: location.moduleId,
        ),
      );
    } else if (module.type == 'practice') {
      screen = PracticeScreen(
        title: module.title,
        subjectId: location.subjectId,
        subjectTitle: widget.subjectName,
        chapterId: location.chapterId,
        chapterTitle: widget.subchapter.title,
        questionsFuture: repository.getActiveSubchapterPractice(
          subjectId: location.subjectId,
          chapterId: location.chapterId,
          subchapterId: location.subchapterId,
          moduleId: location.moduleId,
        ),
      );
    } else if (module.type == 'quiz' || module.type == 'test') {
      screen = QuizScreen(
        chapter: widget.chapter,
        subjectId: location.subjectId,
        subjectTitle: widget.subjectName,
        title: module.title,
        questionsFuture: repository.getActiveSubchapterQuiz(
          subjectId: location.subjectId,
          chapterId: location.chapterId,
          subchapterId: location.subchapterId,
          moduleId: location.moduleId,
        ),
      );
    }
    if (!mounted) return;
    if (screen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This module type is being prepared.')),
      );
      return;
    }
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen!));
  }
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({
    required this.leading,
    required this.title,
    required this.theme,
    required this.onTap,
    this.subtitle,
  });

  final String leading;
  final String title;
  final String? subtitle;
  final StudySisSubjectTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = theme.accent(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              constraints: const BoxConstraints(minWidth: 50, minHeight: 50),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: theme.softSurface(context),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(leading,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!,
                        style: Theme.of(context).textTheme.bodySmall)
                  ],
                ])),
            Icon(Icons.chevron_right_rounded, color: accent),
          ]),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(message, textAlign: TextAlign.center)));
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => ListView(children: [
        Padding(
            padding: const EdgeInsets.all(28),
            child: _EmptyCard(message: message))
      ]);
}

String _moduleGlyph(String type) => switch (type) {
      'notes' => 'N',
      'flashcards' => 'F',
      'practice' => 'P',
      'quiz' || 'test' => 'Q',
      _ => 'M',
    };
