import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/chapter_progress.dart';
import 'package:studysis/repositories/student_progress_repository.dart';
import 'package:studysis/screens/practice_screen.dart';
import 'package:studysis/screens/quiz_screen.dart';

void main() {
  const uid = 'anonymousUid123';
  const subjectId = 'math';
  const chapterId = 'chapter-1';

  test('missing progress document defaults to zero progress', () async {
    final repository = _repository(uid);

    final progress = await repository.getChapterProgress(
      subjectId: subjectId,
      chapterId: chapterId,
    );

    expect(progress.studentProfileId, 'qidah');
    expect(progress.learnCompleted, isFalse);
    expect(progress.overallProgress, 0);
    expect(progress.practiceLatestPercentage, 0);
    expect(progress.quizPassed, isFalse);
  });

  test('ChapterProgress maps legacy missing fields safely', () {
    final progress = ChapterProgress.fromMap(
      subjectId: subjectId,
      chapterId: chapterId,
      data: {
        'studentProfileId': 'qidah',
        'subjectId': subjectId,
        'chapterId': chapterId,
        'learnCompleted': true,
        'practiceLatestPercentage': 150,
        'quizCorrectCount': -3,
      },
    );

    expect(progress.learnCompleted, isTrue);
    expect(progress.flashcardsMasteredCount, 0);
    expect(progress.practiceLatestPercentage, 100);
    expect(progress.quizCorrectCount, 0);
  });

  test('overall progress calculation uses four equally weighted stages', () {
    expect(
      calculateOverallProgress(
        learnCompleted: true,
        flashcardsMasteredCount: 2,
        flashcardsTotalCount: 4,
        practiceCompleted: true,
        quizCompleted: false,
      ),
      63,
    );
  });

  test('persists learn and flashcard progress with merge-safe updates',
      () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repository(uid, firestore);
    await repository.markLearnCompleted(
        subjectId: subjectId, chapterId: chapterId);
    await repository.updateFlashcardProgress(
      subjectId: subjectId,
      chapterId: chapterId,
      masteredCount: 2,
      totalCount: 4,
      masteredCardIds: ['a', 'b'],
    );

    final snapshot = await firestore.doc(_path(uid)).get();
    final data = snapshot.data()!;
    expect(data['learnCompleted'], isTrue);
    expect(data['learnCompletedAt'], isNotNull);
    expect(data['flashcardsMasteredCount'], 2);
    expect(data['flashcardsTotalCount'], 4);
    expect(data['masteredFlashcardIds'], ['a', 'b']);
    expect(data['overallProgress'], 38);
    expect(data['createdAt'], isNotNull);
  });

  test('learn completion repository payload is rules-compatible', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repository(uid, firestore);

    await repository.markLearnCompleted(
      subjectId: subjectId,
      chapterId: chapterId,
    );

    final snapshot = await firestore.doc(_path(uid)).get();
    final data = snapshot.data()!;
    expect(snapshot.reference.path, _path(uid));
    expect(data.keys, {
      'studentProfileId',
      'subjectId',
      'chapterId',
      'learnCompleted',
      'learnCompletedAt',
      'flashcardsMasteredCount',
      'flashcardsTotalCount',
      'flashcardsCompleted',
      'masteredFlashcardIds',
      'practiceLatestPercentage',
      'practiceBestPercentage',
      'practiceCorrectCount',
      'practiceTotalQuestions',
      'practiceCompletedAt',
      'quizLatestPercentage',
      'quizBestPercentage',
      'quizCorrectCount',
      'quizIncorrectCount',
      'quizUnansweredCount',
      'quizPassed',
      'quizCompletedAt',
      'overallProgress',
      'lastActivityAt',
      'createdAt',
      'updatedAt',
    });
    expect(data['studentProfileId'], 'qidah');
    expect(data['subjectId'], subjectId);
    expect(data['chapterId'], chapterId);
    expect(data['learnCompleted'], isTrue);
    expect(data['flashcardsMasteredCount'], 0);
    expect(data['flashcardsTotalCount'], 0);
    expect(data['flashcardsCompleted'], isFalse);
    expect(data['masteredFlashcardIds'], <String>[]);
    expect(data['practiceLatestPercentage'], 0);
    expect(data['practiceBestPercentage'], 0);
    expect(data['practiceCorrectCount'], 0);
    expect(data['practiceTotalQuestions'], 0);
    expect(data['practiceCompletedAt'], isNull);
    expect(data['quizLatestPercentage'], 0);
    expect(data['quizBestPercentage'], 0);
    expect(data['quizCorrectCount'], 0);
    expect(data['quizIncorrectCount'], 0);
    expect(data['quizUnansweredCount'], 0);
    expect(data['quizPassed'], isFalse);
    expect(data['quizCompletedAt'], isNull);
    expect(data['overallProgress'], 25);
    expect(data['createdAt'], isNotNull);
    expect(data['updatedAt'], isNotNull);
    expect(data['lastActivityAt'], isNotNull);
    expect(data['learnCompletedAt'], isNotNull);
  });

  test('existing progress update preserves createdAt and other module fields',
      () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repository(uid, firestore);
    await repository.markLearnCompleted(
      subjectId: subjectId,
      chapterId: chapterId,
    );
    final first = (await firestore.doc(_path(uid)).get()).data()!;
    final createdAt = first['createdAt'];
    final learnCompletedAt = first['learnCompletedAt'];

    await repository.recordPracticeResult(
      subjectId: subjectId,
      chapterId: chapterId,
      result: const PracticeResult(correctAnswers: 3, totalQuestions: 4),
    );

    final data = (await firestore.doc(_path(uid)).get()).data()!;
    expect(data['createdAt'], createdAt);
    expect(data['learnCompleted'], isTrue);
    expect(data['learnCompletedAt'], learnCompletedAt);
    expect(data['flashcardsMasteredCount'], 0);
    expect(data['masteredFlashcardIds'], <String>[]);
    expect(data['practiceLatestPercentage'], 75);
    expect(data['practiceBestPercentage'], 75);
    expect(data['quizLatestPercentage'], 0);
    expect(data['quizPassed'], isFalse);
    expect(data['overallProgress'], 50);
  });

  test('repository field names match ChapterProgress mapping', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repository(uid, firestore);

    await repository.updateFlashcardProgress(
      subjectId: subjectId,
      chapterId: chapterId,
      masteredCount: 1,
      totalCount: 2,
      masteredCardIds: ['card-1'],
    );

    final progress = await repository.getChapterProgress(
      subjectId: subjectId,
      chapterId: chapterId,
    );
    final data = (await firestore.doc(_path(uid)).get()).data()!;
    expect(data.containsKey('masteredFlashcardIds'), isTrue);
    expect(data.containsKey('flashcardsMasteredIds'), isFalse);
    expect(progress.masteredFlashcardIds, ['card-1']);
  });

  test('chapter progress stream updates after learn completion write',
      () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repository(uid, firestore);
    final values = <ChapterProgress>[];
    final subscription = repository
        .streamChapterProgress(subjectId: subjectId, chapterId: chapterId)
        .listen(values.add);

    await repository.markLearnCompleted(
      subjectId: subjectId,
      chapterId: chapterId,
    );
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(values.last.learnCompleted, isTrue);
    expect(values.last.overallProgress, 25);
  });

  test('streams all chapter progress documents for the current user', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repository(uid, firestore);
    await repository.markLearnCompleted(
      subjectId: subjectId,
      chapterId: 'chapter-1',
    );
    await repository.markLearnCompleted(
      subjectId: subjectId,
      chapterId: 'chapter-2',
    );
    await firestore
        .doc('student_progress/anotherUid/chapters/math_chapter-3')
        .set({
      'studentProfileId': 'qidah',
      'subjectId': subjectId,
      'chapterId': 'chapter-3',
      'overallProgress': 100,
    });

    final progress = await repository.getAllChapterProgress();

    expect(progress.map((chapter) => chapter.chapterId), {
      'chapter-1',
      'chapter-2',
    });
  });

  test('practice latest updates and best percentage never decreases', () async {
    final repository = _repository(uid);
    await repository.recordPracticeResult(
      subjectId: subjectId,
      chapterId: chapterId,
      result: const PracticeResult(correctAnswers: 4, totalQuestions: 5),
    );
    await repository.recordPracticeResult(
      subjectId: subjectId,
      chapterId: chapterId,
      result: const PracticeResult(correctAnswers: 2, totalQuestions: 5),
    );

    final progress = await repository.getChapterProgress(
      subjectId: subjectId,
      chapterId: chapterId,
    );
    expect(progress.practiceLatestPercentage, 40);
    expect(progress.practiceBestPercentage, 80);
    expect(progress.practiceCorrectCount, 2);
  });

  test('quiz latest updates, best never decreases, and 70 percent passes',
      () async {
    final repository = _repository(uid);
    await repository.recordQuizResult(
      subjectId: subjectId,
      chapterId: chapterId,
      result: const QuizResult(
        correctCount: 7,
        incorrectCount: 2,
        unansweredCount: 1,
        totalQuestions: 10,
      ),
    );
    await repository.recordQuizResult(
      subjectId: subjectId,
      chapterId: chapterId,
      result: const QuizResult(
        correctCount: 5,
        incorrectCount: 5,
        unansweredCount: 0,
        totalQuestions: 10,
      ),
    );

    final progress = await repository.getChapterProgress(
      subjectId: subjectId,
      chapterId: chapterId,
    );
    expect(progress.quizLatestPercentage, 50);
    expect(progress.quizBestPercentage, 70);
    expect(progress.quizPassed, isFalse);
    expect(
      const QuizResult(
        correctCount: 7,
        incorrectCount: 3,
        unansweredCount: 0,
        totalQuestions: 10,
      ).passed,
      isTrue,
    );
  });

  test('persistent module unlocking restores after repository reload',
      () async {
    final firestore = FakeFirebaseFirestore();
    final firstSession = _repository(uid, firestore);
    await firstSession.markLearnCompleted(
        subjectId: subjectId, chapterId: chapterId);
    await firstSession.updateFlashcardProgress(
      subjectId: subjectId,
      chapterId: chapterId,
      masteredCount: 3,
      totalCount: 3,
    );
    await firstSession.recordPracticeResult(
      subjectId: subjectId,
      chapterId: chapterId,
      result: const PracticeResult(correctAnswers: 1, totalQuestions: 2),
    );

    final restoredSession = _repository(uid, firestore);
    final progress = await restoredSession.getChapterProgress(
      subjectId: subjectId,
      chapterId: chapterId,
    );

    expect(progress.learnCompleted, isTrue);
    expect(progress.flashcardsCompleted, isTrue);
    expect(progress.practiceCompleted, isTrue);
    expect(progress.overallProgress, 75);
  });
}

StudentProgressRepository _repository([
  String uid = 'anonymousUid123',
  FakeFirebaseFirestore? firestore,
]) {
  return StudentProgressRepository(
    firestore: firestore ?? FakeFirebaseFirestore(),
    uidProvider: () => uid,
  );
}

String _path(String uid) => 'student_progress/$uid/chapters/math_chapter-1';
