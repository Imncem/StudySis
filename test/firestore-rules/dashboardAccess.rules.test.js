const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  Timestamp,
  updateDoc,
} = require('firebase/firestore');

const projectId = 'studysis-d2151';
const adminUid = 'dashboard-admin';
const editorUid = 'science-editor';
const mathEditorUid = 'math-editor';
const otherUid = 'other-editor';
const now = Timestamp.fromMillis(1_700_000_000_000);
const later = Timestamp.fromMillis(1_700_000_001_000);
const verifiedSubjectIds = [
  'bahasa_melayu',
  'english',
  'math',
  'science',
  'sejarah',
  'geography',
  'rbt',
  'pendidikan_islam',
  'pjk',
  'seni',
];

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
  await seedAccess(adminUid, access({role: 'admin'}));
  await seedAccess(editorUid, access({subjectIds: ['science']}));
  await seedAccess(mathEditorUid, access({subjectIds: ['math']}));
  await seedAccess(otherUid, access({subjectIds: ['rbt']}));
  await seedCurriculum();
});

test('active admin can author and publish every verified subject', async () => {
  const db = dashboardDb(adminUid);

  await assertSucceeds(setDoc(moduleRef(db, 'science', 'chapter-01', 'admin-notes'), moduleData({status: 'active'})));
  await assertSucceeds(updateDoc(chapterRef(db, 'science', 'chapter-01'), {
    status: 'active',
    updatedAt: later,
  }));
});

test('admin may create missing generic curriculum items with optional grouping', async () => {
  const db = dashboardDb(adminUid);

  await assertSucceeds(setDoc(
    chapterRef(db, 'science', 'chapter_02'),
    chapterData({chapterNumber: 2, order: 2, title: 'Ecosystem'}),
  ));
  await assertSucceeds(setDoc(
    chapterRef(db, 'bahasa_melayu', 'unit_01'),
    chapterData({
      group: 'Tema 1: Kesihatan dan Kebersihan',
      title: 'Anda Sihat Anda Ceria',
    }),
  ));
  await assertFails(setDoc(
    chapterRef(db, 'bahasa_melayu', 'unit_02'),
    chapterData({group: ''}),
  ));
});

test('active editor can create and edit draft module content', async () => {
  const db = dashboardDb(editorUid);
  const draftModule = moduleRef(db, 'science', 'chapter-01', 'editor-notes');

  await assertSucceeds(setDoc(draftModule, moduleData()));
  await assertSucceeds(updateDoc(draftModule, {
    summary: 'Updated draft summary',
    updatedAt: later,
  }));
  await assertSucceeds(setDoc(
    doc(draftModule, 'sections', 'section-01'),
    noteData(),
  ));
  await assertSucceeds(setDoc(
    practiceRef(db, 'science', 'chapter-01', 'practice-01'),
    practiceData(),
  ));
});

test('active editor can author a draft module in every verified subject', async () => {
  const db = dashboardDb(editorUid);

  for (const subjectId of verifiedSubjectIds) {
    await assertSucceeds(setDoc(
      moduleRef(db, subjectId, 'chapter-01', `editor-${subjectId}`),
      moduleData(),
    ));
  }
});

test('legacy subject assignments do not restrict editor draft authoring', async () => {
  const db = dashboardDb(otherUid);

  await assertSucceeds(setDoc(moduleRef(db, 'science', 'chapter-01', 'collaborative'), moduleData()));
  await assertSucceeds(setDoc(practiceRef(db, 'science', 'chapter-01', 'collaborative'), practiceData()));
  await assertSucceeds(updateDoc(moduleRef(db, 'science', 'chapter-01', 'notes'), {
    summary: 'Updated by another active editor',
    updatedAt: later,
  }));
});

test('editors with empty or missing subjectIds can author every verified subject', async () => {
  await seedAccess('empty-editor', access({subjectIds: []}));
  const withoutSubjectIds = access();
  delete withoutSubjectIds.subjectIds;
  await seedAccess('legacy-editor', withoutSubjectIds);

  await assertSucceeds(setDoc(
    moduleRef(dashboardDb('empty-editor'), 'science', 'chapter-01', 'empty-access'),
    moduleData(),
  ));
  await assertSucceeds(setDoc(
    moduleRef(dashboardDb('legacy-editor'), 'math', 'chapter-01', 'legacy-access'),
    moduleData(),
  ));
});

test('inactive editor, missing access record and anonymous student fail closed', async () => {
  await seedAccess('inactive-editor', access({active: false, subjectIds: ['science']}));
  const inactiveDb = dashboardDb('inactive-editor');
  const missingDb = dashboardDb('missing-access');
  const anonymousDb = testEnv.authenticatedContext('student', {
    firebase: {sign_in_provider: 'anonymous'},
  }).firestore();

  await assertFails(setDoc(moduleRef(inactiveDb, 'science', 'chapter-01', 'blocked'), moduleData()));
  await assertFails(setDoc(moduleRef(missingDb, 'science', 'chapter-01', 'blocked'), moduleData()));
  await assertFails(setDoc(moduleRef(anonymousDb, 'science', 'chapter-01', 'blocked'), moduleData()));
  await assertFails(setDoc(chapterRef(inactiveDb, 'science', 'chapter_02'), chapterData()));
  await assertFails(setDoc(chapterRef(missingDb, 'science', 'chapter_02'), chapterData()));
  await assertFails(setDoc(chapterRef(anonymousDb, 'science', 'chapter_02'), chapterData()));
});

test('invalid subject and malformed access records fail closed', async () => {
  await seedAccess('bad-role', access({role: 'owner', subjectIds: ['science']}));
  await seedAccess('bad-subjects', access({subjectIds: ['not_a_subject']}));

  await assertFails(setDoc(moduleRef(dashboardDb(adminUid), 'unknown', 'chapter-01', 'blocked'), moduleData()));
  await assertFails(setDoc(chapterRef(dashboardDb(adminUid), 'unknown', 'chapter_01'), chapterData()));
  await assertFails(setDoc(moduleRef(dashboardDb('bad-role'), 'science', 'chapter-01', 'blocked'), moduleData()));
  await assertFails(setDoc(moduleRef(dashboardDb('bad-subjects'), 'science', 'chapter-01', 'blocked'), moduleData()));
});

test('access records are readable only by their password owner and protected metadata is not client-writable', async () => {
  const editorDb = dashboardDb(editorUid);
  const anonymousDb = testEnv.authenticatedContext(editorUid, {
    firebase: {sign_in_provider: 'anonymous'},
  }).firestore();

  await assertSucceeds(getDoc(accessRef(editorDb, editorUid)));
  await assertFails(getDoc(accessRef(editorDb, adminUid)));
  await assertFails(getDoc(accessRef(anonymousDb, editorUid)));
  await assertFails(updateDoc(accessRef(editorDb, editorUid), {active: false}));
  await assertFails(updateDoc(accessRef(dashboardDb(adminUid), editorUid), {active: false}));
});

test('dashboard access documents cannot be updated by clients', async () => {
  const db = dashboardDb(editorUid);

  await assertFails(updateDoc(accessRef(db, editorUid), {subjectIds: ['math']}));
  await assertFails(updateDoc(accessRef(db, editorUid), {role: 'admin'}));
  await assertFails(updateDoc(accessRef(db, editorUid), {active: false}));
  await assertFails(updateDoc(accessRef(db, editorUid), {displayName: 'Changed'}));
  await assertFails(updateDoc(accessRef(db, otherUid), {subjectIds: ['science']}));
  await assertFails(updateDoc(accessRef(dashboardDb(adminUid), adminUid), {
    subjectIds: ['science'],
  }));
});

test('editor cannot alter verified curriculum structure', async () => {
  const db = dashboardDb(editorUid);

  await assertFails(updateDoc(chapterRef(db, 'science', 'chapter-01'), {
    title: 'Changed by editor',
    updatedAt: later,
  }));
  await assertFails(setDoc(chapterRef(db, 'science', 'chapter-02'), chapterData()));
});

test('editor cannot publish modules, child content or practice questions', async () => {
  const db = dashboardDb(editorUid);

  await assertFails(updateDoc(moduleRef(db, 'science', 'chapter-01', 'notes'), {
    status: 'active',
    updatedAt: later,
  }));
  await assertFails(setDoc(
    doc(moduleRef(db, 'science', 'chapter-01', 'flashcards'), 'cards', 'card-01'),
    flashcardData({status: 'active'}),
  ));
  await assertFails(setDoc(
    practiceRef(db, 'science', 'chapter-01', 'practice-active'),
    practiceData({status: 'active'}),
  ));
  await assertFails(updateDoc(moduleRef(db, 'science', 'chapter-01', 'notes'), {
    status: 'archived',
    updatedAt: later,
  }));
  await assertFails(updateDoc(moduleRef(db, 'science', 'chapter-01', 'active-notes'), {
    status: 'archived',
    updatedAt: later,
  }));
});

test('editor cannot edit active module content', async () => {
  const db = dashboardDb(editorUid);

  await assertFails(setDoc(
    doc(moduleRef(db, 'science', 'chapter-01', 'active-notes'), 'sections', 'section-01'),
    noteData(),
  ));
});

test('Mathematics editor regression retains draft authoring access', async () => {
  const db = dashboardDb(mathEditorUid);

  await assertSucceeds(updateDoc(moduleRef(db, 'math', 'chapter-01', 'notes'), {
    summary: 'Mathematics draft updated',
    updatedAt: later,
  }));
  await assertSucceeds(setDoc(
    doc(moduleRef(db, 'math', 'chapter-01', 'notes'), 'sections', 'section-01'),
    noteData(),
  ));
});

function dashboardDb(uid) {
  return testEnv.authenticatedContext(uid, {
    email: `${uid}@example.test`,
    firebase: {sign_in_provider: 'password'},
  }).firestore();
}

async function seedAccess(uid, data) {
  await testEnv.withSecurityRulesDisabled((context) =>
    setDoc(accessRef(context.firestore(), uid), data),
  );
}

async function seedCurriculum() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const subjectId of verifiedSubjectIds) {
      await setDoc(chapterRef(db, subjectId, 'chapter-01'), chapterData());
    }
    for (const subjectId of ['science', 'math']) {
      await setDoc(moduleRef(db, subjectId, 'chapter-01', 'notes'), moduleData({type: 'notes'}));
      await setDoc(moduleRef(db, subjectId, 'chapter-01', 'flashcards'), moduleData({type: 'flashcards'}));
    }
    await setDoc(
      moduleRef(db, 'science', 'chapter-01', 'active-notes'),
      moduleData({type: 'notes', status: 'active'}),
    );
  });
}

function access(overrides = {}) {
  return {
    role: 'editor',
    active: true,
    displayName: 'Team member',
    email: 'member@example.test',
    subjectIds: [],
    ...overrides,
  };
}

function chapterData(overrides = {}) {
  return {
    chapterNumber: 1,
    title: 'Matter',
    textbookChapterTitle: 'Matter',
    learningObjectives: [],
    estimatedMinutes: 30,
    status: 'draft',
    order: 1,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function moduleData(overrides = {}) {
  return {
    title: 'Notes',
    type: 'notes',
    content: '',
    summary: '',
    estimatedMinutes: 5,
    difficulty: 'easy',
    order: 1,
    status: 'draft',
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function noteData(overrides = {}) {
  return {
    heading: 'Key idea',
    body: 'A valid note body.',
    example: '',
    order: 1,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function flashcardData(overrides = {}) {
  return {
    front: 'Question',
    back: 'Answer',
    hint: '',
    order: 1,
    status: 'draft',
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function practiceData(overrides = {}) {
  return {
    question: 'Which answer is correct?',
    options: ['A', 'B', 'C', 'D'],
    correctAnswerIndex: 0,
    explanation: 'A is correct.',
    hint: '',
    topic: 'Matter',
    difficulty: 'easy',
    order: 1,
    status: 'draft',
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function accessRef(db, uid) {
  return doc(db, 'dashboard_access', uid);
}

function chapterRef(db, subjectId, chapterId) {
  return doc(db, 'curriculum', 'form2', 'subjects', subjectId, 'chapters', chapterId);
}

function moduleRef(db, subjectId, chapterId, moduleId) {
  return doc(chapterRef(db, subjectId, chapterId), 'modules', moduleId);
}

function practiceRef(db, subjectId, chapterId, questionId) {
  return doc(chapterRef(db, subjectId, chapterId), 'practice_questions', questionId);
}
