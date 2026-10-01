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
const uid = 'test-economy-user';
const otherUid = 'other-economy-user';

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

test('default pet economy state can be created by owner', async () => {
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertSucceeds(setDoc(economyRef(db, uid), defaultEconomy()));
});

test('valid first coin credit create is allowed', async () => {
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertSucceeds(
    setDoc(
      economyRef(db, uid),
      defaultEconomy({
        pawCoins: 10,
        lifetimePawCoinsEarned: 10,
        creditedCoinActivities: {learn_math_chapter01: true},
      }),
    ),
  );
});

test('another user cannot create or update economy state', async () => {
  await seedEconomy();
  const db = testEnv.authenticatedContext(otherUid).firestore();

  await assertFails(setDoc(economyRef(db, uid), defaultEconomy()));
  await assertFails(
    updateDoc(economyRef(db, uid), {
      pawCoins: 15,
      lifetimePawCoinsEarned: 15,
      creditedCoinActivities: {learn_math_chapter01: true},
      updatedAt: serverTimestamp(),
    }),
  );
});

test('valid earned coin update is allowed once', async () => {
  await seedEconomy({
    pawCoins: 5,
    lifetimePawCoinsEarned: 5,
    creditedCoinActivities: {flashcards_math_chapter01: true},
  });
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertSucceeds(
    updateDoc(economyRef(db, uid), {
      pawCoins: 15,
      lifetimePawCoinsEarned: 15,
      creditedCoinActivities: {
        flashcards_math_chapter01: true,
        learn_math_chapter01: true,
      },
      updatedAt: serverTimestamp(),
    }),
  );
});

test('duplicate coin credit and invalid awards are rejected', async () => {
  await seedEconomy({
    pawCoins: 10,
    lifetimePawCoinsEarned: 10,
    creditedCoinActivities: {learn_math_chapter01: true},
  });
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertFails(
    updateDoc(economyRef(db, uid), {
      pawCoins: 20,
      lifetimePawCoinsEarned: 20,
      creditedCoinActivities: {learn_math_chapter01: true},
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(economyRef(db, uid), {
      pawCoins: 9,
      lifetimePawCoinsEarned: 9,
      creditedCoinActivities: {
        learn_math_chapter01: true,
        practice_math_chapter01: true,
      },
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(economyRef(db, uid), {
      pawCoins: 35,
      lifetimePawCoinsEarned: 35,
      creditedCoinActivities: {
        learn_math_chapter01: true,
        quiz_math_chapter01: true,
      },
      updatedAt: serverTimestamp(),
    }),
  );
});

test('purchase with enough balance deducts exact catalog price', async () => {
  await seedEconomy({
    pawCoins: 120,
    lifetimePawCoinsEarned: 120,
  });
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertSucceeds(
    updateDoc(economyRef(db, uid), {
      pawCoins: 30,
      totalPawCoinsSpent: 90,
      ownedCosmeticIds: ['wizard_hat'],
      equippedCosmetics: {head: 'wizard_hat', face: null, neck: null},
      lastPurchasedItemId: 'wizard_hat',
      lastPurchasedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );

  const snapshot = await getDoc(economyRef(db, uid));
  assert.equal(snapshot.data().pawCoins, 30);
});

test('purchase rejects insufficient balance, wrong price, unknown item, and duplicate', async () => {
  const db = testEnv.authenticatedContext(uid).firestore();

  await seedEconomy({
    pawCoins: 80,
    lifetimePawCoinsEarned: 80,
  });
  await assertFails(
    updateDoc(economyRef(db, uid), {
      pawCoins: -10,
      totalPawCoinsSpent: 90,
      ownedCosmeticIds: ['wizard_hat'],
      equippedCosmetics: {head: 'wizard_hat', face: null, neck: null},
      lastPurchasedItemId: 'wizard_hat',
      lastPurchasedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );

  await seedEconomy({
    pawCoins: 120,
    lifetimePawCoinsEarned: 120,
  });
  await assertFails(
    updateDoc(economyRef(db, uid), {
      pawCoins: 40,
      totalPawCoinsSpent: 80,
      ownedCosmeticIds: ['wizard_hat'],
      equippedCosmetics: {head: 'wizard_hat', face: null, neck: null},
      lastPurchasedItemId: 'wizard_hat',
      lastPurchasedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(economyRef(db, uid), {
      pawCoins: 119,
      totalPawCoinsSpent: 1,
      ownedCosmeticIds: ['mystery_boost'],
      equippedCosmetics: {head: 'mystery_boost', face: null, neck: null},
      lastPurchasedItemId: 'mystery_boost',
      lastPurchasedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );

  await seedEconomy({
    pawCoins: 30,
    lifetimePawCoinsEarned: 120,
    totalPawCoinsSpent: 90,
    ownedCosmeticIds: ['wizard_hat'],
    equippedCosmetics: {head: 'wizard_hat', face: null, neck: null},
    lastPurchasedItemId: 'wizard_hat',
    lastPurchasedAt: oldTimestamp(),
  });
  await assertFails(
    updateDoc(economyRef(db, uid), {
      pawCoins: 0,
      totalPawCoinsSpent: 120,
      ownedCosmeticIds: ['wizard_hat'],
      equippedCosmetics: {head: 'wizard_hat', face: null, neck: null},
      lastPurchasedItemId: 'wizard_hat',
      lastPurchasedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
});

test('owned cosmetic can be equipped, unequipped, and slot rules are enforced', async () => {
  await seedEconomy({
    pawCoins: 30,
    lifetimePawCoinsEarned: 120,
    totalPawCoinsSpent: 90,
    ownedCosmeticIds: ['wizard_hat', 'round_glasses'],
    equippedCosmetics: {head: 'wizard_hat', face: null, neck: null},
  });
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertSucceeds(
    updateDoc(economyRef(db, uid), {
      equippedCosmetics: {
        head: 'wizard_hat',
        face: 'round_glasses',
        neck: null,
      },
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    updateDoc(economyRef(db, uid), {
      equippedCosmetics: {head: null, face: 'round_glasses', neck: null},
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(economyRef(db, uid), {
      equippedCosmetics: {head: 'graduation_cap', face: null, neck: null},
      updatedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(economyRef(db, uid), {
      equippedCosmetics: {head: null, face: 'wizard_hat', neck: null},
      updatedAt: serverTimestamp(),
    }),
  );
});

test('pet habitat and evolution rules still work with economy rules present', async () => {
  await seedPetAndEngagement();
  const db = testEnv.authenticatedContext(uid).firestore();

  await assertSucceeds(
    updateDoc(petRef(db, uid), {
      habitatTheme: 'farm',
      updatedAt: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    updateDoc(petRef(db, uid), {
      growthStage: 'young',
      lastEvolutionAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );
});

async function seedEconomy(overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(economyRef(db, uid), defaultEconomy(overrides));
  });
}

async function seedPetAndEngagement() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'student_progress', uid, 'engagement', 'state'), {
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
    });
  });
}

function defaultEconomy(overrides = {}) {
  return {
    schemaVersion: 1,
    pawCoins: 0,
    lifetimePawCoinsEarned: 0,
    totalPawCoinsSpent: 0,
    creditedCoinActivities: {},
    ownedCosmeticIds: [],
    equippedCosmetics: {head: null, face: null, neck: null},
    lastPurchasedItemId: null,
    lastPurchasedAt: null,
    updatedAt: oldTimestamp(),
    ...overrides,
  };
}

function economyRef(db, userId) {
  return doc(db, 'student_progress', userId, 'pet_economy', 'state');
}

function petRef(db, userId) {
  return doc(db, 'student_progress', userId, 'pet', 'state');
}

function oldTimestamp() {
  return Timestamp.fromDate(new Date('2026-08-20T10:00:00.000Z'));
}

function hoursAgo(hours) {
  return Timestamp.fromMillis(Date.now() - hours * 60 * 60 * 1000);
}
