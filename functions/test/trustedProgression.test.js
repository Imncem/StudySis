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
