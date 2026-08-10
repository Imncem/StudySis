const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildSafetyPrompt,
  validateMuffinRequest,
} = require('../muffinPolicy');

test('validates allowed quiz action without answer data', () => {
  const error = validateMuffinRequest({
    mode: 'quiz',
    action: 'smallHint',
    context: {
      subjectId: 'math',
      chapterId: 'chapter-1',
      currentQuestion: 'What comes next?',
      answerOptions: ['1', '2', '3', '4'],
    },
  });

  assert.equal(error, null);
});

test('rejects quiz context that includes answer data', () => {
  const error = validateMuffinRequest({
    mode: 'quiz',
    action: 'smallHint',
    context: {
      currentQuestion: 'What comes next?',
      correctOptionIndex: 2,
    },
  });

  assert.match(error, /correctOptionIndex/);
});

test('rejects unsupported mode action pair', () => {
  const error = validateMuffinRequest({
    mode: 'quiz',
    action: 'generateSimilarQuestion',
    context: { currentQuestion: 'What comes next?' },
  });

  assert.match(error, /Unsupported Muffin action/);
});

test('quiz safety prompt forbids direct answers', () => {
  const prompt = buildSafetyPrompt('quiz').join('\n');

  assert.match(prompt, /Never reveal the correct answer/);
  assert.match(prompt, /Never say "Choose A\/B\/C\/D"/);
});
