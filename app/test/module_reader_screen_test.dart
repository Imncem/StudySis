import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/chapter.dart';
import 'package:studysis/models/learning_content.dart';
import 'package:studysis/models/learning_module.dart';
import 'package:studysis/models/note_section.dart';
import 'package:studysis/models/page_translation.dart';
import 'package:studysis/screens/module_reader_screen.dart';
import 'package:studysis/services/muffin_context_registry.dart';
import 'package:studysis/services/page_translation_service.dart';
import 'package:studysis/theme/app_theme.dart';
import 'package:studysis/widgets/page_translation_scope.dart';

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

  testWidgets('Learn uses global Muffin entry only and registers actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const ModuleReaderScreen(learningContent: _content),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Ask Muffin'), findsNothing);
    final actions = MuffinContextRegistry.instance.current.value!.actions;
    expect(
        actions.map((action) => action.label), contains('Explain this simply'));
    expect(actions.map((action) => action.label),
        contains('Translate this section'));
    expect(actions.map((action) => action.label),
        contains('Translate this section to English'));
    expect(actions.map((action) => action.label),
        contains('Show another example'));
  });

  testWidgets('Learn page translation visibly changes every note section',
      (tester) async {
    final controller = PageTranslationController(
      service: _StaticTranslationService({
        'section_section-1_heading': 'Corak',
        'section_section-1_body': 'Corak mengikut peraturan.',
        'section_section-1_example_label': 'Contoh',
        'section_section-1_example_text': '2, 4, 6, 8',
        'section_section-2_heading': 'Jujukan',
        'section_section-2_body': 'Jujukan ialah senarai tersusun.',
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PageTranslationScope(
          controller: controller,
          child:
              const ModuleReaderScreen(learningContent: _multiSectionContent),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await controller.translateCurrentPage(
      targetLanguage: TranslationLanguage.malay,
    );
    await tester.pumpAndSettle();

    expect(find.text('Corak'), findsOneWidget);
    expect(find.text('Corak mengikut peraturan.'), findsOneWidget);
    expect(find.text('Contoh'), findsOneWidget);
    expect(find.text('Jujukan', skipOffstage: false), findsOneWidget);
    expect(find.text('Jujukan ialah senarai tersusun.', skipOffstage: false),
        findsOneWidget);

    controller.showOriginal();
    await tester.pumpAndSettle();

    expect(find.text('Pattern'), findsOneWidget);
    expect(find.text('A pattern follows a rule.'), findsOneWidget);
    expect(find.text('Sequence'), findsOneWidget);
  });

  testWidgets('Learn Malay headings translate through page scope',
      (tester) async {
    final controller = PageTranslationController(
      service: _StaticTranslationService({
        'section_section-1_heading': 'What is a Pattern?',
        'section_section-2_heading': 'What is a sequence?',
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PageTranslationScope(
          controller: controller,
          child: const ModuleReaderScreen(learningContent: _malayContent),
        ),
      ),
    );
    await tester.pump();

    await controller.translateCurrentPage(
      targetLanguage: TranslationLanguage.english,
    );
    await tester.pump();

    expect(find.text('What is a Pattern?'), findsOneWidget);
    expect(
        find.text('What is a sequence?', skipOffstage: false), findsOneWidget);

    controller.showOriginal();
    await tester.pump();

    expect(find.text('Apa itu Pola'), findsOneWidget);
    expect(find.text('Apa itu jujukan?', skipOffstage: false), findsOneWidget);
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

const _multiSectionContent = LearningContent(
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
      example: '2, 4, 6, 8',
      order: 1,
    ),
    NoteSection(
      id: 'section-2',
      heading: 'Sequence',
      body: 'A sequence is an ordered list.',
      example: '',
      order: 2,
    ),
  ],
);

const _malayContent = LearningContent(
  subjectName: 'Matematik',
  chapter: Chapter(
    id: 'chapter-1',
    chapterNumber: 1,
    title: 'Pola dan Jujukan',
    textbookChapterTitle: 'Pola dan Jujukan',
    learningObjectives: [],
    estimatedMinutes: 30,
    status: 'active',
    order: 1,
  ),
  module: LearningModule(
    id: 'notes',
    title: 'Belajar',
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
      heading: 'Apa itu Pola',
      body:
          'Pola ialah susunan nombor, bentuk, atau objek yang mengikut peraturan tertentu.',
      example: '2, 4, 6, 8 ialah pola kerana setiap nombor bertambah 2.',
      order: 1,
    ),
    NoteSection(
      id: 'section-2',
      heading: 'Apa itu jujukan?',
      body:
          'Jujukan ialah senarai nombor yang disusun mengikut urutan tertentu.',
      example: '5, 10, 15, 20 ialah jujukan dengan beza tetap 5.',
      order: 2,
    ),
  ],
);

class _StaticTranslationService implements PageTranslationService {
  const _StaticTranslationService(this.values);

  final Map<String, String> values;

  @override
  Future<PageTranslationResult> translate(
      PageTranslationRequest request) async {
    return PageTranslationResult(
      sourceLanguage: request.content.sourceLanguage,
      targetLanguage: request.targetLanguage,
      fields: {
        for (final field in request.content.fields)
          field.id: values[field.id] ?? field.text,
      },
    );
  }
}
