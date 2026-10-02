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
  deleteDoc,
  getDoc,
  setDoc,
  Timestamp,
  updateDoc,
  writeBatch,
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

test('admin manages language topics and may publish topic modules', async () => {
  const db = dashboardDb(adminUid);
  const topic = topicRef(db, 'bahasa_melayu', 'tatabahasa', 'kata_nama');

  await assertSucceeds(setDoc(topic, topicData()));
  await assertSucceeds(updateDoc(topic, {status: 'active', updatedAt: later}));
  await assertSucceeds(setDoc(
    topicModuleRef(db, 'bahasa_melayu', 'tatabahasa', 'kata_nama', 'notes'),
    moduleData({status: 'active'}),
  ));
});

test('editor authors another editor draft inside a language topic but cannot change structure', async () => {
  const db = dashboardDb(editorUid);
  const topic = topicRef(db, 'bahasa_melayu', 'tatabahasa', 'kata_nama');
  const notes = topicModuleRef(db, 'bahasa_melayu', 'tatabahasa', 'kata_nama', 'notes');

  await assertFails(setDoc(
    topicRef(db, 'bahasa_melayu', 'tatabahasa', 'kata_kerja'),
    topicData({title: 'Kata Kerja', order: 2}),
  ));
  await assertFails(updateDoc(topic, {title: 'Changed', updatedAt: later}));
  await assertSucceeds(updateDoc(notes, {
    summary: 'Collaboratively updated topic notes',
    updatedAt: later,
  }));
  await assertSucceeds(setDoc(doc(notes, 'sections', 'section-01'), noteData()));
  await assertSucceeds(updateDoc(notes, {status: 'active', updatedAt: later}));
});

test('editor activates a normal module and its parent with status-only writes', async () => {
  const db = dashboardDb(editorUid);
  const batch = writeBatch(db);
  batch.update(chapterRef(db, 'science', 'chapter-01'), {
    status: 'active',
    updatedAt: later,
  });
  batch.update(moduleRef(db, 'science', 'chapter-01', 'notes'), {
    status: 'active',
    updatedAt: later,
  });

  await assertSucceeds(batch.commit());
});

test('editor activates Flashcard, Practice and Quiz content created by another editor', async () => {
  const db = dashboardDb(editorUid);

  await assertSucceeds(updateDoc(
    doc(moduleRef(db, 'science', 'chapter-01', 'flashcards'), 'cards', 'card-01'),
    {status: 'active', updatedAt: later},
  ));
  await assertSucceeds(updateDoc(
    doc(moduleRef(db, 'science', 'chapter-01', 'practice'), 'items', 'item-01'),
    {status: 'active', updatedAt: later},
  ));
  await assertSucceeds(updateDoc(
    doc(moduleRef(db, 'science', 'chapter-01', 'quiz'), 'questions', 'question-01'),
    {status: 'active', updatedAt: later},
  ));
  await assertSucceeds(updateDoc(
    practiceRef(db, 'science', 'chapter-01', 'practice-legacy'),
    {status: 'active', updatedAt: later},
  ));
});

test('editors activate BM and English topic modules and content', async () => {
  const db = dashboardDb(editorUid);
  const bmModule = topicModuleRef(db, 'bahasa_melayu', 'tatabahasa', 'kata_nama', 'notes');
  const englishModule = topicModuleRef(db, 'english', 'grammar', 'verbs', 'flashcards');

  const bmBatch = writeBatch(db);
  bmBatch.update(chapterRef(db, 'bahasa_melayu', 'tatabahasa'), {status: 'active', updatedAt: later});
  bmBatch.update(topicRef(db, 'bahasa_melayu', 'tatabahasa', 'kata_nama'), {status: 'active', updatedAt: later});
  bmBatch.update(bmModule, {status: 'active', updatedAt: later});
  await assertSucceeds(bmBatch.commit());

  await assertSucceeds(updateDoc(
    doc(englishModule, 'cards', 'card-01'),
    {status: 'active', updatedAt: later},
  ));
  const englishBatch = writeBatch(db);
  englishBatch.update(chapterRef(db, 'english', 'grammar'), {status: 'active', updatedAt: later});
  englishBatch.update(topicRef(db, 'english', 'grammar', 'verbs'), {status: 'active', updatedAt: later});
  englishBatch.update(englishModule, {status: 'active', updatedAt: later});
  await assertSucceeds(englishBatch.commit());
});

test('topic hierarchy is language-only and topic validation rejects invalid ordering', async () => {
  const adminDb = dashboardDb(adminUid);

  await assertFails(setDoc(
    topicRef(adminDb, 'science', 'chapter-01', 'invalid-topic'),
    topicData(),
  ));
  await assertFails(setDoc(
    topicRef(adminDb, 'english', 'grammar', 'invalid-order'),
    topicData({order: 0}),
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
  await assertFails(updateDoc(moduleRef(inactiveDb, 'science', 'chapter-01', 'notes'), {
    status: 'active',
    updatedAt: later,
  }));
  await assertFails(updateDoc(moduleRef(missingDb, 'science', 'chapter-01', 'notes'), {
    status: 'active',
    updatedAt: later,
  }));
  await assertFails(updateDoc(moduleRef(anonymousDb, 'science', 'chapter-01', 'notes'), {
    status: 'active',
    updatedAt: later,
  }));
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
  await assertFails(updateDoc(chapterRef(db, 'science', 'chapter-01'), {
    order: 9,
    updatedAt: later,
  }));
  await assertFails(updateDoc(chapterRef(db, 'science', 'chapter-01'), {
    group: 'Changed group',
    updatedAt: later,
  }));
  await assertFails(setDoc(chapterRef(db, 'science', 'chapter-02'), chapterData()));
  await assertFails(deleteDoc(chapterRef(db, 'science', 'chapter-01')));
  await assertFails(deleteDoc(topicRef(db, 'bahasa_melayu', 'tatabahasa', 'kata_nama')));
});

test('editor cannot archive content or withdraw active content to draft', async () => {
  const db = dashboardDb(editorUid);

  await assertFails(setDoc(
    moduleRef(db, 'science', 'chapter-01', 'created-active'),
    moduleData({status: 'active'}),
  ));
  await assertFails(setDoc(
    doc(moduleRef(db, 'science', 'chapter-01', 'flashcards'), 'cards', 'created-active'),
    flashcardData({status: 'active'}),
  ));
  await assertFails(updateDoc(moduleRef(db, 'science', 'chapter-01', 'notes'), {
    status: 'archived',
    updatedAt: later,
  }));
  await assertFails(updateDoc(moduleRef(db, 'science', 'chapter-01', 'active-notes'), {
    status: 'archived',
    updatedAt: later,
  }));
  await assertFails(updateDoc(moduleRef(db, 'science', 'chapter-01', 'active-notes'), {
    status: 'draft',
    updatedAt: later,
  }));
  await assertFails(updateDoc(chapterRef(db, 'science', 'active-chapter'), {
    status: 'draft',
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
    await setDoc(chapterRef(db, 'science', 'active-chapter'), chapterData({status: 'active'}));
    await setDoc(moduleRef(db, 'science', 'chapter-01', 'practice'), moduleData({type: 'practice'}));
    await setDoc(moduleRef(db, 'science', 'chapter-01', 'quiz'), moduleData({type: 'quiz'}));
    await setDoc(
      doc(moduleRef(db, 'science', 'chapter-01', 'flashcards'), 'cards', 'card-01'),
      flashcardData(),
    );
    await setDoc(
      doc(moduleRef(db, 'science', 'chapter-01', 'practice'), 'items', 'item-01'),
      practiceData(),
    );
    await setDoc(
      doc(moduleRef(db, 'science', 'chapter-01', 'quiz'), 'questions', 'question-01'),
      quizData(),
    );
    await setDoc(practiceRef(db, 'science', 'chapter-01', 'practice-legacy'), practiceData());
    await setDoc(
      chapterRef(db, 'bahasa_melayu', 'tatabahasa'),
      chapterData({title: 'Tatabahasa', textbookChapterTitle: 'Tatabahasa'}),
    );
    await setDoc(
      chapterRef(db, 'english', 'grammar'),
      chapterData({title: 'Grammar', textbookChapterTitle: 'Grammar'}),
    );
    await setDoc(
      topicRef(db, 'bahasa_melayu', 'tatabahasa', 'kata_nama'),
      topicData(),
    );
    await setDoc(
      topicModuleRef(db, 'bahasa_melayu', 'tatabahasa', 'kata_nama', 'notes'),
      moduleData({type: 'notes'}),
    );
    await setDoc(topicRef(db, 'english', 'grammar', 'verbs'), topicData({title: 'Verbs'}));
    await setDoc(
      topicModuleRef(db, 'english', 'grammar', 'verbs', 'flashcards'),
      moduleData({type: 'flashcards'}),
    );
    await setDoc(
      doc(topicModuleRef(db, 'english', 'grammar', 'verbs', 'flashcards'), 'cards', 'card-01'),
      flashcardData(),
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

function topicData(overrides = {}) {
  return {
    title: 'Kata Nama',
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

function quizData(overrides = {}) {
  return {
    question: 'Which answer is correct?',
    options: ['A', 'B', 'C', 'D'],
    correctOptionIndex: 0,
    explanation: 'A is correct.',
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

function topicRef(db, subjectId, chapterId, topicId) {
  return doc(chapterRef(db, subjectId, chapterId), 'topics', topicId);
}

function topicModuleRef(db, subjectId, chapterId, topicId, moduleId) {
  return doc(topicRef(db, subjectId, chapterId, topicId), 'modules', moduleId);
}

function practiceRef(db, subjectId, chapterId, questionId) {
  return doc(chapterRef(db, subjectId, chapterId), 'practice_questions', questionId);
}
