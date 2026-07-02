import 'package:flutter/material.dart';

import '../models/learning_content.dart';
import 'flashcard_screen.dart';

class ModuleReaderScreen extends StatelessWidget {
  const ModuleReaderScreen({required this.learningContent, super.key});

  final LearningContent learningContent;

  @override
  Widget build(BuildContext context) {
    final chapter = learningContent.chapter;
    final module = learningContent.module;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Learning module'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Text(
              learningContent.subjectName.toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chapter ${chapter.chapterNumber}: ${chapter.title}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            Text(module.title,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ReaderChip(label: module.typeLabel),
                _ReaderChip(label: '${module.estimatedMinutes} min'),
                _ReaderChip(label: _titleCase(module.difficulty)),
              ],
            ),
            const SizedBox(height: 24),
            if (learningContent.noteSections.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'This lesson is being prepared.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              for (final section in learningContent.noteSections) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.heading,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          section.body,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(height: 1.7),
                        ),
                        if (section.example.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF4F0),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Example',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 6),
                                SelectableText(section.example),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FlashcardScreen(
                      subjectName: learningContent.subjectName,
                      chapter: chapter,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.style_rounded),
              label: const Text('Go to Flashcards'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderChip extends StatelessWidget {
  const _ReaderChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

String _titleCase(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
