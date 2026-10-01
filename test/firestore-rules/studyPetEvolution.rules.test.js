const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
} = require('firebase/firestore');

const projectId = 'studysis-d2151';
const uid = 'test-momo-user';
const otherUid = 'other-user';

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, '../../firestore.rules'),
        'utf8',
      ),
    },
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
});

test('habitat forest to farm is allowed for owner', async () => {
  await seedState();
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertSucceeds(
    updateDoc(petRef(db, uid), {
      habitatTheme: 'farm',
      updatedAt: serverTimestamp(),
    }),
  );
});

test('exact Momo 430 total XP and 230 hatch baseline evolves to young', async () => {
  await seedState({
    engagement: { totalXp: 430 },
    pet: {
      growthStage: 'hatchling',
      xpBaselineAtHatch: 230,
      hatchedAt: hoursAgo(72),
    },
  });
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertSucceeds(updateDoc(petRef(db, uid), evolutionPayload('young')));

  const snapshot = await getDoc(petRef(db, uid));
  assert.equal(snapshot.data().growthStage, 'young');
  assert.equal(snapshot.data().stage, 'hatchling');
  assert.equal(snapshot.data().xpBaselineAtHatch, 230);
  assert.equal(snapshot.data().petId, 'pet_bunny');
  assert.equal(snapshot.data().eggId, 'egg_sprout');
});

test('young to evolved is allowed at 500 XP and 120 hours', async () => {
  await seedState({
    engagement: { totalXp: 730 },
    pet: {
      growthStage: 'young',
      xpBaselineAtHatch: 230,
      hatchedAt: hoursAgo(121),
    },
  });
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertSucceeds(updateDoc(petRef(db, uid), evolutionPayload('evolved')));
});

test('evolved to adult is allowed at 900 XP and 240 hours', async () => {
  await seedState({
    engagement: { totalXp: 1130 },
    pet: {
      growthStage: 'evolved',
      xpBaselineAtHatch: 230,
      hatchedAt: hoursAgo(241),
    },
  });
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertSucceeds(updateDoc(petRef(db, uid), evolutionPayload('adult')));
});

test('199 growth XP cannot evolve to young', async () => {
  await seedState({
    engagement: { totalXp: 429 },
    pet: {
      growthStage: 'hatchling',
      xpBaselineAtHatch: 230,
      hatchedAt: hoursAgo(72),
    },
  });
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertFails(updateDoc(petRef(db, uid), evolutionPayload('young')));
});

test('young evolution before 48 hours is denied', async () => {
  await seedState({
    engagement: { totalXp: 430 },
    pet: {
      growthStage: 'hatchling',
      xpBaselineAtHatch: 230,
      hatchedAt: hoursAgo(47),
    },
  });
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertFails(updateDoc(petRef(db, uid), evolutionPayload('young')));
});

test('stage skipping is denied', async () => {
  await seedState({
    engagement: { totalXp: 1130 },
    pet: {
      growthStage: 'hatchling',
      xpBaselineAtHatch: 230,
      hatchedAt: hoursAgo(241),
    },
  });
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertFails(updateDoc(petRef(db, uid), evolutionPayload('evolved')));
  await assertFails(updateDoc(petRef(db, uid), evolutionPayload('adult')));
});

test('young to adult skip is denied', async () => {
  await seedState({
    engagement: { totalXp: 1130 },
    pet: {
      growthStage: 'young',
      xpBaselineAtHatch: 230,
      hatchedAt: hoursAgo(241),
    },
  });
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertFails(updateDoc(petRef(db, uid), evolutionPayload('adult')));
});

test('backward evolution is denied', async () => {
  await seedState({
    engagement: { totalXp: 1130 },
    pet: {
      growthStage: 'evolved',
      xpBaselineAtHatch: 230,
      hatchedAt: hoursAgo(241),
    },
  });
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertFails(updateDoc(petRef(db, uid), evolutionPayload('young')));
});

test('another UID cannot evolve pet', async () => {
  await seedState();
  const db = testEnv.authenticatedContext(otherUid).firestore();

  await assertFails(updateDoc(petRef(db, uid), evolutionPayload('young')));
});

test('evolution cannot mutate xpBaselineAtHatch', async () => {
  await seedState();
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertFails(
    updateDoc(petRef(db, uid), {
      ...evolutionPayload('young'),
      xpBaselineAtHatch: 100,
    }),
  );
});

test('evolution cannot mutate hatchedAt', async () => {
  await seedState();
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertFails(
    updateDoc(petRef(db, uid), {
      ...evolutionPayload('young'),
      hatchedAt: hoursAgo(100),
    }),
  );
});

test('evolution cannot mutate petId', async () => {
  await seedState();
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertFails(
    updateDoc(petRef(db, uid), {
      ...evolutionPayload('young'),
      petId: 'pet_cat',
    }),
  );
});

test('evolution cannot mutate eggId', async () => {
  await seedState();
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertFails(
    updateDoc(petRef(db, uid), {
      ...evolutionPayload('young'),
      eggId: 'egg_starlight',
    }),
  );
});

test('serverTimestamp transforms satisfy timestamp checks', async () => {
  await seedState();
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertSucceeds(updateDoc(petRef(db, uid), evolutionPayload('young')));

  const snapshot = await getDoc(petRef(db, uid));
  assert.ok(snapshot.data().lastEvolutionAt instanceof Timestamp);
  assert.ok(snapshot.data().updatedAt instanceof Timestamp);
});

test('engagement get reads owner totalXp during evolution', async () => {
  await seedState();
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertSucceeds(updateDoc(petRef(db, uid), evolutionPayload('young')));

  const engagement = await getDoc(engagementRef(db, uid));
  assert.equal(engagement.data().totalXp, 430);
});

async function seedState({
  engagement = {},
  pet = {},
} = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(engagementRef(db, uid), {
      totalXp: 430,
      level: 4,
      currentStreak: 0,
      longestStreak: 0,
      lastQualifiedDate: null,
      todayDateKey: '2026-08-25',
      todayStudyPoints: 0,
      dailyStudyTarget: 3,
      todayStreakSecured: false,
      updatedAt: oldTimestamp(),
      ...engagement,
    });
    await setDoc(petRef(db, uid), {
      schemaVersion: 1,
      petUnlockAcknowledgedAt: oldTimestamp(),
      eggId: 'egg_sprout',
      petId: 'pet_bunny',
      petName: 'Momo',
      stage: 'hatchling',
      growthStage: 'hatchling',
      habitatTheme: 'forest',
      selectedAt: hoursAgo(120),
      xpBaselineAtSelection: 290,
      hatchXpTarget: 100,
      hatchDelayHours: 24,
      hatchedAt: hoursAgo(72),
      xpBaselineAtHatch: 230,
      updatedAt: oldTimestamp(),
      ...pet,
    });
  });
}

function evolutionPayload(nextStage) {
  return {
    growthStage: nextStage,
    lastEvolutionAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

function petRef(db, userId) {
  return doc(db, 'student_progress', userId, 'pet', 'state');
}

function engagementRef(db, userId) {
  return doc(db, 'student_progress', userId, 'engagement', 'state');
}

function oldTimestamp() {
  return Timestamp.fromDate(new Date('2026-08-20T10:00:00.000Z'));
}

function hoursAgo(hours) {
  return Timestamp.fromMillis(Date.now() - hours * 60 * 60 * 1000);
}
