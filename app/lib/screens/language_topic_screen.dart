import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../models/curriculum_topic.dart';
import '../models/learning_module.dart';
import '../models/learning_module_sequence.dart';
import '../repositories/learning_repository.dart';
import '../theme/app_theme.dart';
import 'learning_module_sequence_screen.dart';

class LanguageTopicScreen extends StatefulWidget {
  const LanguageTopicScreen({
    required this.subjectId,
    required this.subjectName,
    required this.section,
    required this.repository,
    super.key,
  });

  final String subjectId;
  final String subjectName;
  final Chapter section;
  final LearningRepository repository;

  @override
  State<LanguageTopicScreen> createState() => _LanguageTopicScreenState();
}

class _LanguageTopicScreenState extends State<LanguageTopicScreen> {
  late Future<List<CurriculumTopic>> _topics;

  @override
  void initState() {
    super.initState();
    _topics = widget.repository.getActiveTopics(
      subjectId: widget.subjectId,
      sectionId: widget.section.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.section.title)),
      body: FutureBuilder<List<CurriculumTopic>>(
        future: _topics,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final topics = snapshot.data ?? const <CurriculumTopic>[];
          if (snapshot.hasError || topics.isEmpty) {
            return const Center(child: Text('Topics are being prepared.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            itemCount: topics.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _TopicCard(
              topic: topics[index],
              subjectId: widget.subjectId,
              subjectName: widget.subjectName,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LanguageTopicModulesScreen(
                    subjectId: widget.subjectId,
                    subjectName: widget.subjectName,
                    section: widget.section,
                    topic: topics[index],
                    repository: widget.repository,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class LanguageTopicModulesScreen extends StatefulWidget {
  const LanguageTopicModulesScreen({
    required this.subjectId,
    required this.subjectName,
    required this.section,
    required this.topic,
    required this.repository,
    super.key,
  });

  final String subjectId;
  final String subjectName;
  final Chapter section;
  final CurriculumTopic topic;
  final LearningRepository repository;

  @override
  State<LanguageTopicModulesScreen> createState() =>
      _LanguageTopicModulesScreenState();
}

class _LanguageTopicModulesScreenState
    extends State<LanguageTopicModulesScreen> {
  late Future<List<LearningModule>> _modules;

  @override
  void initState() {
    super.initState();
    _modules = widget.repository.getActiveTopicModules(
      subjectId: widget.subjectId,
      sectionId: widget.section.id,
      topicId: widget.topic.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.topic.title)),
      body: FutureBuilder<List<LearningModule>>(
        future: _modules,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final modules = snapshot.data ?? const <LearningModule>[];
          if (snapshot.hasError || modules.isEmpty) {
            return const Center(
              child: Text('Learning modules are being prepared.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            itemCount: modules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final module = modules[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(module.title),
                  subtitle: Text(
                    '${module.typeLabel} · ${module.estimatedMinutes} min',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LearningModuleSequenceScreen(
                        subjectName: widget.subjectName,
                        chapter: widget.section,
                        parent: LearningModuleParent.topic(
                          subjectId: widget.subjectId,
                          chapterId: widget.section.id,
                          topicId: widget.topic.id,
                        ),
                        parentTitle: widget.topic.title,
                        modules: modules,
                        initialModuleId: module.id,
                        repository: widget.repository,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.topic,
    required this.subjectId,
    required this.subjectName,
    required this.onTap,
  });

  final CurriculumTopic topic;
  final String subjectId;
  final String subjectName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = StudySisSubjectTheme.forSubject(
      id: subjectId,
      displayName: subjectName,
    );
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: theme.softSurface(context),
          foregroundColor: theme.accent(context),
          child: Text('${topic.order}'),
        ),
        title: Text(topic.title),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
