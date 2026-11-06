const test = require('node:test');
const assert = require('node:assert/strict');

const { _test } = require('../trustedProgression');

test('trusted rewards are fixed by activity and never supplied by the client', () => {
  assert.deepEqual(_test.REWARDS.notes, {
    studyPoints: 2,
    xp: 20,
    pawCoins: 10,
    lifetime: true,
  });
  assert.equal(_test.REWARDS.quiz.xp, 40);
  assert.equal(_test.REWARDS.quiz.pawCoins, 20);
  assert.deepEqual(_test.REWARDS.review, {
    studyPoints: 2, xp: 20, pawCoins: 10, lifetime: true,
  });
  assert.equal(_test.REWARDS.test.xp, 40);
});

test('Test scoring is server-derived from stored correct answer indexes', () => {
  const questions = [
    { id: 'q1', data: () => ({ correctOptionIndex: 2 }) },
    { id: 'q2', data: () => ({ correctOptionIndex: 0 }) },
    { id: 'q3', data: () => ({ correctOptionIndex: 1 }) },
  ];
  assert.deepEqual(_test.scoreQuestionDocuments(questions, { q1: 2, q2: 3 }), {
    correctCount: 1,
    incorrectCount: 1,
    unansweredCount: 1,
    totalQuestions: 3,
    percentage: 33,
    passed: false,
  });
});

test('Test question delivery strips answers and explanations before submission', () => {
  const questions = _test.sanitizeTestQuestionDocuments([
    {
      id: 'q2',
      data: () => ({
        question: 'Second?', options: ['A', 'B', 'C', 'D'],
        correctOptionIndex: 1, explanation: 'Secret', difficulty: 'medium',
        order: 2, status: 'active',
      }),
    },
    {
      id: 'q1',
      data: () => ({
        question: 'First?', options: ['A', 'B', 'C', 'D'],
        correctOptionIndex: 0, explanation: 'Secret', difficulty: 'easy',
        order: 1, status: 'active',
      }),
    },
  ]);
  assert.deepEqual(questions.map((question) => question.id), ['q1', 'q2']);
  assert.equal(Object.hasOwn(questions[0], 'correctOptionIndex'), false);
  assert.equal(Object.hasOwn(questions[0], 'explanation'), false);
});

test('Quiz, Test and Review progression endpoints cannot cross module types', () => {
  assert.deepEqual([..._test.expectedModuleTypes('quiz')], ['quiz']);
  assert.deepEqual([..._test.expectedModuleTypes('test')], ['test']);
  assert.deepEqual([..._test.expectedModuleTypes('review')], ['review']);
});

test('Test and Review persist separate parent-aware progress fields', () => {
  const location = {
    subjectId: 'english',
    parentKind: 'topic',
    parentId: 'verbs',
    containerId: 'grammar',
  };
  const timestamp = {serverTimestamp: true};
  const testProgress = _test.buildProgressUpdate({
    existing: {quizBestPercentage: 80},
    location,
    activityType: 'test',
    evidence: {
      score: {
        percentage: 60,
        correctCount: 3,
        incorrectCount: 2,
        unansweredCount: 0,
        totalQuestions: 5,
        passed: false,
      },
    },
    timestamp,
  });
  assert.equal(testProgress.testLatestPercentage, 60);
  assert.equal(testProgress.testBestPercentage, 60);
  assert.equal(testProgress.testPassed, false);
  assert.equal(testProgress.quizBestPercentage, 80);
  assert.equal(testProgress.parentKind, 'topic');
  assert.equal(testProgress.containerId, 'grammar');

  const reviewProgress = _test.buildProgressUpdate({
    existing: testProgress,
    location,
    activityType: 'review',
    evidence: {reviewedItemCount: 2},
    timestamp,
  });
  assert.equal(reviewProgress.reviewCompleted, true);
  assert.equal(reviewProgress.reviewCompletedAt, timestamp);
  assert.equal(reviewProgress.testLatestPercentage, 60);
});

test('module completion event identity is deterministic and module scoped', () => {
  const first = _test.trustedEventKey({
    activityType: 'notes',
    modulePath: 'curriculum/form2/subjects/math/chapters/chapter-1/modules/notes-a',
    today: '2026-11-05',
    lifetime: true,
  });
  const retry = _test.trustedEventKey({
    activityType: 'notes',
    modulePath: 'curriculum/form2/subjects/math/chapters/chapter-1/modules/notes-a',
    today: '2026-11-06',
    lifetime: true,
  });
  const anotherModule = _test.trustedEventKey({
    activityType: 'notes',
    modulePath: 'curriculum/form2/subjects/math/chapters/chapter-1/modules/notes-b',
    today: '2026-11-05',
    lifetime: true,
  });
  assert.equal(first, retry);
  assert.notEqual(first, anotherModule);
});

test('daily quiz event retries dedupe but a later Malaysia day is distinct', () => {
  const event = (today) => _test.trustedEventKey({
    activityType: 'quiz',
    modulePath: 'curriculum/form2/subjects/math/chapters/chapter-1/modules/quiz-a',
    today,
    lifetime: false,
  });
  assert.equal(event('2026-11-05'), event('2026-11-05'));
  assert.notEqual(event('2026-11-05'), event('2026-11-06'));
});

test('location validation enforces parent-aware curriculum hierarchy', () => {
  assert.deepEqual(
    _test.validateLocation({
      subjectId: 'sejarah',
      parentKind: 'subchapter',
      parentId: 'subchapter-1-1',
      containerId: 'chapter-1',
      moduleId: 'notes-1',
    }),
    {
      subjectId: 'sejarah',
      parentKind: 'subchapter',
      parentId: 'subchapter-1-1',
      containerId: 'chapter-1',
      moduleId: 'notes-1',
    },
  );
  assert.throws(
    () => _test.validateLocation({
      subjectId: 'sejarah',
      parentKind: 'chapter',
      parentId: 'chapter-1',
      moduleId: 'notes-1',
    }),
    /does not match/,
  );
});

test('nested progress identity matches the Flutter length-prefixed format', () => {
  assert.equal(
    _test.progressDocumentId({
      subjectId: 'english',
      parentKind: 'topic',
      parentId: 'grammar-basics',
      containerId: 'grammar',
    }),
    '7:english7:section7:grammar5:topic14:grammar-basics',
  );
});

test('Malaysia day and streak calculation are idempotent for one day', () => {
  assert.equal(
    _test.malaysiaDateKey(new Date('2026-11-04T16:30:00.000Z')),
    '2026-11-05',
  );
  const current = {
    currentStreak: 2,
    longestStreak: 2,
    lastQualifiedDate: '2026-11-04',
    todayStreakSecured: false,
    dailyStudyTarget: 3,
  };
  const first = _test.calculateStreak({
    current,
    nextPoints: 3,
    today: '2026-11-05',
    yesterday: '2026-11-04',
  });
  const repeat = _test.calculateStreak({
    current: { ...current, ...first },
    nextPoints: 5,
    today: '2026-11-05',
    yesterday: '2026-11-04',
  });
  assert.equal(first.currentStreak, 3);
  assert.equal(first.newlySecured, true);
  assert.equal(repeat.currentStreak, 3);
  assert.equal(repeat.newlySecured, false);
});
