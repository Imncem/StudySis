import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/config/content_paths.dart';
import 'package:studysis/models/learning_module_sequence.dart';
import 'package:studysis/repositories/learning_repository.dart';

void main() {
  test('loads canonical Notes content from a Sejarah subchapter', () async {
    final firestore = FakeFirebaseFirestore();
    await _seedSubjectAndChapter(firestore, 'sejarah', 'chapter-01');
    await firestore
        .doc(
            '${ContentPaths.subchapters('sejarah', 'chapter-01')}/subchapter_01_01')
        .set({
      'number': '1.1',
      'title': 'Konsep Alam Melayu',
      'order': 1,
      'status': 'active',
    });
    await firestore
        .doc(ContentPaths.subchapterModule(
          'sejarah',
          'chapter-01',
          'subchapter_01_01',
          'notes',
        ))
        .set(_notesModule('Sejarah lesson'));

    final content = await LearningRepository(firestore: firestore)
        .getSubchapterNotesContent(
      subjectId: 'sejarah',
      chapterId: 'chapter-01',
      subchapterId: 'subchapter_01_01',
      moduleId: 'notes',
    );

    expect(content?.module.content, 'Sejarah lesson');
    expect(content?.noteSections, isEmpty);
    expect(content?.hasLessonContent, isTrue);
  });

  test('loads canonical Notes content from a normal chapter module', () async {
    final firestore = FakeFirebaseFirestore();
    await _seedSubjectAndChapter(firestore, 'science', 'chapter-01');
    await firestore
        .doc(ContentPaths.module('science', 'chapter-01', 'notes'))
        .set(_notesModule('Science lesson'));

    final content =
        await LearningRepository(firestore: firestore).getChapterNotesContent(
      subjectId: 'science',
      chapterId: 'chapter-01',
    );

    expect(content?.module.content, 'Science lesson');
    expect(content?.noteSections, isEmpty);
  });

  test('loads legacy sections when canonical Notes content is empty', () async {
    final firestore = FakeFirebaseFirestore();
    await _seedSubjectAndChapter(firestore, 'math', 'chapter-01');
    await firestore
        .doc(ContentPaths.module('math', 'chapter-01', 'notes'))
        .set(_notesModule(''));
    await firestore
        .collection(ContentPaths.noteSections('math', 'chapter-01', 'notes'))
        .doc('section-1')
        .set({
      'heading': 'Legacy heading',
      'body': 'Legacy lesson body',
      'example': '',
      'order': 1,
    });

    final content =
        await LearningRepository(firestore: firestore).getChapterNotesContent(
      subjectId: 'math',
      chapterId: 'chapter-01',
    );

    expect(content?.module.content, isEmpty);
    expect(content?.noteSections.single.body, 'Legacy lesson body');
  });

  for (final languageSubject in {
    'bahasa_melayu': ('pemahaman', 'Kandungan pelajaran'),
    'english': ('grammar', 'English lesson content'),
  }.entries) {
    test('loads canonical Notes content from ${languageSubject.key} Topic',
        () async {
      final firestore = FakeFirebaseFirestore();
      final sectionId = languageSubject.value.$1;
      final lesson = languageSubject.value.$2;
      await _seedSubjectAndChapter(
        firestore,
        languageSubject.key,
        sectionId,
      );
      await firestore
          .doc('${ContentPaths.topics(languageSubject.key, sectionId)}/topic-1')
          .set({'title': 'Topic', 'order': 1, 'status': 'active'});
      await firestore
          .doc(ContentPaths.topicModule(
            languageSubject.key,
            sectionId,
            'topic-1',
            'notes',
          ))
          .set(_notesModule(lesson));

      final content =
          await LearningRepository(firestore: firestore).getTopicNotesContent(
        subjectId: languageSubject.key,
        sectionId: sectionId,
        topicId: 'topic-1',
        moduleId: 'notes',
      );

      expect(content?.module.content, lesson);
      expect(content?.noteSections, isEmpty);
    });
  }

  test('loads only active Sejarah subchapters and modules in order', () async {
    final firestore = FakeFirebaseFirestore();
    final subchapters = firestore.collection(
      ContentPaths.subchapters('sejarah', 'chapter-01'),
    );
    await subchapters.doc('subchapter_01_02').set({
      'number': '1.2',
      'title': 'Second',
      'order': 2,
      'status': 'active',
    });
    await subchapters.doc('subchapter_01_01').set({
      'number': '1.1',
      'title': 'First',
      'order': 1,
      'status': 'active',
    });
    await subchapters.doc('subchapter_01_03').set({
      'number': '1.3',
      'title': 'Draft',
      'order': 3,
      'status': 'draft',
    });
    final modules = firestore.collection(ContentPaths.subchapterModules(
      'sejarah',
      'chapter-01',
      'subchapter_01_01',
    ));
    await modules.doc('quiz').set({
      'title': 'Quiz',
      'type': 'quiz',
      'content': '',
      'summary': '',
      'estimatedMinutes': 5,
      'difficulty': 'easy',
      'order': 2,
      'status': 'active',
    });
    await modules.doc('notes').set({
      'title': 'Notes',
      'type': 'notes',
      'content': '',
      'summary': '',
      'estimatedMinutes': 5,
      'difficulty': 'easy',
      'order': 1,
      'status': 'active',
    });
    await modules.doc('draft').set({
      'title': 'Draft',
      'type': 'practice',
      'content': '',
      'summary': '',
      'estimatedMinutes': 5,
      'difficulty': 'easy',
      'order': 3,
      'status': 'draft',
    });

    final repository = LearningRepository(firestore: firestore);
    final activeSubchapters = await repository.getActiveSubchapters(
      subjectId: 'sejarah',
      chapterId: 'chapter-01',
    );
    final activeModules = await repository.getActiveSubchapterModules(
      subjectId: 'sejarah',
      chapterId: 'chapter-01',
      subchapterId: 'subchapter_01_01',
    );

    expect(activeSubchapters.map((item) => item.number), ['1.1', '1.2']);
    expect(activeModules.map((item) => item.id), ['notes', 'quiz']);
  });

  test('loads only published practice questions ordered by order', () async {
    final firestore = FakeFirebaseFirestore();
    final collection = firestore
        .collection(ContentPaths.practiceQuestions('math', 'chapter-1'));
    await collection.doc('later').set({
      'question': 'Second question',
      'options': ['A', 'B', 'C', 'D'],
      'correctAnswerIndex': 1,
      'explanation': 'B is correct.',
      'hint': '',
      'topic': 'ordering',
      'difficulty': 'easy',
      'order': 2,
      'status': 'active',
    });
    await collection.doc('draft').set({
      'question': 'Draft question',
      'options': ['A', 'B', 'C', 'D'],
      'correctAnswerIndex': 0,
      'explanation': 'Hidden.',
      'hint': '',
      'topic': 'draft',
      'difficulty': 'easy',
      'order': 0,
      'status': 'draft',
    });
    await collection.doc('first').set({
      'question': 'First question',
      'options': ['A', 'B', 'C', 'D'],
      'correctAnswerIndex': 2,
      'explanation': 'C is correct.',
      'hint': 'Think carefully.',
      'topic': 'ordering',
      'difficulty': 'easy',
      'order': 1,
      'status': 'active',
    });

    final repository = LearningRepository(firestore: firestore);
    final questions = await repository.getPublishedPracticeQuestions(
      subjectId: 'math',
      chapterId: 'chapter-1',
    );

    expect(questions.map((question) => question.id), ['first', 'later']);
    expect(questions.every((question) => question.isPublished), isTrue);
  });

  test('loads only active quiz questions ordered by order', () async {
    final firestore = FakeFirebaseFirestore();
    final collection =
        firestore.collection(ContentPaths.quizQuestions('math', 'chapter-1'));
    await collection.doc('second').set({
      'question': 'Second quiz question',
      'options': ['A', 'B', 'C', 'D'],
      'correctOptionIndex': 1,
      'explanation': 'B is correct.',
      'difficulty': 'easy',
      'order': 2,
      'status': 'active',
    });
    await collection.doc('draft').set({
      'question': 'Draft quiz question',
      'options': ['A', 'B', 'C', 'D'],
      'correctOptionIndex': 0,
      'explanation': 'Hidden.',
      'difficulty': 'easy',
      'order': 0,
      'status': 'draft',
    });
    await collection.doc('first').set({
      'question': 'First quiz question',
      'options': ['A', 'B', 'C', 'D'],
      'correctOptionIndex': 2,
      'explanation': 'C is correct.',
      'difficulty': 'easy',
      'order': 1,
      'status': 'active',
    });

    final repository = LearningRepository(firestore: firestore);
    final questions = await repository.getActiveQuizQuestions(
      subjectId: 'math',
      chapterId: 'chapter-1',
    );

    expect(questions.map((question) => question.id), ['first', 'second']);
    expect(questions.every((question) => question.isActive), isTrue);
  });

  for (final subjectId in ['bahasa_melayu', 'english']) {
    test('loads active $subjectId Topic modules in module order', () async {
      final firestore = FakeFirebaseFirestore();
      final modules = firestore.collection(
        ContentPaths.topicModules(subjectId, 'section-1', 'topic-1'),
      );
      await modules.doc('second').set({
        ..._notesModule('Second'),
        'order': 2,
      });
      await modules.doc('draft').set({
        ..._notesModule('Draft'),
        'order': 0,
        'status': 'draft',
      });
      await modules.doc('first').set({
        ..._notesModule('First'),
        'order': 1,
      });

      final result =
          await LearningRepository(firestore: firestore).getActiveTopicModules(
        subjectId: subjectId,
        sectionId: 'section-1',
        topicId: 'topic-1',
      );

      expect(result.map((module) => module.id), ['first', 'second']);
    });
  }

  test('Flutter reads ordered active Quiz questions from a Quiz module',
      () async {
    final firestore = FakeFirebaseFirestore();
    final questions = firestore.collection(ContentPaths.moduleContent(
      'geography',
      'chapter-1',
      'quiz-module',
      'questions',
    ));
    await questions.doc('second').set(_quizQuestion(
          question: 'Second question',
          correctOptionIndex: 2,
          explanation: 'Second explanation',
          order: 2,
        ));
    await questions.doc('first').set(_quizQuestion(
          question: 'First question',
          correctOptionIndex: 1,
          explanation: 'First explanation',
          order: 1,
        ));
    await questions.doc('draft').set({
      ..._quizQuestion(
        question: 'Draft question',
        correctOptionIndex: 0,
        explanation: 'Draft explanation',
        order: 0,
      ),
      'status': 'draft',
    });

    final result = await LearningRepository(firestore: firestore).getModuleQuiz(
      parent: const LearningModuleParent.chapter(
        subjectId: 'geography',
        chapterId: 'chapter-1',
      ),
      moduleId: 'quiz-module',
    );

    expect(result.map((item) => item.id), ['first', 'second']);
    expect(result.first.options, ['A', 'B', 'C', 'D']);
    expect(result.first.correctOptionIndex, 1);
    expect(result.first.explanation, 'First explanation');
  });

  final practiceParents =
      <String, ({LearningModuleParent parent, String path})>{
    'Chapter': (
      parent: const LearningModuleParent.chapter(
        subjectId: 'science',
        chapterId: 'chapter-1',
      ),
      path: ContentPaths.practiceQuestions('science', 'chapter-1'),
    ),
    'Sejarah Subchapter': (
      parent: const LearningModuleParent.subchapter(
        subjectId: 'sejarah',
        chapterId: 'chapter-1',
        subchapterId: 'subchapter-1',
      ),
      path: ContentPaths.subchapterPracticeQuestions(
        'sejarah',
        'chapter-1',
        'subchapter-1',
      ),
    ),
    'BM/English Topic': (
      parent: const LearningModuleParent.topic(
        subjectId: 'english',
        chapterId: 'grammar',
        topicId: 'verbs',
      ),
      path: ContentPaths.topicPracticeQuestions(
        'english',
        'grammar',
        'verbs',
      ),
    ),
  };

  for (final entry in practiceParents.entries) {
    test('${entry.key} Practice modules cannot mix questions', () async {
      final firestore = FakeFirebaseFirestore();
      final questions = firestore.collection(entry.value.path);
      await questions.doc('a-1').set(_practiceQuestion('practice-a', 1));
      await questions.doc('b-1').set(_practiceQuestion('practice-b', 2));
      await questions.doc('a-2').set(_practiceQuestion('practice-a', 3));
      await questions.doc('draft-a').set({
        ..._practiceQuestion('practice-a', 4),
        'status': 'draft',
      });

      final repository = LearningRepository(firestore: firestore);
      final moduleA = await repository.getModulePractice(
        parent: entry.value.parent,
        moduleId: 'practice-a',
      );
      final moduleB = await repository.getModulePractice(
        parent: entry.value.parent,
        moduleId: 'practice-b',
      );

      expect(moduleA.map((item) => item.id), ['a-1', 'a-2']);
      expect(moduleB.map((item) => item.id), ['b-1']);
    });
  }

  test('legacy unassigned Practice questions require explicit fallback',
      () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection(ContentPaths.practiceQuestions('science', 'chapter-1'))
        .doc('legacy')
        .set(_practiceQuestion(null, 1));
    final repository = LearningRepository(firestore: firestore);
    const parent = LearningModuleParent.chapter(
      subjectId: 'science',
      chapterId: 'chapter-1',
    );

    expect(
      await repository.getModulePractice(
        parent: parent,
        moduleId: 'practice-a',
      ),
      isEmpty,
    );
    expect(
      (await repository.getModulePractice(
        parent: parent,
        moduleId: 'practice-a',
        includeLegacyUnassigned: true,
      ))
          .single
          .id,
      'legacy',
    );
  });
}

Future<void> _seedSubjectAndChapter(
  FakeFirebaseFirestore firestore,
  String subjectId,
  String chapterId,
) async {
  await firestore.doc(ContentPaths.subject(subjectId)).set({
    'displayName': subjectId,
  });
  await firestore.doc('${ContentPaths.chapters(subjectId)}/$chapterId').set({
    'chapterNumber': 1,
    'title': 'Chapter title',
    'textbookChapterTitle': 'Chapter title',
    'learningObjectives': <String>[],
    'estimatedMinutes': 20,
    'status': 'active',
    'order': 1,
  });
}

Map<String, Object> _notesModule(String content) => {
      'title': 'Notes',
      'type': 'notes',
      'content': content,
      'summary': 'Summary',
      'estimatedMinutes': 10,
      'difficulty': 'easy',
      'order': 1,
      'status': 'active',
    };

Map<String, Object> _practiceQuestion(String? moduleId, int order) => {
      if (moduleId != null) 'moduleId': moduleId,
      'question': 'Question $order',
      'options': ['A', 'B', 'C', 'D'],
      'correctAnswerIndex': 0,
      'explanation': 'A is correct.',
      'hint': '',
      'topic': 'Topic',
      'difficulty': 'easy',
      'order': order,
      'status': 'active',
    };

Map<String, Object> _quizQuestion({
  required String question,
  required int correctOptionIndex,
  required String explanation,
  required int order,
}) =>
    {
      'question': question,
      'options': ['A', 'B', 'C', 'D'],
      'correctOptionIndex': correctOptionIndex,
      'explanation': explanation,
      'difficulty': 'easy',
      'order': order,
      'status': 'active',
    };
