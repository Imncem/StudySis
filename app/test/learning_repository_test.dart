import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/config/content_paths.dart';
import 'package:studysis/repositories/learning_repository.dart';

void main() {
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
