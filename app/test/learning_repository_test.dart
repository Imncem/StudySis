import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/config/content_paths.dart';
import 'package:studysis/repositories/learning_repository.dart';

void main() {
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
}
