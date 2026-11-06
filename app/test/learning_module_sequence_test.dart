import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/config/content_paths.dart';
import 'package:studysis/models/chapter.dart';
import 'package:studysis/models/learning_module.dart';
import 'package:studysis/models/learning_module_sequence.dart';
import 'package:studysis/repositories/learning_repository.dart';
import 'package:studysis/screens/learning_module_sequence_screen.dart';
import 'package:studysis/services/saved_flashcard_service.dart';

void main() {
  test('active modules sort by order and exclude draft and archived modules',
      () {
    final modules = [
      _module('draft', order: 0, status: 'draft'),
      _module('fourth', order: 4),
      _module('first', order: 1),
      _module('archived', order: 2, status: 'archived'),
      _module('second', order: 2),
      _module('third', order: 3),
    ];

    expect(
      sequenceActiveLearningModules(modules).map((module) => module.id),
      ['first', 'second', 'third', 'fourth'],
    );
  });

  test('duplicate orders are stable and missing orders are placed last', () {
    final modules = [
      _module('duplicate-a', order: 1),
      _module('missing', order: 0, hasValidOrder: false),
      _module('duplicate-b', order: 1),
      _module('ordered', order: 0),
    ];

    expect(
      sequenceActiveLearningModules(modules).map((module) => module.id),
      ['ordered', 'duplicate-a', 'duplicate-b', 'missing'],
    );
  });

  test('unsupported active Test and Review modules do not inflate sequence',
      () {
    final modules = [
      _module('notes', order: 1, type: 'notes'),
      _module('flashcards', order: 2, type: 'flashcards'),
      _module('practice', order: 3, type: 'practice'),
      _module('quiz', order: 4, type: 'quiz'),
      _module('test', order: 5, type: 'test'),
      _module('review', order: 6, type: 'review'),
    ];

    expect(
      sequenceActiveLearningModules(modules).map((module) => module.id),
      ['notes', 'flashcards', 'practice', 'quiz'],
    );
  });

  testWidgets('four modules show progress and Next/Previous replace content',
      (tester) async {
    final setup = await _seedNotesSequence(4);
    await tester.pumpWidget(
      MaterialApp(
        home: LearningModuleSequenceScreen(
          subjectName: 'Geography',
          chapter: _chapter,
          parent: const LearningModuleParent.chapter(
            subjectId: 'geography',
            chapterId: 'chapter-01',
          ),
          modules: setup.modules,
          initialModuleId: 'notes-1',
          repository: setup.repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Module 1 of 4'), findsOneWidget);
    expect(find.text('Lesson body 1'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('next-module-button')));
    await tester.tap(find.byKey(const Key('next-module-button')));
    await tester.pumpAndSettle();

    expect(find.text('Module 2 of 4'), findsOneWidget);
    expect(find.text('Lesson body 2'), findsOneWidget);
    expect(find.text('Lesson body 1'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('previous-module-button')));
    await tester.tap(find.byKey(const Key('previous-module-button')));
    await tester.pumpAndSettle();

    expect(find.text('Module 1 of 4'), findsOneWidget);
    expect(find.text('Lesson body 1'), findsOneWidget);
  });

  testWidgets('one active module does not show sequence controls',
      (tester) async {
    final setup = await _seedNotesSequence(1);
    await tester.pumpWidget(
      MaterialApp(
        home: LearningModuleSequenceScreen(
          subjectName: 'Geography',
          chapter: _chapter,
          parent: const LearningModuleParent.chapter(
            subjectId: 'geography',
            chapterId: 'chapter-01',
          ),
          modules: setup.modules,
          initialModuleId: 'notes-1',
          repository: setup.repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('module-sequence-progress')), findsNothing);
    expect(find.byKey(const Key('next-module-button')), findsNothing);
  });

  testWidgets('leaving a Notes sequence invokes existing completion once',
      (tester) async {
    final setup = await _seedNotesSequence(1);
    var completions = 0;
    var locationCompletions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LearningModuleSequenceScreen(
                  subjectName: 'Geography',
                  chapter: _chapter,
                  parent: const LearningModuleParent.chapter(
                    subjectId: 'geography',
                    chapterId: 'chapter-01',
                  ),
                  modules: setup.modules,
                  initialModuleId: 'notes-1',
                  repository: setup.repository,
                  onNotesCompleted: (_) async => completions += 1,
                  onLocationNotesCompleted: (location, _) async {
                    expect(location.subjectId, 'geography');
                    locationCompletions += 1;
                  },
                ),
              ),
            ),
            child: const Text('Open module'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open module'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(completions, 1);
    expect(locationCompletions, 1);
  });

  testWidgets('last module returns to list instead of inventing completion',
      (tester) async {
    final setup = await _seedNotesSequence(2);
    await tester.pumpWidget(
      MaterialApp(
        home: LearningModuleSequenceScreen(
          subjectName: 'Geography',
          chapter: _chapter,
          parent: const LearningModuleParent.chapter(
            subjectId: 'geography',
            chapterId: 'chapter-01',
          ),
          modules: setup.modules,
          initialModuleId: 'notes-2',
          repository: setup.repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Module 2 of 2'), findsOneWidget);
    expect(find.byKey(const Key('next-module-button')), findsNothing);
    expect(find.text('Back to module list'), findsOneWidget);
    expect(find.text('Complete chapter'), findsNothing);
  });

  testWidgets('mixed module sequence opens each existing module experience',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    await _seedParent(firestore);
    final modules = firestore.collection(
      ContentPaths.modules('geography', 'chapter-01'),
    );
    await modules.doc('notes').set(_moduleData(
          title: 'Notes module',
          type: 'notes',
          order: 1,
          content: 'Notes content',
        ));
    await modules.doc('flashcards').set(_moduleData(
          title: 'Flashcards module',
          type: 'flashcards',
          order: 2,
        ));
    await modules.doc('practice').set(_moduleData(
          title: 'Practice module',
          type: 'practice',
          order: 3,
        ));
    await modules.doc('quiz').set(_moduleData(
          title: 'Quiz module',
          type: 'quiz',
          order: 4,
        ));
    await modules.doc('flashcards').collection('cards').doc('card-1').set({
      'front': 'Scale',
      'back': 'A map ratio',
      'order': 1,
      'status': 'active',
    });
    await firestore
        .collection(ContentPaths.practiceQuestions('geography', 'chapter-01'))
        .doc('practice-1')
        .set({
      'moduleId': 'practice',
      'question': 'Which scale is correct?',
      'options': ['A', 'B', 'C', 'D'],
      'correctAnswerIndex': 0,
      'explanation': 'A is correct.',
      'hint': '',
      'topic': 'Scale',
      'difficulty': 'easy',
      'order': 1,
      'status': 'active',
    });
    await modules.doc('quiz').collection('questions').doc('quiz-1').set({
      'question': 'What does map scale compare?',
      'options': ['Distance', 'Weather', 'Height', 'Time'],
      'correctOptionIndex': 0,
      'explanation': 'It compares distance.',
      'difficulty': 'easy',
      'order': 1,
      'status': 'active',
    });
    final repository = LearningRepository(firestore: firestore);
    final active = await repository.getActiveChapterModules(
      subjectId: 'geography',
      chapterId: 'chapter-01',
    );

    await tester.pumpWidget(MaterialApp(
      home: LearningModuleSequenceScreen(
        subjectName: 'Geography',
        chapter: _chapter,
        parent: const LearningModuleParent.chapter(
          subjectId: 'geography',
          chapterId: 'chapter-01',
        ),
        modules: active,
        initialModuleId: 'notes',
        repository: repository,
        savedFlashcardService: const StaticSavedFlashcardService(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('next-module-button')));
    await tester.tap(find.byKey(const Key('next-module-button')));
    await tester.pumpAndSettle();

    expect(find.text('Scale'), findsOneWidget);
    expect(find.text('Module 2 of 4'), findsOneWidget);

    await tester.tap(find.byKey(const Key('next-module-button')));
    await tester.pumpAndSettle();
    expect(find.text('Which scale is correct?'), findsOneWidget);
    expect(find.text('Module 3 of 4'), findsOneWidget);

    await tester.tap(find.byKey(const Key('next-module-button')));
    await tester.pumpAndSettle();
    expect(find.text('What does map scale compare?'), findsOneWidget);
    expect(find.text('Module 4 of 4'), findsOneWidget);
  });
}

Future<({LearningRepository repository, List<LearningModule> modules})>
    _seedNotesSequence(int count) async {
  final firestore = FakeFirebaseFirestore();
  await _seedParent(firestore);
  final collection =
      firestore.collection(ContentPaths.modules('geography', 'chapter-01'));
  for (var index = count; index >= 1; index--) {
    await collection.doc('notes-$index').set(_moduleData(
          title: 'Module $index',
          type: 'notes',
          order: index,
          content: 'Lesson body $index',
        ));
  }
  final repository = LearningRepository(firestore: firestore);
  return (
    repository: repository,
    modules: await repository.getActiveChapterModules(
      subjectId: 'geography',
      chapterId: 'chapter-01',
    ),
  );
}

Future<void> _seedParent(FakeFirebaseFirestore firestore) async {
  await firestore.doc(ContentPaths.subject('geography')).set({
    'displayName': 'Geography',
  });
  await firestore.doc('${ContentPaths.chapters('geography')}/chapter-01').set({
    'chapterNumber': 1,
    'title': 'Scale and Distance',
    'textbookChapterTitle': 'Scale and Distance',
    'learningObjectives': <String>[],
    'estimatedMinutes': 20,
    'status': 'active',
    'order': 1,
  });
}

Map<String, Object> _moduleData({
  required String title,
  required String type,
  required int order,
  String content = '',
}) =>
    {
      'title': title,
      'type': type,
      'content': content,
      'summary': '',
      'estimatedMinutes': 5,
      'difficulty': 'easy',
      'order': order,
      'status': 'active',
    };

LearningModule _module(
  String id, {
  required int order,
  String type = 'notes',
  String status = 'active',
  bool hasValidOrder = true,
}) =>
    LearningModule(
      id: id,
      title: id,
      type: type,
      content: '',
      summary: '',
      estimatedMinutes: 5,
      difficulty: 'easy',
      order: order,
      status: status,
      hasValidOrder: hasValidOrder,
    );

const _chapter = Chapter(
  id: 'chapter-01',
  chapterNumber: 1,
  title: 'Scale and Distance',
  textbookChapterTitle: 'Scale and Distance',
  learningObjectives: [],
  estimatedMinutes: 20,
  status: 'active',
  order: 1,
);
