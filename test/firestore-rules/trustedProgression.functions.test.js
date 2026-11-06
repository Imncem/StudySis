const test = require('node:test');
const assert = require('node:assert/strict');

const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const admin = require('../../functions/node_modules/firebase-admin');
const { processTrustedLearningEvent } = require('../../functions/trustedProgression');

const projectId = 'studysis-d2151';
const uid = 'trusted-function-user';
let testEnv;
let db;
let app;

test.before(async () => {
  testEnv = await initializeTestEnvironment({ projectId });
  app = admin.initializeApp({ projectId }, 'trusted-progression-tests');
  db = app.firestore();
});

test.after(async () => {
  await app.delete();
  await testEnv.cleanup();
});

test.beforeEach(async () => testEnv.clearFirestore());

test('legitimate module completion updates baseline progress and rewards once', async () => {
  await seedChapterModule({ moduleId: 'notes-1', type: 'notes' });
  await db.doc(`student_progress/${uid}/engagement/state`).set({
    totalXp: 90,
    level: 1,
    currentStreak: 0,
    longestStreak: 0,
    lastQualifiedDate: null,
    todayDateKey: '2026-11-05',
    todayStudyPoints: 1,
    dailyStudyTarget: 3,
    todayStreakSecured: false,
    creditedActivities: {},
    updatedAt: admin.firestore.Timestamp.fromDate(new Date('2026-11-05T00:00:00Z')),
  });

  const input = chapterInput('notes-1');
  const first = await processTrustedLearningEvent({
    admin,
    db,
    uid,
    activityType: 'notes',
    input,
    now: new Date('2026-11-05T02:00:00Z'),
  });
  const duplicate = await processTrustedLearningEvent({
    admin,
    db,
    uid,
    activityType: 'notes',
    input,
    now: new Date('2026-11-05T02:00:01Z'),
  });

  assert.equal(first.credited, true);
  assert.equal(first.xpAwarded, 20);
  assert.equal(first.pawCoinsAwarded, 10);
  assert.equal(first.state.totalXp, 110);
  assert.equal(first.state.currentStreak, 1);
  assert.equal(duplicate.credited, false);
  assert.equal(duplicate.xpAwarded, 0);

  const state = await db.doc(`student_progress/${uid}/engagement/state`).get();
  const progress = await db.doc(`student_progress/${uid}/chapters/math_chapter-1`).get();
  const economy = await db.doc(`student_progress/${uid}/pet_economy/state`).get();
  assert.equal(state.data().totalXp, 110);
  assert.equal(progress.data().learnCompleted, true);
  assert.equal(progress.data().overallProgress, 25);
  assert.equal(economy.data().pawCoins, 10);
});

test('invalid, inactive, and wrong-parent modules cannot generate rewards', async () => {
  await seedChapterModule({ moduleId: 'draft-notes', type: 'notes', status: 'draft' });
  await assert.rejects(
    processTrustedLearningEvent({
      admin,
      db,
      uid,
      activityType: 'notes',
      input: chapterInput('missing'),
    }),
    /not found/i,
  );
  await assert.rejects(
    processTrustedLearningEvent({
      admin,
      db,
      uid,
      activityType: 'notes',
      input: chapterInput('draft-notes'),
    }),
    /Draft or archived/,
  );
  await assert.rejects(
    processTrustedLearningEvent({
      admin,
      db,
      uid,
      activityType: 'notes',
      input: { ...chapterInput('draft-notes'), parentId: 'chapter-2' },
    }),
    /not active|not found/i,
  );
});

test('quiz score is server-calculated and duplicate submission is not rewarded', async () => {
  await seedChapterModule({ moduleId: 'quiz-1', type: 'quiz' });
  const questions = db
    .doc('curriculum/form2/subjects/math/chapters/chapter-1/modules/quiz-1')
    .collection('questions');
  await questions.doc('q1').set({ status: 'active', correctOptionIndex: 1 });
  await questions.doc('q2').set({ status: 'active', correctOptionIndex: 0 });
  const input = { ...chapterInput('quiz-1'), answers: { q1: 1, q2: 3 } };

  const first = await processTrustedLearningEvent({
    admin,
    db,
    uid,
    activityType: 'quiz',
    input,
    now: new Date('2026-11-05T02:00:00Z'),
  });
  const duplicate = await processTrustedLearningEvent({
    admin,
    db,
    uid,
    activityType: 'quiz',
    input,
    now: new Date('2026-11-05T03:00:00Z'),
  });

  assert.deepEqual(first.score, {
    correctCount: 1,
    incorrectCount: 1,
    unansweredCount: 0,
    totalQuestions: 2,
    percentage: 50,
    passed: false,
  });
  assert.equal(first.xpAwarded, 40);
  assert.equal(duplicate.xpAwarded, 0);
});

test('Practice questions cannot be mixed between two modules under one parent', async () => {
  await seedChapterModule({ moduleId: 'practice-a', type: 'practice' });
  await seedChapterModule({ moduleId: 'practice-b', type: 'practice' });
  const questions = db
    .doc('curriculum/form2/subjects/math/chapters/chapter-1')
    .collection('practice_questions');
  await questions.doc('a1').set({
    status: 'active',
    moduleId: 'practice-a',
    correctAnswerIndex: 0,
  });
  await questions.doc('b1').set({
    status: 'active',
    moduleId: 'practice-b',
    correctAnswerIndex: 1,
  });

  await assert.rejects(
    processTrustedLearningEvent({
      admin,
      db,
      uid,
      activityType: 'practice',
      input: { ...chapterInput('practice-a'), answers: { b1: 1 } },
    }),
    /invalid question/,
  );
});

test('trusted XP continues from existing baseline without resetting Study Pet state', async () => {
  await seedChapterModule({ moduleId: 'notes-1', type: 'notes' });
  await db.doc(`student_progress/${uid}/engagement/state`).set({
    totalXp: 430,
    level: 4,
    currentStreak: 2,
    longestStreak: 4,
    lastQualifiedDate: '2026-11-04',
    todayDateKey: '2026-11-05',
    todayStudyPoints: 0,
    dailyStudyTarget: 3,
    todayStreakSecured: false,
    creditedActivities: {},
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await db.doc(`student_progress/${uid}/pet/state`).set({
    schemaVersion: 1,
    petId: 'pet_bunny',
    stage: 'hatched',
    growthStage: 'hatchling',
  });

  await processTrustedLearningEvent({
    admin,
    db,
    uid,
    activityType: 'notes',
    input: chapterInput('notes-1'),
    now: new Date('2026-11-05T02:00:00Z'),
  });

  const state = await db.doc(`student_progress/${uid}/engagement/state`).get();
  const pet = await db.doc(`student_progress/${uid}/pet/state`).get();
  assert.equal(state.data().totalXp, 450);
  assert.equal(pet.data().petId, 'pet_bunny');
  assert.equal(pet.data().growthStage, 'hatchling');
});

async function seedChapterModule({ moduleId, type, status = 'active' }) {
  const chapter = db.doc('curriculum/form2/subjects/math/chapters/chapter-1');
  await chapter.set({ title: 'Chapter 1', status: 'active' }, { merge: true });
  await chapter.collection('modules').doc(moduleId).set({
    title: moduleId,
    type,
    status,
  });
}

function chapterInput(moduleId) {
  return {
    subjectId: 'math',
    parentKind: 'chapter',
    parentId: 'chapter-1',
    moduleId,
  };
}
