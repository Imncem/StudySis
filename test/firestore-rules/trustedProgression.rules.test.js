const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, serverTimestamp, setDoc, updateDoc } = require('firebase/firestore');

const projectId = 'studysis-d2151';
const uid = 'trusted-progress-user';
let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8'),
    },
  });
});

test.after(async () => testEnv.cleanup());
test.beforeEach(async () => testEnv.clearFirestore());

test('client cannot create or alter trusted chapter progress', async () => {
  const db = testEnv.authenticatedContext(uid).firestore();
  const ref = doc(db, 'student_progress', uid, 'chapters', 'math_chapter-01');
  await assertFails(setDoc(ref, progressPayload()));
  await seed(ref.path, progressPayload());
  await assertFails(updateDoc(ref, { overallProgress: 100, updatedAt: serverTimestamp() }));
});

test('client cannot arbitrarily increase XP or streak', async () => {
  const db = testEnv.authenticatedContext(uid).firestore();
  const ref = doc(db, 'student_progress', uid, 'engagement', 'state');
  await seed(ref.path, engagementPayload());
  await assertFails(updateDoc(ref, {
    totalXp: 999999,
    level: 999,
    currentStreak: 999,
    longestStreak: 999,
    updatedAt: serverTimestamp(),
  }));
});

test('client cannot create engagement day credits or trusted events', async () => {
  const db = testEnv.authenticatedContext(uid).firestore();
  await assertFails(setDoc(
    doc(db, 'student_progress', uid, 'engagement_days', '2026-11-05'),
    {
      studyPoints: 3,
      xpEarned: 40,
      streakSecured: true,
      qualifiedAt: serverTimestamp(),
      creditedActivities: { fabricated: true },
      updatedAt: serverTimestamp(),
    },
  ));
  await assertFails(setDoc(
    doc(db, 'student_progress', uid, 'trusted_events', 'fabricated'),
    { activityType: 'quiz', createdAt: serverTimestamp() },
  ));
});

test('owner can read server-created progress but another UID cannot', async () => {
  const path = `student_progress/${uid}/chapters/math_chapter-01`;
  await seed(path, progressPayload());
  await assertSucceeds(getDoc(doc(testEnv.authenticatedContext(uid).firestore(), path)));
  await assertFails(getDoc(doc(testEnv.authenticatedContext('other-user').firestore(), path)));
});

async function seed(documentPath, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), documentPath), data);
  });
}

function engagementPayload() {
  return {
    totalXp: 100,
    level: 2,
    currentStreak: 1,
    longestStreak: 1,
    lastQualifiedDate: '2026-11-05',
    todayDateKey: '2026-11-05',
    todayStudyPoints: 3,
    dailyStudyTarget: 3,
    todayStreakSecured: true,
    creditedActivities: {},
    updatedAt: new Date(),
  };
}

function progressPayload() {
  return {
    studentProfileId: 'qidah',
    subjectId: 'math',
    chapterId: 'chapter-01',
    learnCompleted: true,
    learnCompletedAt: new Date(),
    flashcardsMasteredCount: 0,
    flashcardsTotalCount: 0,
    flashcardsCompleted: false,
    masteredFlashcardIds: [],
    practiceLatestPercentage: 0,
    practiceBestPercentage: 0,
    practiceCorrectCount: 0,
    practiceTotalQuestions: 0,
    practiceCompletedAt: null,
    quizLatestPercentage: 0,
    quizBestPercentage: 0,
    quizCorrectCount: 0,
    quizIncorrectCount: 0,
    quizUnansweredCount: 0,
    quizPassed: false,
    quizCompletedAt: null,
    overallProgress: 25,
    lastActivityAt: new Date(),
    createdAt: new Date(),
    updatedAt: new Date(),
  };
}
