import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/learning_location.dart';
import 'package:studysis/repositories/engagement_repository.dart';
import 'package:studysis/services/trusted_progress_service.dart';

void main() {
  const chapter = LearningLocation(
    subjectId: 'science',
    subjectName: 'Science',
    parentKind: 'chapter',
    parentId: 'chapter-1',
    parentTitle: 'Biodiversity',
    parentNumber: '1',
    parentOrder: 1,
    structureLabel: 'Chapter',
  );

  test('module completion sends identity without client reward amounts',
      () async {
    final service = _RecordingTrustedProgressService();
    final repository = _repository(service);

    final result = await repository.creditLocationLearnCompletion(
      location: chapter,
      moduleId: 'notes-biodiversity',
    );

    expect(service.functionName, 'recordModuleCompletion');
    expect(service.payload, {
      'subjectId': 'science',
      'parentKind': 'chapter',
      'parentId': 'chapter-1',
      'moduleId': 'notes-biodiversity',
    });
    expect(service.payload, isNot(contains('xp')));
    expect(service.payload, isNot(contains('pawCoins')));
    expect(result.xpAwarded, 20);
    expect(result.pawCoinsAwarded, 10);
  });

  test('Practice sends question selections instead of a claimed score',
      () async {
    final service = _RecordingTrustedProgressService();
    final repository = _repository(service);

    await repository.creditLocationPracticeQuestions(
      location: chapter,
      moduleId: 'practice-a',
      answers: const {'question-1': 2, 'question-2': 0},
    );

    expect(service.functionName, 'submitPracticeAttempt');
    expect(service.payload?['answers'], {'question-1': 2, 'question-2': 0});
    expect(service.payload, isNot(contains('percentage')));
    expect(service.payload, isNot(contains('correctCount')));
  });

  test('Quiz sends parent-aware Topic identity and selected answers', () async {
    final service = _RecordingTrustedProgressService();
    final repository = _repository(service);
    const topic = LearningLocation(
      subjectId: 'english',
      subjectName: 'English',
      parentKind: 'topic',
      parentId: 'grammar-basics',
      parentTitle: 'Grammar Basics',
      parentNumber: '1',
      parentOrder: 1,
      structureLabel: 'Topic',
      containerKind: 'section',
      containerId: 'grammar',
      containerTitle: 'Grammar',
      containerNumber: '1',
    );

    await repository.creditLocationQuizCompletion(
      location: topic,
      moduleId: 'quiz-1',
      answers: const {'q1': 1},
    );

    expect(service.functionName, 'submitQuizAttempt');
    expect(service.payload?['containerId'], 'grammar');
    expect(service.payload?['parentKind'], 'topic');
    expect(service.payload?['answers'], {'q1': 1});
  });

  test('Flashcard milestone sends reviewed IDs for server verification',
      () async {
    final service = _RecordingTrustedProgressService();
    final repository = _repository(service);

    await repository.creditLocationFlashcardReview(
      location: chapter,
      moduleId: 'flashcards-a',
      reviewedCardIds: const {'c3', 'c1', 'c2'},
    );

    expect(service.functionName, 'recordFlashcardMilestone');
    expect(service.payload?['reviewedCardIds'], ['c1', 'c2', 'c3']);
  });
}

EngagementRepository _repository(TrustedProgressService service) {
  return EngagementRepository(
    firestore: FakeFirebaseFirestore(),
    uidProvider: () => 'student-1',
    nowProvider: () => DateTime.utc(2026, 11, 5),
    trustedProgressService: service,
  );
}

class _RecordingTrustedProgressService implements TrustedProgressService {
  String? functionName;
  Map<String, Object?>? payload;

  @override
  Future<Map<String, dynamic>> record(
    String functionName,
    Map<String, Object?> payload,
  ) async {
    this.functionName = functionName;
    this.payload = payload;
    return {
      'success': true,
      'credited': true,
      'studyPointsAwarded': 2,
      'xpAwarded': 20,
      'pawCoinsAwarded': 10,
      'previousTotalXp': 80,
      'previousLevel': 1,
      'streakNewlySecured': false,
      'state': {
        'totalXp': 100,
        'level': 2,
        'currentStreak': 1,
        'longestStreak': 1,
        'lastQualifiedDate': '2026-11-05',
        'todayDateKey': '2026-11-05',
        'todayStudyPoints': 3,
        'dailyStudyTarget': 3,
        'todayStreakSecured': true,
      },
    };
  }
}
