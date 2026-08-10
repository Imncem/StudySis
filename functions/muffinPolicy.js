const allowedActions = {
  learn: [
    'askMuffin',
    'explainSimply',
    'translate',
    'anotherExample',
    'stillConfused',
  ],
  practice: [
    'askMuffin',
    'smallHint',
    'explainConcept',
    'translate',
    'generateSimilarQuestion',
    'stillConfused',
  ],
  quiz: [
    'smallHint',
    'explainConcept',
    'translate',
    'identifyPattern',
    'guideQuestion',
  ],
};

const generalSafetyPolicy = [
  'Act as a supportive Form 2 learning companion.',
  'Use age-appropriate language.',
  'Stay within the current subject and chapter.',
  'Prefer guidance over direct answers.',
  'Ask short guiding questions where useful.',
  'Explain one step at a time.',
  'Avoid overwhelming the student.',
  'Use the student preferred language when requested.',
  'Clearly distinguish generated questions from official curriculum questions.',
];

const quizSafetyPolicy = [
  'Never reveal the correct answer.',
  'Never name the correct answer option.',
  'Never say "Choose A/B/C/D".',
  'Never eliminate options in a way that exposes the answer.',
  'Never solve the entire question.',
  'Give conceptual or procedural guidance only.',
];

function validateMuffinRequest(body) {
  if (!body || typeof body !== 'object') {
    return 'Request body is required.';
  }
  const { mode, action, context } = body;
  if (!Object.prototype.hasOwnProperty.call(allowedActions, mode)) {
    return 'Unsupported Muffin mode.';
  }
  if (!allowedActions[mode].includes(action)) {
    return 'Unsupported Muffin action for this mode.';
  }
  if (!context || typeof context !== 'object') {
    return 'Muffin context is required.';
  }
  if (mode === 'quiz') {
    const forbiddenKeys = [
      'correctOptionIndex',
      'correctAnswer',
      'answer',
      'explanation',
    ];
    const leakedKey = forbiddenKeys.find((key) =>
      Object.prototype.hasOwnProperty.call(context, key),
    );
    if (leakedKey) return `Quiz context cannot include ${leakedKey}.`;
  }
  return null;
}

function buildSafetyPrompt(mode) {
  return [
    ...generalSafetyPolicy,
    ...(mode === 'quiz' ? quizSafetyPolicy : []),
    'Return structured JSON only.',
  ];
}

module.exports = {
  allowedActions,
  generalSafetyPolicy,
  quizSafetyPolicy,
  validateMuffinRequest,
  buildSafetyPrompt,
};
