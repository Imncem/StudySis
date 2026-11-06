const crypto = require('node:crypto');

const MALAYSIA_OFFSET_MS = 8 * 60 * 60 * 1000;

const REWARDS = Object.freeze({
  notes: { studyPoints: 2, xp: 20, pawCoins: 10, lifetime: true },
  flashcards: { studyPoints: 1, xp: 10, pawCoins: 5, lifetime: false },
  practice: { studyPoints: 2, xp: 20, pawCoins: 10, lifetime: false },
  quiz: { studyPoints: 3, xp: 40, pawCoins: 20, lifetime: false },
  savedFlashcards: { studyPoints: 1, xp: 10, pawCoins: 5, lifetime: false },
});

function createTrustedProgressionHandler({ admin, db, activityType }) {
  return async (req, res) => {
    const requestId = crypto.randomBytes(6).toString('hex');
    if (req.method !== 'POST') {
      res.status(405).json({ success: false, message: 'Method not allowed.' });
      return;
    }

    const auth = await authenticateRequest(admin, req, res, requestId);
    if (!auth) return;

    try {
      const result = await processTrustedLearningEvent({
        admin,
        db,
        uid: auth.uid,
        activityType,
        input: req.body,
      });
      res.status(200).json({ success: true, ...result });
    } catch (error) {
      const normalized = normalizeError(error);
      console.warn(
        `[StudySis][progression] requestId=${requestId} uid=${auth.uid} ` +
          `activity=${activityType} code=${normalized.code} message=${normalized.message}`,
      );
      res.status(normalized.httpStatus).json({
        success: false,
        code: normalized.code,
        message: normalized.publicMessage,
      });
    }
  };
}

async function authenticateRequest(admin, req, res, requestId) {
  const authorization = req.get('authorization') || '';
  const idToken = authorization.startsWith('Bearer ')
    ? authorization.substring('Bearer '.length)
    : '';
  if (!idToken) {
    res.status(401).json({ success: false, message: 'Authentication is required.' });
    return null;
  }
  try {
    return await admin.auth().verifyIdToken(idToken);
  } catch (error) {
    console.warn(
      `[StudySis][progression] requestId=${requestId} authentication failed`,
    );
    res.status(401).json({ success: false, message: 'Authentication is required.' });
    return null;
  }
}

async function processTrustedLearningEvent({
  admin,
  db,
  uid,
  activityType,
  input,
  now = new Date(),
}) {
  if (!uid || typeof uid !== 'string') throw eventError('unauthenticated');
  const reward = REWARDS[activityType];
  if (!reward) throw eventError('invalid-argument', 'Unsupported activity type.');

  const today = malaysiaDateKey(now);
  const yesterday = previousDateKey(today);
  if (activityType === 'savedFlashcards') {
    return processSavedFlashcards({ admin, db, uid, input, reward, today, yesterday });
  }

  const location = validateLocation(input);
  const refs = learningRefs(db, location, input.moduleId);
  const expectedTypes = expectedModuleTypes(activityType);

  return db.runTransaction(async (transaction) => {
    const chapterSnapshot = location.parentKind === 'chapter'
      ? null
      : await transaction.get(refs.chapterRef);
    const parentSnapshot = await transaction.get(refs.parentRef);
    const moduleSnapshot = await transaction.get(refs.moduleRef);
    if (chapterSnapshot &&
        (!chapterSnapshot.exists || chapterSnapshot.data()?.status !== 'active')) {
      throw eventError('failed-precondition', 'Curriculum container is not active.');
    }
    if (!parentSnapshot.exists || parentSnapshot.data()?.status !== 'active') {
      throw eventError('failed-precondition', 'Learning location is not active.');
    }
    if (!moduleSnapshot.exists) {
      throw eventError('not-found', 'Learning module was not found.');
    }
    const moduleData = moduleSnapshot.data();
    if (moduleData.status !== 'active') {
      throw eventError('failed-precondition', 'Draft or archived modules cannot be credited.');
    }
    if (!expectedTypes.has(String(moduleData.type || '').toLowerCase())) {
      throw eventError('failed-precondition', 'Learning module type does not match this activity.');
    }

    const evidence = await validateActivityEvidence({
      transaction,
      refs,
      activityType,
      input,
      moduleId: refs.moduleRef.id,
    });
    const eventKey = trustedEventKey({
      activityType,
      modulePath: refs.moduleRef.path,
      today,
      lifetime: reward.lifetime,
    });
    const eventRef = db.doc(`student_progress/${uid}/trusted_events/${eventKey}`);
    const stateRef = db.doc(`student_progress/${uid}/engagement/state`);
    const dayRef = db.doc(`student_progress/${uid}/engagement_days/${today}`);
    const economyRef = db.doc(`student_progress/${uid}/pet_economy/state`);
    const progressRef = db.doc(
      `student_progress/${uid}/chapters/${progressDocumentId(location)}`,
    );

    const [eventSnapshot, stateSnapshot, daySnapshot, economySnapshot, progressSnapshot] =
      await Promise.all([
        transaction.get(eventRef),
        transaction.get(stateRef),
        transaction.get(dayRef),
        transaction.get(economyRef),
        transaction.get(progressRef),
      ]);

    if (eventSnapshot.exists) {
      return duplicateResult(eventSnapshot.data(), stateSnapshot.data(), today);
    }

    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    const progress = buildProgressUpdate({
      existing: progressSnapshot.data(),
      location,
      activityType,
      evidence,
      timestamp,
    });
    transaction.set(progressRef, progress);

    const shouldReward = activityType === 'flashcards'
      ? evidence.milestoneReached
      : activityType === 'practice'
        ? evidence.eligibleForReward
        : true;
    if (!shouldReward) {
      return {
        credited: false,
        studyPointsAwarded: 0,
        xpAwarded: 0,
        pawCoinsAwarded: 0,
        streakNewlySecured: false,
        state: engagementState(stateSnapshot.data(), today),
        score: evidence.score || null,
      };
    }

    const current = engagementState(stateSnapshot.data(), today);
    const nextPoints = current.todayStudyPoints + reward.studyPoints;
    const streak = calculateStreak({ current, nextPoints, today, yesterday });
    const nextTotalXp = current.totalXp + reward.xp;
    const nextState = {
      totalXp: nextTotalXp,
      level: calculateLevel(nextTotalXp),
      currentStreak: streak.currentStreak,
      longestStreak: streak.longestStreak,
      lastQualifiedDate: streak.lastQualifiedDate,
      todayDateKey: today,
      todayStudyPoints: nextPoints,
      dailyStudyTarget: current.dailyStudyTarget,
      todayStreakSecured: streak.todayStreakSecured,
      creditedActivities: {
        ...objectMap(stateSnapshot.data()?.creditedActivities),
        [eventKey]: true,
      },
      updatedAt: timestamp,
    };
    transaction.set(stateRef, nextState);

    const day = daySnapshot.data() || {};
    transaction.set(dayRef, {
      studyPoints: nextPoints,
      xpEarned: integer(day.xpEarned) + reward.xp,
      streakSecured: streak.todayStreakSecured,
      qualifiedAt: streak.newlySecured ? timestamp : day.qualifiedAt || null,
      creditedActivities: { ...objectMap(day.creditedActivities), [eventKey]: true },
      updatedAt: timestamp,
    });

    const economy = petEconomyState(economySnapshot.data());
    transaction.set(economyRef, {
      ...economy,
      pawCoins: economy.pawCoins + reward.pawCoins,
      lifetimePawCoinsEarned: economy.lifetimePawCoinsEarned + reward.pawCoins,
      creditedCoinActivities: {
        ...economy.creditedCoinActivities,
        [eventKey]: true,
      },
      updatedAt: timestamp,
    });

    const result = {
      credited: true,
      studyPointsAwarded: reward.studyPoints,
      xpAwarded: reward.xp,
      pawCoinsAwarded: reward.pawCoins,
      previousTotalXp: current.totalXp,
      previousLevel: current.level,
      streakNewlySecured: streak.newlySecured,
      state: publicEngagementState(nextState),
      score: evidence.score || null,
    };
    transaction.create(eventRef, {
      schemaVersion: 1,
      activityType,
      curriculumPath: refs.moduleRef.path,
      moduleId: refs.moduleRef.id,
      subjectId: location.subjectId,
      parentKind: location.parentKind,
      parentId: location.parentId,
      containerId: location.containerId || null,
      malaysiaDateKey: today,
      reward: {
        studyPoints: reward.studyPoints,
        xp: reward.xp,
        pawCoins: reward.pawCoins,
      },
      result,
      createdAt: timestamp,
    });
    return result;
  });
}

async function processSavedFlashcards({ admin, db, uid, input, reward, today, yesterday }) {
  const ids = uniqueStringList(input.savedCardIds, 100);
  if (ids.length < 3) {
    throw eventError('failed-precondition', 'Review at least three saved flashcards.');
  }
  const savedRefs = ids.map((id) => db.doc(`student_progress/${uid}/saved_flashcards/${id}`));
  const eventKey = hashId(`savedFlashcards|${uid}|${today}`);
  return db.runTransaction(async (transaction) => {
    const savedSnapshots = await Promise.all(savedRefs.map((ref) => transaction.get(ref)));
    if (savedSnapshots.filter((snapshot) => snapshot.exists).length < 3) {
      throw eventError('failed-precondition', 'Saved flashcard review could not be verified.');
    }
    return applyRewardOnly({
      admin,
      db,
      transaction,
      uid,
      eventKey,
      activityType: 'savedFlashcards',
      reward,
      today,
      yesterday,
    });
  });
}

async function applyRewardOnly({
  admin,
  db,
  transaction,
  uid,
  eventKey,
  activityType,
  reward,
  today,
  yesterday,
}) {
  const eventRef = db.doc(`student_progress/${uid}/trusted_events/${eventKey}`);
  const stateRef = db.doc(`student_progress/${uid}/engagement/state`);
  const dayRef = db.doc(`student_progress/${uid}/engagement_days/${today}`);
  const economyRef = db.doc(`student_progress/${uid}/pet_economy/state`);
  const [eventSnapshot, stateSnapshot, daySnapshot, economySnapshot] = await Promise.all([
    transaction.get(eventRef),
    transaction.get(stateRef),
    transaction.get(dayRef),
    transaction.get(economyRef),
  ]);
  if (eventSnapshot.exists) {
    return duplicateResult(eventSnapshot.data(), stateSnapshot.data(), today);
  }
  const timestamp = admin.firestore.FieldValue.serverTimestamp();
  const current = engagementState(stateSnapshot.data(), today);
  const nextPoints = current.todayStudyPoints + reward.studyPoints;
  const streak = calculateStreak({ current, nextPoints, today, yesterday });
  const nextTotalXp = current.totalXp + reward.xp;
  const nextState = {
    totalXp: nextTotalXp,
    level: calculateLevel(nextTotalXp),
    currentStreak: streak.currentStreak,
    longestStreak: streak.longestStreak,
    lastQualifiedDate: streak.lastQualifiedDate,
    todayDateKey: today,
    todayStudyPoints: nextPoints,
    dailyStudyTarget: current.dailyStudyTarget,
    todayStreakSecured: streak.todayStreakSecured,
    creditedActivities: { ...objectMap(stateSnapshot.data()?.creditedActivities), [eventKey]: true },
    updatedAt: timestamp,
  };
  transaction.set(stateRef, nextState);
  const day = daySnapshot.data() || {};
  transaction.set(dayRef, {
    studyPoints: nextPoints,
    xpEarned: integer(day.xpEarned) + reward.xp,
    streakSecured: streak.todayStreakSecured,
    qualifiedAt: streak.newlySecured ? timestamp : day.qualifiedAt || null,
    creditedActivities: { ...objectMap(day.creditedActivities), [eventKey]: true },
    updatedAt: timestamp,
  });
  const economy = petEconomyState(economySnapshot.data());
  transaction.set(economyRef, {
    ...economy,
    pawCoins: economy.pawCoins + reward.pawCoins,
    lifetimePawCoinsEarned: economy.lifetimePawCoinsEarned + reward.pawCoins,
    creditedCoinActivities: { ...economy.creditedCoinActivities, [eventKey]: true },
    updatedAt: timestamp,
  });
  const result = {
    credited: true,
    studyPointsAwarded: reward.studyPoints,
    xpAwarded: reward.xp,
    pawCoinsAwarded: reward.pawCoins,
    previousTotalXp: current.totalXp,
    previousLevel: current.level,
    streakNewlySecured: streak.newlySecured,
    state: publicEngagementState(nextState),
  };
  transaction.create(eventRef, {
    schemaVersion: 1,
    activityType,
    malaysiaDateKey: today,
    reward,
    result,
    createdAt: timestamp,
  });
  return result;
}

function validateLocation(input) {
  if (!input || typeof input !== 'object') throw eventError('invalid-argument');
  const subjectId = requiredId(input.subjectId, 'subjectId');
  const parentId = requiredId(input.parentId, 'parentId');
  const moduleId = requiredId(input.moduleId, 'moduleId');
  const expectedKind = subjectId === 'sejarah'
    ? 'subchapter'
    : subjectId === 'bahasa_melayu' || subjectId === 'english'
      ? 'topic'
      : 'chapter';
  const parentKind = requiredId(input.parentKind, 'parentKind');
  if (parentKind !== expectedKind) {
    throw eventError('invalid-argument', 'Learning parent does not match the subject hierarchy.');
  }
  const containerId = expectedKind === 'chapter'
    ? null
    : requiredId(input.containerId, 'containerId');
  return { subjectId, parentKind, parentId, containerId, moduleId };
}

function learningRefs(db, location, moduleId) {
  const chapterId = location.containerId || location.parentId;
  const chapterRef = db.doc(
    `curriculum/form2/subjects/${location.subjectId}/chapters/${chapterId}`,
  );
  if (location.parentKind === 'chapter') {
    return {
      chapterRef,
      parentRef: chapterRef,
      moduleRef: chapterRef.collection('modules').doc(moduleId),
      practiceRef: chapterRef.collection('practice_questions'),
    };
  }
  const nestedCollection = location.parentKind === 'subchapter' ? 'subchapters' : 'topics';
  const parentRef = chapterRef.collection(nestedCollection).doc(location.parentId);
  return {
    chapterRef,
    parentRef,
    moduleRef: parentRef.collection('modules').doc(moduleId),
    practiceRef: parentRef.collection('practice_questions'),
  };
}

async function validateActivityEvidence({
  transaction,
  refs,
  activityType,
  input,
  moduleId,
}) {
  if (activityType === 'notes') return {};
  if (activityType === 'flashcards') {
    const reviewedIds = uniqueStringList(input.reviewedCardIds, 200);
    const cardsSnapshot = await transaction.get(refs.moduleRef.collection('cards'));
    const activeIds = new Set(
      cardsSnapshot.docs
        .filter((doc) => doc.data().status === 'active')
        .map((doc) => doc.id),
    );
    const verifiedIds = reviewedIds.filter((id) => activeIds.has(id));
    return {
      masteredIds: verifiedIds,
      totalCount: activeIds.size,
      milestoneReached: verifiedIds.length >= 5,
    };
  }
  const answers = answerMap(input.answers);
  const questionsSnapshot = activityType === 'quiz'
    ? await transaction.get(refs.moduleRef.collection('questions'))
    : await transaction.get(refs.practiceRef);
  let questions = questionsSnapshot.docs.filter((doc) =>
    doc.data().status === 'active' ||
    (activityType === 'practice' && !doc.data().status && doc.data().isPublished === true),
  );
  if (activityType === 'practice') {
    const assigned = questions.filter((doc) => doc.data().moduleId === moduleId);
    if (assigned.length > 0) {
      questions = assigned;
    } else {
      const modulesSnapshot = await transaction.get(
        refs.parentRef.collection('modules').where('status', '==', 'active'),
      );
      const activePracticeModules = modulesSnapshot.docs.filter(
        (doc) => String(doc.data().type || '').toLowerCase() === 'practice',
      );
      if (activePracticeModules.length !== 1 || activePracticeModules[0].id !== moduleId) {
        throw eventError('failed-precondition', 'Practice question ownership is ambiguous.');
      }
      questions = questions.filter((doc) => !String(doc.data().moduleId || '').trim());
    }
  }
  if (questions.length === 0) {
    throw eventError('failed-precondition', 'No active questions are available.');
  }
  const validIds = new Set(questions.map((doc) => doc.id));
  for (const id of Object.keys(answers)) {
    if (!validIds.has(id)) throw eventError('failed-precondition', 'Submission contains an invalid question.');
  }
  let correct = 0;
  let incorrect = 0;
  let unanswered = 0;
  for (const question of questions) {
    const selected = answers[question.id];
    const correctIndex = integer(
      question.data().correctOptionIndex ?? question.data().correctAnswerIndex,
      -1,
    );
    if (selected === undefined) unanswered += 1;
    else if (selected === correctIndex) correct += 1;
    else incorrect += 1;
  }
  const total = questions.length;
  const percentage = total === 0 ? 0 : Math.round((correct / total) * 100);
  return {
    eligibleForReward: Object.keys(answers).length >= 5,
    score: {
      correctCount: correct,
      incorrectCount: incorrect,
      unansweredCount: unanswered,
      totalQuestions: total,
      percentage,
      passed: percentage >= 70,
    },
  };
}

function buildProgressUpdate({ existing, location, activityType, evidence, timestamp }) {
  const data = { ...initialProgress(), ...(existing || {}) };
  if (activityType === 'notes') {
    data.learnCompleted = true;
    data.learnCompletedAt = data.learnCompletedAt || timestamp;
  } else if (activityType === 'flashcards') {
    const mastered = new Set([...(data.masteredFlashcardIds || []), ...evidence.masteredIds]);
    data.masteredFlashcardIds = [...mastered];
    data.flashcardsMasteredCount = mastered.size;
    data.flashcardsTotalCount = Math.max(integer(data.flashcardsTotalCount), evidence.totalCount);
    data.flashcardsCompleted =
      data.flashcardsTotalCount > 0 && data.flashcardsMasteredCount >= data.flashcardsTotalCount;
  } else if (activityType === 'practice') {
    const score = evidence.score;
    data.practiceLatestPercentage = score.percentage;
    data.practiceBestPercentage = Math.max(integer(data.practiceBestPercentage), score.percentage);
    data.practiceCorrectCount = score.correctCount;
    data.practiceTotalQuestions = score.totalQuestions;
    data.practiceCompletedAt = timestamp;
  } else if (activityType === 'quiz') {
    const score = evidence.score;
    data.quizLatestPercentage = score.percentage;
    data.quizBestPercentage = Math.max(integer(data.quizBestPercentage), score.percentage);
    data.quizCorrectCount = score.correctCount;
    data.quizIncorrectCount = score.incorrectCount;
    data.quizUnansweredCount = score.unansweredCount;
    data.quizPassed = score.passed;
    data.quizCompletedAt = timestamp;
  }
  data.studentProfileId = 'qidah';
  data.subjectId = location.subjectId;
  data.chapterId = location.parentId;
  data.parentKind = location.parentKind;
  data.parentId = location.parentId;
  if (location.containerId) {
    data.containerKind = location.parentKind === 'topic' ? 'section' : 'chapter';
    data.containerId = location.containerId;
  }
  data.overallProgress = calculateOverallProgress(data);
  data.lastActivityAt = timestamp;
  data.createdAt = data.createdAt || timestamp;
  data.updatedAt = timestamp;
  return data;
}

function initialProgress() {
  return {
    learnCompleted: false,
    learnCompletedAt: null,
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
    overallProgress: 0,
  };
}

function calculateOverallProgress(data) {
  let progress = data.learnCompleted ? 25 : 0;
  if (integer(data.flashcardsTotalCount) > 0) {
    progress += Math.round(
      25 * Math.min(integer(data.flashcardsMasteredCount), integer(data.flashcardsTotalCount)) /
        integer(data.flashcardsTotalCount),
    );
  }
  if (data.practiceCompletedAt) progress += 25;
  if (data.quizCompletedAt) progress += 25;
  return Math.min(100, progress);
}

function engagementState(data, today) {
  const raw = data || {};
  const sameDay = raw.todayDateKey === today;
  const currentStreak = raw.todayStreakSecured === true && integer(raw.currentStreak) < 1
    ? 1
    : integer(raw.currentStreak);
  const totalXp = integer(raw.totalXp);
  return {
    totalXp,
    level: calculateLevel(totalXp),
    currentStreak,
    longestStreak: Math.max(integer(raw.longestStreak), currentStreak),
    lastQualifiedDate: raw.lastQualifiedDate || null,
    todayDateKey: today,
    todayStudyPoints: sameDay ? integer(raw.todayStudyPoints) : 0,
    dailyStudyTarget: Math.max(1, integer(raw.dailyStudyTarget, 3)),
    todayStreakSecured: sameDay && raw.todayStreakSecured === true,
  };
}

function calculateStreak({ current, nextPoints, today, yesterday }) {
  let currentStreak = current.currentStreak;
  let longestStreak = current.longestStreak;
  let lastQualifiedDate = current.lastQualifiedDate;
  let todayStreakSecured = current.todayStreakSecured;
  let newlySecured = false;
  if (!todayStreakSecured && nextPoints >= current.dailyStudyTarget) {
    todayStreakSecured = true;
    if (lastQualifiedDate === today) currentStreak = Math.max(1, currentStreak);
    else {
      newlySecured = true;
      currentStreak = lastQualifiedDate === yesterday ? currentStreak + 1 : 1;
      lastQualifiedDate = today;
    }
  }
  if (todayStreakSecured) currentStreak = Math.max(1, currentStreak);
  longestStreak = Math.max(longestStreak, currentStreak);
  return {
    currentStreak,
    longestStreak,
    lastQualifiedDate,
    todayStreakSecured,
    newlySecured,
  };
}

function petEconomyState(data) {
  const raw = data || {};
  return {
    schemaVersion: 1,
    pawCoins: integer(raw.pawCoins),
    lifetimePawCoinsEarned: integer(raw.lifetimePawCoinsEarned),
    totalPawCoinsSpent: integer(raw.totalPawCoinsSpent),
    creditedCoinActivities: objectMap(raw.creditedCoinActivities),
    ownedCosmeticIds: Array.isArray(raw.ownedCosmeticIds) ? raw.ownedCosmeticIds : [],
    equippedCosmetics: {
      head: raw.equippedCosmetics?.head || null,
      face: raw.equippedCosmetics?.face || null,
      neck: raw.equippedCosmetics?.neck || null,
    },
    lastPurchasedItemId: raw.lastPurchasedItemId || null,
    lastPurchasedAt: raw.lastPurchasedAt || null,
  };
}

function duplicateResult(event, stateData, today) {
  const previous = event?.result || {};
  return {
    ...previous,
    credited: false,
    studyPointsAwarded: 0,
    xpAwarded: 0,
    pawCoinsAwarded: 0,
    streakNewlySecured: false,
    state: engagementState(stateData, today),
    duplicate: true,
  };
}

function publicEngagementState(state) {
  return {
    totalXp: state.totalXp,
    level: state.level,
    currentStreak: state.currentStreak,
    longestStreak: state.longestStreak,
    lastQualifiedDate: state.lastQualifiedDate,
    todayDateKey: state.todayDateKey,
    todayStudyPoints: state.todayStudyPoints,
    dailyStudyTarget: state.dailyStudyTarget,
    todayStreakSecured: state.todayStreakSecured,
  };
}

function expectedModuleTypes(activityType) {
  if (activityType === 'notes') return new Set(['notes']);
  if (activityType === 'flashcards') return new Set(['flashcards']);
  if (activityType === 'practice') return new Set(['practice']);
  return new Set(['quiz', 'test']);
}

function trustedEventKey({ activityType, modulePath, today, lifetime }) {
  return hashId(`${activityType}|${modulePath}|${lifetime ? 'lifetime' : today}`);
}

function progressDocumentId(location) {
  if (!location.containerId) return `${location.subjectId}_${location.parentId}`;
  return [
    location.subjectId,
    location.parentKind === 'topic' ? 'section' : 'chapter',
    location.containerId,
    location.parentKind,
    location.parentId,
  ].map((part) => `${encodeURIComponent(part).length}:${encodeURIComponent(part)}`).join('');
}

function malaysiaDateKey(now) {
  return new Date(now.getTime() + MALAYSIA_OFFSET_MS).toISOString().slice(0, 10);
}

function previousDateKey(dateKey) {
  const date = new Date(`${dateKey}T00:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() - 1);
  return date.toISOString().slice(0, 10);
}

function calculateLevel(totalXp) {
  if (totalXp < 100) return 1;
  if (totalXp < 250) return 2;
  if (totalXp < 450) return 3;
  if (totalXp < 700) return 4;
  if (totalXp < 1000) return 5;
  return 5 + Math.floor((totalXp - 1000) / 400) + 1;
}

function requiredId(value, field) {
  const result = typeof value === 'string' ? value.trim() : '';
  if (!result || result.length > 160 || result.includes('/')) {
    throw eventError('invalid-argument', `Invalid ${field}.`);
  }
  return result;
}

function answerMap(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw eventError('invalid-argument', 'Answers are required.');
  }
  const result = {};
  for (const [id, selected] of Object.entries(value)) {
    const questionId = requiredId(id, 'question ID');
    if (!Number.isInteger(selected) || selected < 0 || selected > 20) {
      throw eventError('invalid-argument', 'Invalid selected answer.');
    }
    result[questionId] = selected;
  }
  return result;
}

function uniqueStringList(value, maxLength) {
  if (!Array.isArray(value) || value.length > maxLength) {
    throw eventError('invalid-argument', 'Invalid item list.');
  }
  return [...new Set(value.map((item) => requiredId(item, 'item ID')))];
}

function integer(value, fallback = 0) {
  return Number.isFinite(value) ? Math.trunc(value) : fallback;
}

function objectMap(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}

function hashId(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function eventError(code, message) {
  const error = new Error(message || 'Invalid learning event.');
  error.code = code;
  return error;
}

function normalizeError(error) {
  const known = new Set(['invalid-argument', 'not-found', 'failed-precondition', 'unauthenticated']);
  const code = known.has(error?.code) ? error.code : 'internal';
  const httpStatus = code === 'unauthenticated'
    ? 401
    : code === 'not-found'
      ? 404
      : code === 'internal'
        ? 500
        : 400;
  return {
    code,
    httpStatus,
    message: String(error?.message || error),
    publicMessage: code === 'internal'
      ? 'Progress could not be saved. Please try again.'
      : String(error?.message || 'Learning activity could not be verified.'),
  };
}

module.exports = {
  createTrustedProgressionHandler,
  processTrustedLearningEvent,
  _test: {
    REWARDS,
    calculateLevel,
    calculateOverallProgress,
    calculateStreak,
    engagementState,
    malaysiaDateKey,
    previousDateKey,
    progressDocumentId,
    trustedEventKey,
    validateLocation,
  },
};
