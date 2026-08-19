import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/engagement.dart';
import 'package:studysis/repositories/engagement_repository.dart';

const uid = 'anonymousUid123';

void main() {
  test('opening app gives zero Study Points and XP does not reset', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = EngagementRepository(
      firestore: firestore,
      uidProvider: () => uid,
      nowProvider: () => DateTime.utc(2026, 8, 17, 2),
    );

    final state = await repository.readState();

    expect(state.todayStudyPoints, 0);
    expect(state.totalXp, 0);
    expect(state.todayStreakSecured, isFalse);
  });

  test('opening Muffin and translating have zero engagement values', () {
    const askMuffin = EngagementCredit(
      activityKey: 'ask_muffin',
      studyPoints: 0,
      xp: 0,
    );
    const translate = EngagementCredit(
      activityKey: 'translate_content',
      studyPoints: 0,
      xp: 0,
    );

    expect(askMuffin.studyPoints, 0);
    expect(askMuffin.xp, 0);
    expect(translate.studyPoints, 0);
    expect(translate.xp, 0);
  });

  test('Learn completion awards points and XP once', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repo(firestore);

    final first = await repository.creditLearnCompletion(
      subjectId: 'math',
      chapterId: 'chapter-1',
    );
    final second = await repository.creditLearnCompletion(
      subjectId: 'math',
      chapterId: 'chapter-1',
    );

    expect(first.credited, isTrue);
    expect(first.studyPointsAwarded, 2);
    expect(first.xpAwarded, 20);
    expect(first.previousTotalXp, 0);
    expect(first.newTotalXp, 20);
    expect(first.previousLevel, 1);
    expect(first.newLevel, 1);
    expect(first.levelUp, isFalse);
    expect(second.credited, isFalse);
    final state = await repository.readState();
    expect(state.todayStudyPoints, 2);
    expect(state.totalXp, 20);
  });

  test('5 flashcards awards once and fewer than 5 does not', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repo(firestore);

    final early = await repository.creditFlashcardReview(
      subjectId: 'math',
      chapterId: 'chapter-1',
      reviewedCardIds: {'a', 'b', 'c', 'd'},
    );
    final first = await repository.creditFlashcardReview(
      subjectId: 'math',
      chapterId: 'chapter-1',
      reviewedCardIds: {'a', 'b', 'c', 'd', 'e'},
    );
    final duplicate = await repository.creditFlashcardReview(
      subjectId: 'math',
      chapterId: 'chapter-1',
      reviewedCardIds: {'a', 'b', 'c', 'd', 'e'},
    );

    expect(early.credited, isFalse);
    expect(first.credited, isTrue);
    expect(first.studyPointsAwarded, 1);
    expect(first.xpAwarded, 10);
    expect(duplicate.credited, isFalse);
  });

  test('Practice, Quiz, and saved flashcard milestones award configured values',
      () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repo(firestore);

    final practice = await repository.creditPracticeQuestions(
      subjectId: 'math',
      chapterId: 'chapter-1',
      completedQuestionCount: 5,
      sessionId: 'session-1',
    );
    final quiz = await repository.creditQuizCompletion(
      subjectId: 'math',
      chapterId: 'chapter-1',
    );
    final saved = await repository.creditSavedFlashcardReview(
      reviewedSavedCardIds: {'a', 'b', 'c'},
    );

    expect(practice.studyPointsAwarded, 2);
    expect(practice.xpAwarded, 20);
    expect(quiz.studyPointsAwarded, 3);
    expect(quiz.xpAwarded, 40);
    expect(saved.studyPointsAwarded, 1);
    expect(saved.xpAwarded, 10);
  });

  test('daily Study Points reset next Malaysia day but XP remains', () async {
    final firestore = FakeFirebaseFirestore();
    var now = DateTime.utc(2026, 8, 17, 15, 30); // 2026-08-17 MYT.
    final repository = EngagementRepository(
      firestore: firestore,
      uidProvider: () => uid,
      nowProvider: () => now,
    );
    await repository.creditLearnCompletion(
      subjectId: 'math',
      chapterId: 'chapter-1',
    );

    now = DateTime.utc(2026, 8, 17, 16, 30); // 2026-08-18 MYT.
    final state = await repository.readState();

    expect(state.todayDateKey, '2026-08-18');
    expect(state.todayStudyPoints, 0);
    expect(state.totalXp, 20);
  });

  test('streak first, consecutive, repeat same day, missed day, and longest',
      () async {
    final firestore = FakeFirebaseFirestore();
    var now = DateTime.utc(2026, 8, 17, 2);
    final repository = EngagementRepository(
      firestore: firestore,
      uidProvider: () => uid,
      nowProvider: () => now,
    );

    final monday = await repository.creditQuizCompletion(
      subjectId: 'math',
      chapterId: 'chapter-1',
    );
    final mondayAgain = await repository.creditPracticeQuestions(
      subjectId: 'math',
      chapterId: 'chapter-1',
      completedQuestionCount: 5,
      sessionId: 'monday-extra',
    );
    now = DateTime.utc(2026, 8, 18, 2);
    final tuesday = await repository.creditQuizCompletion(
      subjectId: 'math',
      chapterId: 'chapter-1',
    );
    now = DateTime.utc(2026, 8, 20, 2);
    final thursday = await repository.creditQuizCompletion(
      subjectId: 'math',
      chapterId: 'chapter-1',
    );

    expect(monday.streakNewlySecured, isTrue);
    expect(monday.state.currentStreak, 1);
    expect(mondayAgain.streakNewlySecured, isFalse);
    expect(mondayAgain.state.currentStreak, 1);
    expect(tuesday.state.currentStreak, 2);
    expect(tuesday.state.longestStreak, 2);
    expect(thursday.state.currentStreak, 1);
    expect(thursday.state.longestStreak, 2);
  });

  test('first-ever streak persists currentStreak 1 when target is crossed',
      () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repo(firestore);
    await _seedEngagementState(
      firestore,
      currentStreak: 0,
      longestStreak: 0,
      lastQualifiedDate: '2026-08-15',
      todayStudyPoints: 2,
      todayStreakSecured: false,
      totalXp: 60,
    );

    final result = await repository.creditQuizCompletion(
      subjectId: 'math',
      chapterId: 'chapter-1',
    );
    final persisted = await firestore
        .doc('student_progress/$uid/engagement/state')
        .get()
        .then((snapshot) => snapshot.data()!);

    expect(result.streakNewlySecured, isTrue);
    expect(result.state.currentStreak, 1);
    expect(result.xpAwarded, 40);
    expect(persisted['currentStreak'], 1);
    expect(persisted['longestStreak'], 1);
    expect(persisted['lastQualifiedDate'], '2026-08-17');
    expect(persisted['todayStreakSecured'], isTrue);
    expect(persisted['todayStudyPoints'], 5);
    expect(persisted['totalXp'], 100);
  });

  test('missed-day qualification restarts currentStreak at 1', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repo(firestore);
    await _seedEngagementState(
      firestore,
      currentStreak: 6,
      longestStreak: 6,
      lastQualifiedDate: '2026-08-15',
      todayStudyPoints: 2,
      todayStreakSecured: false,
    );

    final result = await repository.creditFlashcardReview(
      subjectId: 'math',
      chapterId: 'chapter-1',
      reviewedCardIds: {'a', 'b', 'c', 'd', 'e'},
    );

    expect(result.state.currentStreak, 1);
    expect(result.state.longestStreak, 6);
    expect(result.streakNewlySecured, isTrue);
  });

  test('consecutive-day qualification increments currentStreak', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repo(firestore);
    await _seedEngagementState(
      firestore,
      currentStreak: 6,
      longestStreak: 6,
      lastQualifiedDate: '2026-08-16',
      todayStudyPoints: 2,
      todayStreakSecured: false,
    );

    final result = await repository.creditFlashcardReview(
      subjectId: 'math',
      chapterId: 'chapter-1',
      reviewedCardIds: {'a', 'b', 'c', 'd', 'e'},
    );

    expect(result.state.currentStreak, 7);
    expect(result.state.longestStreak, 7);
    expect(result.streakNewlySecured, isTrue);
  });

  test('same-day activity does not increment currentStreak again', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repo(firestore);
    await _seedEngagementState(
      firestore,
      currentStreak: 7,
      longestStreak: 7,
      lastQualifiedDate: '2026-08-17',
      todayStudyPoints: 3,
      todayStreakSecured: true,
    );

    final result = await repository.creditPracticeQuestions(
      subjectId: 'math',
      chapterId: 'chapter-1',
      completedQuestionCount: 5,
      sessionId: 'same-day-extra',
    );

    expect(result.state.currentStreak, 7);
    expect(result.state.longestStreak, 7);
    expect(result.streakNewlySecured, isFalse);
  });

  test('secured zero-streak legacy state is normalized on read and update',
      () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repo(firestore);
    await _seedEngagementState(
      firestore,
      currentStreak: 0,
      longestStreak: 1,
      lastQualifiedDate: '2026-08-17',
      todayStudyPoints: 5,
      todayStreakSecured: true,
    );

    final read = await repository.readState();
    final result = await repository.creditPracticeQuestions(
      subjectId: 'math',
      chapterId: 'chapter-1',
      completedQuestionCount: 5,
      sessionId: 'repair',
    );
    final persisted = await firestore
        .doc('student_progress/$uid/engagement/state')
        .get()
        .then((snapshot) => snapshot.data()!);

    expect(read.currentStreak, 1);
    expect(result.state.currentStreak, 1);
    expect(result.streakNewlySecured, isFalse);
    expect(persisted['todayStreakSecured'], isTrue);
    expect(persisted['currentStreak'], greaterThanOrEqualTo(1));
  });

  test('streak celebration triggers once for a qualifying day', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repo(firestore);

    final first = await repository.creditQuizCompletion(
      subjectId: 'math',
      chapterId: 'chapter-1',
    );
    final second = await repository.creditPracticeQuestions(
      subjectId: 'math',
      chapterId: 'chapter-1',
      completedQuestionCount: 5,
      sessionId: 'extra',
    );
    final reopened = await repository.watchState().first;

    expect(first.streakNewlySecured, isTrue);
    expect(second.streakNewlySecured, isFalse);
    expect(reopened.todayStreakSecured, isTrue);
  });

  test('XP level and progress calculation', () {
    expect(calculateLevel(0), 1);
    expect(calculateLevel(100), 2);
    expect(calculateLevel(250), 3);
    expect(calculateLevel(450), 4);
    expect(calculateLevel(700), 5);
    const state = EngagementState(
      totalXp: 240,
      level: 2,
      currentStreak: 0,
      longestStreak: 0,
      lastQualifiedDate: null,
      todayDateKey: '2026-08-17',
      todayStudyPoints: 0,
      dailyStudyTarget: 3,
      todayStreakSecured: false,
    );
    expect(state.xpForNextLevel, 250);
    expect(state.xpIntoLevel, 140);
  });

  test('credit result reports authoritative level-up transition', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = _repo(firestore);
    await _seedEngagementState(
      firestore,
      currentStreak: 0,
      longestStreak: 0,
      lastQualifiedDate: null,
      todayStudyPoints: 0,
      todayStreakSecured: false,
      totalXp: 90,
    );

    final result = await repository.creditPracticeQuestions(
      subjectId: 'math',
      chapterId: 'chapter-1',
      completedQuestionCount: 5,
      sessionId: 'level-up',
    );

    expect(result.credited, isTrue);
    expect(result.previousTotalXp, 90);
    expect(result.newTotalXp, 110);
    expect(result.previousLevel, 1);
    expect(result.newLevel, 2);
    expect(result.levelUp, isTrue);
  });
}

EngagementRepository _repo(FakeFirebaseFirestore firestore) {
  return EngagementRepository(
    firestore: firestore,
    uidProvider: () => 'anonymousUid123',
    nowProvider: () => DateTime.utc(2026, 8, 17, 2),
  );
}

Future<void> _seedEngagementState(
  FakeFirebaseFirestore firestore, {
  required int currentStreak,
  required int longestStreak,
  required String? lastQualifiedDate,
  required int todayStudyPoints,
  required bool todayStreakSecured,
  int totalXp = 0,
}) {
  return firestore.doc('student_progress/$uid/engagement/state').set({
    'totalXp': totalXp,
    'level': calculateLevel(totalXp),
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastQualifiedDate': lastQualifiedDate,
    'todayDateKey': '2026-08-17',
    'todayStudyPoints': todayStudyPoints,
    'dailyStudyTarget': 3,
    'todayStreakSecured': todayStreakSecured,
    'creditedActivities': <String, bool>{},
    'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 17)),
  });
}
