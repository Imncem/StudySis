import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/chapter.dart';
import 'package:studysis/models/learning_content.dart';
import 'package:studysis/models/learning_module.dart';
import 'package:studysis/models/note_section.dart';
import 'package:studysis/screens/module_reader_screen.dart';
import 'package:studysis/theme/app_theme.dart';

void main() {
  testWidgets('Go to Flashcards returns action to persist Learn first',
      (tester) async {
    Object? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push<ModuleReaderExitAction>(
                MaterialPageRoute<ModuleReaderExitAction>(
                  builder: (_) => const ModuleReaderScreen(
                    learningContent: _content,
                  ),
                ),
              );
            },
            child: const Text('Open Learn'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Learn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to Flashcards'));
    await tester.pumpAndSettle();

    expect(result, ModuleReaderExitAction.goToFlashcards);
    expect(find.text('Go to Flashcards'), findsNothing);
  });
}

const _content = LearningContent(
  subjectName: 'Mathematics',
  chapter: Chapter(
    id: 'chapter-1',
    chapterNumber: 1,
    title: 'Patterns and Sequences',
    textbookChapterTitle: 'Patterns and Sequences',
    learningObjectives: [],
    estimatedMinutes: 30,
    status: 'active',
    order: 1,
  ),
  module: LearningModule(
    id: 'notes',
    title: 'Learn',
    type: 'notes',
    content: '',
    summary: '',
    estimatedMinutes: 15,
    difficulty: 'easy',
    order: 1,
    status: 'active',
  ),
  noteSections: [
    NoteSection(
      id: 'section-1',
      heading: 'Pattern',
      body: 'A pattern follows a rule.',
      example: '',
      order: 1,
    ),
  ],
);
