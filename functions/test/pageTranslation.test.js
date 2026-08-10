const test = require('node:test');
const assert = require('node:assert/strict');

const {
  _test: {
    validatePageTranslationRequest,
    hasProhibitedQuizTranslationField,
    fallbackPageTranslation,
    normalizePageTranslationJson,
    hasFakeTranslationPrefix,
  },
} = require('../index');

test('valid page translation request passes validation', () => {
  const error = validatePageTranslationRequest({
    pageType: 'practice',
    pageId: 'math_chapter-1_practice_q1',
    sourceLanguage: 'ms',
    targetLanguage: 'en',
    fields: [
      { id: 'question_q1', type: 'question', text: 'Apakah nombor seterusnya?' },
      { id: 'option_a', type: 'option', text: '8' },
    ],
  });

  assert.equal(error, null);
});

test('quiz page translation rejects correct-answer data', () => {
  const error = validatePageTranslationRequest({
    pageType: 'quiz',
    pageId: 'math_chapter-1_quiz_q1',
    sourceLanguage: 'en',
    targetLanguage: 'ms',
    fields: [
      { id: 'question_q1', type: 'question', text: 'What comes next?' },
      { id: 'correctAnswer', type: 'answer', text: 'Correct answer: 8' },
    ],
  });

  assert.match(error, /prohibited answer data/);
});

test('quiz prohibited field helper catches explanation and correct ids', () => {
  assert.equal(
    hasProhibitedQuizTranslationField({
      id: 'answerExplanation',
      type: 'explanation',
      text: 'Because it adds 2.',
    }),
    true,
  );
});

test('fallback page translation does not fabricate language prefixes', () => {
  const result = fallbackPageTranslation({
    sourceLanguage: 'en',
    targetLanguage: 'ms',
    fields: [
      { id: 'option_a', text: 'A' },
      { id: 'score', text: '75%' },
      { id: 'heading', text: 'Pattern' },
    ],
  });

  assert.deepEqual(
    result.fields.map((field) => field.id),
    ['option_a', 'score'],
  );
  assert.equal(result.fields[0].translatedText, 'A');
  assert.equal(result.fields[1].translatedText, '75%');
  assert.equal(
    result.fields.some((field) => /^Bahasa Melayu:|^English:|^Malay:/.test(field.translatedText)),
    false,
  );
  assert.equal(result.failedFieldCount, 1);
});

test('normalization rejects fake-prefixed provider fields', () => {
  const result = normalizePageTranslationJson(
    {
      fields: [
        { id: 'question', translatedText: 'English: Apakah pola?' },
        { id: 'option_a', translatedText: 'Number' },
      ],
    },
    {
      sourceLanguage: 'ms',
      targetLanguage: 'en',
      fields: [
        { id: 'question', text: 'Apakah pola?' },
        { id: 'option_a', text: 'Nombor' },
      ],
    },
  );

  assert.equal(hasFakeTranslationPrefix('English: Apakah pola?'), true);
  assert.deepEqual(result.fields, [
    { id: 'option_a', translatedText: 'Number' },
  ]);
  assert.equal(result.failedFieldCount, 1);
});
