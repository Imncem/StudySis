const test = require('node:test');
const assert = require('node:assert/strict');

const {
  _test: {
    validatePageTranslationRequest,
    hasProhibitedQuizTranslationField,
    fallbackPageTranslation,
    normalizePageTranslationJson,
    normalizeProviderJson,
    normalizeGeneratedQuestion,
    hasFakeTranslationPrefix,
    validateContextLength,
    checkRateLimit,
    callMuffinProvider,
    translatePageWithProvider,
    callOpenAiResponsesProvider,
    callGeminiProvider,
    dispatchProvider,
    extractResponseOutputText,
    extractGeminiOutputText,
    geminiEndpoint,
    geminiProfileForMuffin,
    geminiProfileForPageTranslation,
    geminiThinkingLevelForAction,
    isFreeTranslationRequest,
    walletFromData,
    cooldownMinutes,
    budgetBlockedResponse,
    resetCountdownText,
    providerDayInfo,
    timeZoneOffsetMs,
    providerCacheKey,
    standardMuffinTextFormat,
    generatedQuestionTextFormat,
    pageTranslationTextFormat,
    standardMuffinProviderSchema,
    generatedQuestionProviderSchema,
    pageTranslationProviderSchema,
    resetRateLimitForTests,
    limits,
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

test('quiz page translation normalizes exact stable IDs and preserves numeric options', () => {
  const questionId = 'oUk3WOGFR0V1mlbLsObl';
  const request = {
    pageType: 'quiz',
    pageId: `quiz_math_chapter-01_${questionId}`,
    sourceLanguage: 'ms',
    targetLanguage: 'en',
    fields: [
      { id: 'quizTitle', type: 'heading', text: 'Chapter 1 Quiz' },
      { id: 'questionProgress', type: 'label', text: 'Question 1' },
      {
        id: `question_${questionId}`,
        type: 'question',
        text: 'Apakah nombor seterusnya dalam jujukan berikut?\n4, 8, 12, 16, ...',
      },
      { id: 'option_a', type: 'option', text: '18' },
      { id: 'option_b', type: 'option', text: '20' },
      { id: 'option_c', type: 'option', text: '22' },
      { id: 'option_d', type: 'option', text: '24' },
    ],
  };

  const result = normalizePageTranslationJson(
    {
      fields: [
        { id: 'quizTitle', translatedText: 'Chapter 1 Quiz' },
        { id: 'questionProgress', translatedText: 'Question 1' },
        {
          id: `question_${questionId}`,
          translatedText:
            'What is the next number in the following sequence?\n4, 8, 12, 16, ...',
        },
      ],
    },
    request,
  );

  assert.equal(result.totalFieldCount, 7);
  assert.equal(result.fields.length, 7);
  assert.equal(result.translatedFieldCount, 1);
  assert.equal(result.unchangedFieldCount, 6);
  assert.equal(result.failedFieldCount, 0);
  assert.deepEqual(
    result.fields.map((field) => field.id),
    [
      'quizTitle',
      'questionProgress',
      `question_${questionId}`,
      'option_a',
      'option_b',
      'option_c',
      'option_d',
    ],
  );
});

test('page translation parser accepts translations alias defensively', () => {
  const result = normalizePageTranslationJson(
    {
      translations: [
        { id: 'body', translatedText: 'What is a pattern?' },
      ],
    },
    {
      pageType: 'learn',
      pageId: 'learn_math_chapter-01',
      sourceLanguage: 'ms',
      targetLanguage: 'en',
      fields: [{ id: 'body', type: 'paragraph', text: 'Apakah itu pola?' }],
    },
  );

  assert.equal(result.fields[0].id, 'body');
  assert.equal(result.fields[0].translatedText, 'What is a pattern?');
  assert.equal(result.failedFieldCount, 0);
});

test('normal Muffin response schema is accepted', () => {
  const result = normalizeProviderJson(
    {
      responseType: 'guidance',
      message: 'Compare neighbouring numbers first.',
      detectedLanguage: 'en',
    },
    {
      mode: 'quiz',
      action: 'guideQuestion',
      context: { currentQuestion: '7, 12, 17, 22, ...' },
    },
  );

  assert.equal(result.success, true);
  assert.equal(result.responseType, 'guidance');
  assert.equal(result.detectedLanguage, 'en');
});

test('malformed Muffin response is rejected safely', () => {
  assert.throws(
    () => normalizeProviderJson({ responseType: 'hint' }, {
      mode: 'practice',
      action: 'smallHint',
      context: {},
    }),
    /Missing response message/,
  );
});

test('generated-question schema requires answer-check fields', () => {
  const generated = normalizeGeneratedQuestion({
    question: 'Which sequence has a common difference?',
    options: ['2, 4, 6, 8', '1, 2, 4, 8', '3, 3, 4, 4', '9, 7, 4, 0'],
    correctOptionIndex: 0,
    explanation: 'The first sequence adds 2 each time.',
    topic: 'patterns',
    difficulty: 'easy',
  });

  assert.equal(generated.correctOptionIndex, 0);
  assert.equal(generated.generatedByMuffin, true);
});

test('generated-question schema rejects missing fields', () => {
  assert.throws(
    () => normalizeGeneratedQuestion({
      question: 'Which one?',
      options: ['A', 'B', 'C', 'D'],
    }),
    /Invalid generated question schema/,
  );
});

test('quiz response containing direct answer instruction is rejected', () => {
  assert.throws(
    () => normalizeProviderJson(
      {
        responseType: 'hint',
        message: 'Choose C because it is correct.',
      },
      {
        mode: 'quiz',
        action: 'smallHint',
        context: {},
      },
    ),
    /Quiz response exposed answer data/,
  );
});

test('context length limit rejects oversized Muffin context', () => {
  const message = validateContextLength({
    lessonBody: 'a'.repeat(7000),
  });

  assert.match(message, /too long/);
});

test('rate limit returns friendly application error', () => {
  resetRateLimitForTests();
  const res = fakeResponse();
  let allowed = true;
  for (let index = 0; index < limits.requestsPerMinute + 1; index += 1) {
    allowed = checkRateLimit('uid-rate-limit', res);
  }

  assert.equal(allowed, false);
  assert.equal(res.statusCode, 429);
  assert.match(res.body.message, /busy/);
});

test('Muffin wallet regenerates elapsed Bites and caps at 5', () => {
  const now = new Date('2026-08-11T12:00:00.000Z');
  const wallet = walletFromData({
    currentBites: 3,
    maxBites: 5,
    regenIntervalMinutes: 60,
    lastRegenAt: {
      toDate: () => new Date('2026-08-11T08:00:00.000Z'),
    },
    dailyResetDate: '2026-08-11',
    dailyUsedRequests: 4,
  }, now);

  assert.equal(wallet.currentBites, 5);
  assert.equal(wallet.dailyUsedRequests, 4);
});

test('Muffin wallet regeneration uses elapsed time thresholds', () => {
  const anchor = new Date('2026-08-11T18:20:00.000Z');
  const data = {
    currentBites: 0,
    maxBites: 5,
    regenIntervalMinutes: 60,
    lastRegenAt: { toDate: () => anchor },
  };

  assert.equal(
    walletFromData(data, new Date('2026-08-11T19:19:00.000Z')).currentBites,
    0,
  );
  assert.equal(
    walletFromData(data, new Date('2026-08-11T19:20:00.000Z')).currentBites,
    1,
  );
  assert.equal(
    walletFromData(data, new Date('2026-08-11T21:20:00.000Z')).currentBites,
    3,
  );
});

test('Muffin wallet preserves partial elapsed recharge anchor', () => {
  const wallet = walletFromData({
    currentBites: 0,
    maxBites: 5,
    regenIntervalMinutes: 60,
    lastRegenAt: {
      toDate: () => new Date('2026-08-11T18:20:00.000Z'),
    },
  }, new Date('2026-08-11T21:55:00.000Z'));

  assert.equal(wallet.currentBites, 3);
  assert.equal(wallet.lastRegenAt.toISOString(), '2026-08-11T21:20:00.000Z');
  assert.equal(cooldownMinutes(wallet, new Date('2026-08-11T21:55:00.000Z')), 25);
});

test('Muffin wallet caps regeneration and prevents banked excess', () => {
  const full = walletFromData({
    currentBites: 0,
    maxBites: 5,
    regenIntervalMinutes: 60,
    lastRegenAt: {
      toDate: () => new Date('2026-08-11T08:00:00.000Z'),
    },
  }, new Date('2026-08-11T18:00:00.000Z'));

  assert.equal(full.currentBites, 5);
  assert.equal(full.lastRegenAt.toISOString(), '2026-08-11T18:00:00.000Z');

  const afterSpend = walletFromData({
    currentBites: 4,
    maxBites: 5,
    regenIntervalMinutes: 60,
    lastRegenAt: {
      toDate: () => full.lastRegenAt,
    },
  }, new Date('2026-08-11T18:01:00.000Z'));

  assert.equal(afterSpend.currentBites, 4);
});

test('Muffin wallet daily usage resets by date', () => {
  const wallet = walletFromData({
    currentBites: 2,
    dailyResetDate: '2026-08-10',
    dailyUsedRequests: 12,
    lastRegenAt: {
      toDate: () => new Date('2026-08-11T11:30:00.000Z'),
    },
  }, new Date('2026-08-11T12:00:00.000Z'));

  assert.equal(wallet.dailyResetDate, '2026-08-11');
  assert.equal(wallet.dailyUsedRequests, 0);
});

test('Muffin budget blocked responses are student friendly', () => {
  const empty = budgetBlockedResponse('blocked_no_bites', 24);
  const daily = budgetBlockedResponse('blocked_daily_limit');

  assert.equal(empty.resultSource, 'blocked_no_bites');
  assert.match(empty.message, /Next Bite in 24 min/);
  assert.equal(daily.resultSource, 'blocked_daily_limit');
  assert.match(daily.message, /finished helping for today/);
});

test('Muffin cooldown rounds up remaining minutes', () => {
  const wallet = walletFromData({
    currentBites: 0,
    lastRegenAt: {
      toDate: () => new Date('2026-08-11T11:20:30.000Z'),
    },
  }, new Date('2026-08-11T12:00:00.000Z'));

  assert.equal(cooldownMinutes(wallet, new Date('2026-08-11T12:00:00.000Z')), 21);
});

test('Muffin cache keys are stable and separate endpoints', () => {
  const request = { action: 'explainSimply', context: { contextKey: 'a' } };

  assert.equal(providerCacheKey('askMuffin', request), providerCacheKey('askMuffin', request));
  assert.notEqual(
    providerCacheKey('askMuffin', request),
    providerCacheKey('translateMuffinPage', request),
  );
});

test('Muffin response translation is a free student Bite action', () => {
  assert.equal(isFreeTranslationRequest({ action: 'translate' }), true);
  assert.equal(isFreeTranslationRequest({ action: 'smallHint' }), false);
  assert.equal(isFreeTranslationRequest({}), false);
});

test('provider day key follows America Los Angeles instead of UTC', () => {
  const info = providerDayInfo(new Date('2026-08-11T06:30:00.000Z'));

  assert.equal(info.providerDayKey, '2026-08-10');
  assert.equal(info.nextProviderResetAt.toISOString(), '2026-08-11T07:00:00.000Z');
});

test('provider day key handles DST without fixed offset', () => {
  const summer = providerDayInfo(new Date('2026-08-11T06:30:00.000Z'));
  const winter = providerDayInfo(new Date('2026-01-11T07:30:00.000Z'));

  assert.equal(summer.providerDayKey, '2026-08-10');
  assert.equal(summer.nextProviderResetAt.toISOString(), '2026-08-11T07:00:00.000Z');
  assert.equal(winter.providerDayKey, '2026-01-10');
  assert.equal(winter.nextProviderResetAt.toISOString(), '2026-01-11T08:00:00.000Z');
  assert.notEqual(
    timeZoneOffsetMs('America/Los_Angeles', new Date('2026-08-11T12:00:00.000Z')),
    timeZoneOffsetMs('America/Los_Angeles', new Date('2026-01-11T12:00:00.000Z')),
  );
});

test('daily-rest countdown uses next provider reset timestamp', () => {
  assert.equal(
    resetCountdownText(
      new Date('2026-08-11T07:00:00.000Z'),
      new Date('2026-08-11T05:30:00.000Z'),
    ),
    '1 hr 30 min',
  );
});

test('Responses request uses current API shape', async () => {
  const originalFetch = global.fetch;
  let capturedBody;
  global.fetch = async (_endpoint, options) => {
    capturedBody = JSON.parse(options.body);
    return {
      ok: true,
      json: async () => ({
        output: [
          {
            type: 'message',
            content: [
              {
                type: 'output_text',
                text: '{"success":true,"responseType":"hint","message":"Try comparing neighbours.","detectedLanguage":"en"}',
              },
            ],
          },
        ],
      }),
    };
  };

  await callOpenAiResponsesProvider({
    apiKey: 'test',
    endpoint: 'https://api.openai.com/v1/responses',
    model: 'gpt-5.6-luna',
    instructions: 'SYSTEM POLICY',
    input: '{"curriculumContent":{}}',
    textFormat: standardMuffinTextFormat('smallHint'),
    maxTokens: 10,
    reasoning: { effort: 'minimal' },
  });

  assert.equal(capturedBody.model, 'gpt-5.6-luna');
  assert.equal(capturedBody.instructions, 'SYSTEM POLICY');
  assert.equal(capturedBody.input, '{"curriculumContent":{}}');
  assert.equal(capturedBody.store, false);
  assert.equal(capturedBody.max_output_tokens, 10);
  assert.equal(capturedBody.text.format.type, 'json_schema');
  assert.equal(capturedBody.text.format.strict, true);
  assert.equal(capturedBody.response_format, undefined);
  assert.equal(capturedBody.messages, undefined);
  assert.equal(capturedBody.max_tokens, undefined);
  global.fetch = originalFetch;
});

test('Gemini request uses generateContent shape and server-side API key header', async () => {
  const originalFetch = global.fetch;
  let capturedEndpoint;
  let capturedOptions;
  let capturedBody;
  global.fetch = async (endpoint, options) => {
    capturedEndpoint = endpoint;
    capturedOptions = options;
    capturedBody = JSON.parse(options.body);
    return {
      ok: true,
      json: async () => ({
        candidates: [
          {
            content: {
              parts: [
                {
                  text: '{"success":true,"responseType":"hint","message":"Cuba bandingkan nombor berjiran.","detectedLanguage":"ms"}',
                },
              ],
            },
          },
        ],
      }),
    };
  };

  const result = await callGeminiProvider({
    apiKey: 'gemini-secret',
    model: 'gemini-3.5-flash',
    instructions: 'SYSTEM POLICY',
    input: '{"curriculumContent":{"currentQuestion":"Apakah pola?"}}',
    schema: standardMuffinProviderSchema('smallHint').gemini,
    maxTokens: 10,
  });

  assert.equal(
    capturedEndpoint,
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent',
  );
  assert.equal(capturedOptions.headers['x-goog-api-key'], 'gemini-secret');
  assert.equal(capturedBody.systemInstruction.parts[0].text, 'SYSTEM POLICY');
  assert.equal(capturedBody.contents[0].role, 'user');
  assert.equal(capturedBody.generationConfig.responseMimeType, 'application/json');
  assert.equal(capturedBody.generationConfig.responseSchema.type, 'OBJECT');
  assert.equal(capturedBody.generationConfig.maxOutputTokens, 10);
  assert.equal(capturedBody.generationConfig.temperature, undefined);
  assert.equal(capturedBody.generationConfig.topP, undefined);
  assert.equal(capturedBody.generationConfig.topK, undefined);
  assert.equal(JSON.stringify(capturedBody).includes('gemini-secret'), false);
  assert.equal(capturedBody.messages, undefined);
  assert.equal(capturedBody.choices, undefined);
  assert.equal(result.provider, 'gemini');
  assert.equal(result.parsedPayload.detectedLanguage, 'ms');
  global.fetch = originalFetch;
});

test('Gemini profiles use action-specific thinking and larger token ceilings', () => {
  assert.deepEqual(
    geminiProfileForMuffin({ action: 'explainSimply' }),
    {
      maxTokens: 2048,
      retryMaxTokens: 4096,
      thinkingLevel: 'MINIMAL',
    },
  );
  assert.deepEqual(
    geminiProfileForMuffin({ action: 'guideQuestion' }),
    {
      maxTokens: 2048,
      retryMaxTokens: 4096,
      thinkingLevel: 'LOW',
    },
  );
  assert.deepEqual(
    geminiProfileForMuffin({ action: 'generateSimilarQuestion' }),
    {
      maxTokens: 3072,
      retryMaxTokens: 6144,
      thinkingLevel: 'LOW',
    },
  );
  assert.deepEqual(
    geminiProfileForPageTranslation(),
    {
      maxTokens: 4096,
      retryMaxTokens: 8192,
      thinkingLevel: 'MINIMAL',
    },
  );
  assert.equal(geminiThinkingLevelForAction('translate'), 'MINIMAL');
  assert.equal(geminiThinkingLevelForAction('smallHint'), 'MINIMAL');
  assert.equal(geminiThinkingLevelForAction('anotherExample'), 'MINIMAL');
  assert.equal(geminiThinkingLevelForAction('stillConfused'), 'MINIMAL');
});

test('Gemini request sends nested thinkingConfig without sampling overrides', async () => {
  const originalFetch = global.fetch;
  let capturedBody;
  global.fetch = async (_endpoint, options) => {
    capturedBody = JSON.parse(options.body);
    return {
      ok: true,
      json: async () => ({
        candidates: [
          {
            finishReason: 'STOP',
            content: {
              parts: [
                {
                  text: '{"success":true,"responseType":"hint","message":"Hint","detectedLanguage":"en"}',
                },
              ],
            },
          },
        ],
      }),
    };
  };

  await callGeminiProvider({
    apiKey: 'test',
    model: 'gemini-3.5-flash',
    instructions: '',
    input: '',
    schema: standardMuffinProviderSchema('smallHint').gemini,
    maxTokens: 2048,
    retryMaxTokens: 4096,
    thinkingLevel: 'MINIMAL',
  });

  assert.equal(capturedBody.generationConfig.maxOutputTokens, 2048);
  assert.equal(capturedBody.generationConfig.thinkingConfig.thinkingLevel, 'MINIMAL');
  assert.equal(capturedBody.generationConfig.thinkingLevel, undefined);
  assert.equal(capturedBody.generationConfig.temperature, undefined);
  assert.equal(capturedBody.generationConfig.topP, undefined);
  assert.equal(capturedBody.generationConfig.topK, undefined);
  assert.equal(capturedBody.generationConfig.thinkingBudget, undefined);
  global.fetch = originalFetch;
});

test('Muffin explain card uses MINIMAL nested thinkingConfig', async () => {
  const originalFetch = global.fetch;
  let capturedBody;
  global.fetch = async (_endpoint, options) => {
    capturedBody = JSON.parse(options.body);
    return {
      ok: true,
      json: async () => ({
        candidates: [
          {
            finishReason: 'STOP',
            content: {
              parts: [
                {
                  text: '{"success":true,"responseType":"explanation","message":"A pattern follows a rule.","detectedLanguage":"en"}',
                },
              ],
            },
          },
        ],
      }),
    };
  };

  await callMuffinProvider({
    requestId: 'explain-card-test',
    provider: 'gemini',
    openAiApiKey: '',
    openAiEndpoint: '',
    openAiModel: '',
    geminiApiKey: 'test',
    geminiModel: 'gemini-3.5-flash',
    request: {
      mode: 'flashcards',
      action: 'explainSimply',
      context: {
        mode: 'flashcards',
        currentScreen: 'flashcards',
        subjectId: 'math',
        chapterId: 'chapter-01',
        contextKey: 'flashcard_math_chapter-01_card_card-1_back',
        displayedLanguage: 'en',
        currentQuestion: 'What is a pattern?',
        lessonBody: 'A pattern follows a rule.',
      },
    },
  });

  assert.equal(capturedBody.generationConfig.maxOutputTokens, 2048);
  assert.equal(capturedBody.generationConfig.thinkingConfig.thinkingLevel, 'MINIMAL');
  assert.equal(capturedBody.generationConfig.thinkingLevel, undefined);
  assert.equal(capturedBody.generationConfig.responseMimeType, 'application/json');
  assert.equal(capturedBody.generationConfig.responseSchema.type, 'OBJECT');
  global.fetch = originalFetch;
});

test('Page translation uses MINIMAL nested thinkingConfig', async () => {
  const originalFetch = global.fetch;
  let capturedBody;
  global.fetch = async (_endpoint, options) => {
    capturedBody = JSON.parse(options.body);
    return {
      ok: true,
      json: async () => ({
        candidates: [
          {
            finishReason: 'STOP',
            content: {
              parts: [
                {
                  text: '{"success":true,"sourceLanguage":"ms","targetLanguage":"en","fields":[{"id":"question","translatedText":"What is a pattern?"}]}',
                },
              ],
            },
          },
        ],
      }),
    };
  };

  await translatePageWithProvider({
    requestId: 'translation-test',
    provider: 'gemini',
    openAiApiKey: '',
    openAiEndpoint: '',
    openAiModel: '',
    geminiApiKey: 'test',
    geminiModel: 'gemini-3.5-flash',
    request: {
      pageType: 'learn',
      pageId: 'learn_math_chapter-01',
      sourceLanguage: 'ms',
      targetLanguage: 'en',
      fields: [{ id: 'question', type: 'question', text: 'Apakah itu pola?' }],
    },
  });

  assert.equal(capturedBody.generationConfig.maxOutputTokens, 4096);
  assert.equal(capturedBody.generationConfig.thinkingConfig.thinkingLevel, 'MINIMAL');
  assert.equal(capturedBody.generationConfig.thinkingLevel, undefined);
  assert.equal(capturedBody.generationConfig.responseMimeType, 'application/json');
  assert.equal(capturedBody.generationConfig.responseSchema.type, 'OBJECT');
  global.fetch = originalFetch;
});

test('Page translation treats zero normalized fields as structured failure', async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => ({
    ok: true,
    json: async () => ({
      candidates: [
        {
          finishReason: 'STOP',
          content: {
            parts: [
              {
                text: '{"success":true,"sourceLanguage":"ms","targetLanguage":"en","fields":[]}',
              },
            ],
          },
        },
      ],
    }),
  });

  const result = await translatePageWithProvider({
    requestId: 'empty-translation-result-test',
    provider: 'gemini',
    openAiApiKey: '',
    openAiEndpoint: '',
    openAiModel: '',
    geminiApiKey: 'test',
    geminiModel: 'gemini-3.5-flash',
    request: {
      pageType: 'learn',
      pageId: 'learn_math_chapter-01',
      sourceLanguage: 'ms',
      targetLanguage: 'en',
      fields: [
        { id: 'body', type: 'paragraph', text: 'Apakah itu pola?' },
      ],
    },
  });

  assert.equal(result.success, false);
  assert.equal(result.resultSource, 'empty_translation_result');
  global.fetch = originalFetch;
});

test('Quiz guidance uses LOW nested thinkingConfig', async () => {
  const originalFetch = global.fetch;
  let capturedBody;
  global.fetch = async (_endpoint, options) => {
    capturedBody = JSON.parse(options.body);
    return {
      ok: true,
      json: async () => ({
        candidates: [
          {
            finishReason: 'STOP',
            content: {
              parts: [
                {
                  text: '{"success":true,"responseType":"guidance","message":"Compare each neighbouring pair.","detectedLanguage":"en"}',
                },
              ],
            },
          },
        ],
      }),
    };
  };

  await callMuffinProvider({
    requestId: 'quiz-guidance-test',
    provider: 'gemini',
    openAiApiKey: '',
    openAiEndpoint: '',
    openAiModel: '',
    geminiApiKey: 'test',
    geminiModel: 'gemini-3.5-flash',
    request: {
      mode: 'quiz',
      action: 'guideQuestion',
      context: {
        mode: 'quiz',
        currentScreen: 'quiz',
        subjectId: 'math',
        chapterId: 'chapter-01',
        contextKey: 'quiz_math_chapter-01_question_q1',
        displayedLanguage: 'en',
        currentQuestion: 'What is the common difference?',
        answerOptions: ['3', '5', '7', '12'],
      },
    },
  });

  assert.equal(capturedBody.generationConfig.maxOutputTokens, 2048);
  assert.equal(capturedBody.generationConfig.thinkingConfig.thinkingLevel, 'LOW');
  assert.equal(capturedBody.generationConfig.thinkingLevel, undefined);
  assert.equal(capturedBody.generationConfig.responseMimeType, 'application/json');
  assert.equal(capturedBody.generationConfig.responseSchema.type, 'OBJECT');
  global.fetch = originalFetch;
});

test('Generated Practice uses LOW nested thinkingConfig', async () => {
  const originalFetch = global.fetch;
  let capturedBody;
  global.fetch = async (_endpoint, options) => {
    capturedBody = JSON.parse(options.body);
    return {
      ok: true,
      json: async () => ({
        candidates: [
          {
            finishReason: 'STOP',
            content: {
              parts: [
                {
                  text: '{"success":true,"responseType":"generatedQuestion","message":"Try this.","detectedLanguage":"en","generatedQuestion":{"question":"Which sequence adds 3 each time?","options":["3, 6, 9, 12","2, 4, 8, 16","1, 3, 6, 10","9, 7, 5, 2"],"correctOptionIndex":0,"explanation":"The first sequence increases by 3 each step.","difficulty":"easy","topic":"patterns","generatedByMuffin":true}}',
                },
              ],
            },
          },
        ],
      }),
    };
  };

  await callMuffinProvider({
    requestId: 'generated-practice-test',
    provider: 'gemini',
    openAiApiKey: '',
    openAiEndpoint: '',
    openAiModel: '',
    geminiApiKey: 'test',
    geminiModel: 'gemini-3.5-flash',
    request: {
      mode: 'practice',
      action: 'generateSimilarQuestion',
      context: {
        mode: 'practice',
        currentScreen: 'practice',
        subjectId: 'math',
        chapterId: 'chapter-01',
        contextKey: 'practice_math_chapter-01_question_q1',
        displayedLanguage: 'en',
        currentQuestion: 'Which sequence adds the same amount?',
      },
    },
  });

  assert.equal(capturedBody.generationConfig.maxOutputTokens, 3072);
  assert.equal(capturedBody.generationConfig.thinkingConfig.thinkingLevel, 'LOW');
  assert.equal(capturedBody.generationConfig.thinkingLevel, undefined);
  assert.equal(capturedBody.generationConfig.responseMimeType, 'application/json');
  assert.equal(capturedBody.generationConfig.responseSchema.type, 'OBJECT');
  global.fetch = originalFetch;
});

test('Gemini endpoint encodes model name', () => {
  assert.equal(
    geminiEndpoint('models/gemini demo'),
    'https://generativelanguage.googleapis.com/v1beta/models/models%2Fgemini%20demo:generateContent',
  );
});

test('Gemini parser handles one normal text part', () => {
  const text = extractGeminiOutputText({
    candidates: [
      {
        finishReason: 'STOP',
        content: {
          parts: [
            {
              text: '{"success":true,"responseType":"hint","message":"Hint","detectedLanguage":"en"}',
            },
          ],
        },
      },
    ],
  });

  assert.equal(
    text,
    '{"success":true,"responseType":"hint","message":"Hint","detectedLanguage":"en"}',
  );
});

test('Gemini parser handles multiple final answer text parts', () => {
  const text = extractGeminiOutputText({
    candidates: [
      {
        content: {
          parts: [
            { text: '{"success":' },
            { text: 'true}' },
          ],
        },
      },
    ],
  });

  assert.equal(text, '{"success":true}');
});

test('Gemini parser ignores thought parts before final answer text', () => {
  const text = extractGeminiOutputText({
    candidates: [
      {
        finishReason: 'STOP',
        content: {
          parts: [
            { thought: true, text: 'internal/thought summary that is not JSON' },
            {
              text: '{"success":true,"responseType":"explanation","message":"Pola ialah susunan yang ikut peraturan.","detectedLanguage":"ms"}',
            },
          ],
        },
      },
    ],
  });

  assert.equal(
    text,
    '{"success":true,"responseType":"explanation","message":"Pola ialah susunan yang ikut peraturan.","detectedLanguage":"ms"}',
  );
});

test('Gemini parser keeps answer text when thoughtSignature metadata exists', () => {
  const text = extractGeminiOutputText({
    candidates: [
      {
        finishReason: 'STOP',
        content: {
          parts: [
            {
              thoughtSignature: 'opaque-provider-metadata',
              text: '{"success":true,"responseType":"hint","message":"Compare the rule.","detectedLanguage":"en"}',
            },
          ],
        },
      },
    ],
  });

  assert.equal(
    text,
    '{"success":true,"responseType":"hint","message":"Compare the rule.","detectedLanguage":"en"}',
  );
});

test('Gemini parser removes one outer JSON code fence', () => {
  const text = extractGeminiOutputText({
    candidates: [
      {
        finishReason: 'STOP',
        content: {
          parts: [
            {
              text: '```json\n{"success":true,"responseType":"hint","message":"Hint","detectedLanguage":"en"}\n```',
            },
          ],
        },
      },
    ],
  });

  assert.equal(
    text,
    '{"success":true,"responseType":"hint","message":"Hint","detectedLanguage":"en"}',
  );
});

test('Gemini parser rejects empty candidates', () => {
  assert.throws(() => extractGeminiOutputText({ candidates: [] }), /Missing Gemini candidates/);
});

test('Gemini parser rejects truncated candidate before parsing partial JSON', () => {
  assert.throws(
    () => extractGeminiOutputText({
      candidates: [
        {
          finishReason: 'MAX_TOKENS',
          content: {
            parts: [{ text: '{"success":true' }],
          },
        },
      ],
    }),
    /truncated/,
  );
});

test('Gemini parser handles blocked response', () => {
  assert.throws(
    () => extractGeminiOutputText({ promptFeedback: { blockReason: 'SAFETY' } }),
    /blocked/,
  );
});

test('Gemini MAX_TOKENS causes exactly one retry and returns parsed retry response', async () => {
  const originalFetch = global.fetch;
  const requestBodies = [];
  global.fetch = async (_endpoint, options) => {
    requestBodies.push(JSON.parse(options.body));
    if (requestBodies.length === 1) {
      return {
        ok: true,
        json: async () => ({
          candidates: [
            {
              finishReason: 'MAX_TOKENS',
              content: {
                parts: [{ text: '{"success":true' }],
              },
            },
          ],
          usageMetadata: {
            promptTokenCount: 100,
            candidatesTokenCount: 2048,
            thoughtsTokenCount: 1200,
            totalTokenCount: 2148,
          },
        }),
      };
    }
    return {
      ok: true,
      json: async () => ({
        candidates: [
          {
            finishReason: 'STOP',
            content: {
              parts: [
                {
                  text: '{"success":true,"responseType":"hint","message":"Retry worked.","detectedLanguage":"en"}',
                },
              ],
            },
          },
        ],
      }),
    };
  };

  const result = await callGeminiProvider({
    apiKey: 'test',
    model: 'gemini-3.5-flash',
    instructions: '',
    input: '',
    schema: standardMuffinProviderSchema('smallHint').gemini,
    maxTokens: 2048,
    retryMaxTokens: 4096,
    thinkingLevel: 'MINIMAL',
  });

  assert.equal(requestBodies.length, 2);
  assert.equal(requestBodies[0].generationConfig.maxOutputTokens, 2048);
  assert.equal(requestBodies[0].generationConfig.thinkingConfig.thinkingLevel, 'MINIMAL');
  assert.equal(requestBodies[0].generationConfig.thinkingLevel, undefined);
  assert.equal(requestBodies[1].generationConfig.maxOutputTokens, 4096);
  assert.equal(requestBodies[1].generationConfig.thinkingConfig.thinkingLevel, 'MINIMAL');
  assert.equal(requestBodies[1].generationConfig.thinkingLevel, undefined);
  assert.equal(result.parsedPayload.message, 'Retry worked.');
  global.fetch = originalFetch;
});

test('Gemini success reserves one provider attempt', async () => {
  const originalFetch = global.fetch;
  let fetchCount = 0;
  const reservedAttempts = [];
  global.fetch = async () => {
    fetchCount += 1;
    return {
      ok: true,
      json: async () => ({
        candidates: [
          {
            finishReason: 'STOP',
            content: {
              parts: [
                {
                  text: '{"success":true,"responseType":"hint","message":"One call worked.","detectedLanguage":"en"}',
                },
              ],
            },
          },
        ],
      }),
    };
  };

  const result = await callGeminiProvider({
    requestId: 'single-attempt-test',
    apiKey: 'test',
    model: 'gemini-3.5-flash',
    instructions: '',
    input: '',
    schema: standardMuffinProviderSchema('smallHint').gemini,
    maxTokens: 2048,
    retryMaxTokens: 4096,
    thinkingLevel: 'MINIMAL',
    beforeGeminiAttempt: async (attempt) => reservedAttempts.push(attempt),
  });

  assert.equal(fetchCount, 1);
  assert.equal(reservedAttempts.length, 1);
  assert.equal(reservedAttempts[0].truncationRetry, false);
  assert.equal(result.parsedPayload.message, 'One call worked.');
  global.fetch = originalFetch;
});

test('Gemini response translation still reserves provider attempt', async () => {
  const originalFetch = global.fetch;
  let fetchCount = 0;
  const reservedAttempts = [];
  global.fetch = async () => {
    fetchCount += 1;
    return {
      ok: true,
      json: async () => ({
        candidates: [
          {
            finishReason: 'STOP',
            content: {
              parts: [
                {
                  text: '{"success":true,"responseType":"translation","message":"Translated.","detectedLanguage":"en","translatedText":"Terjemahan."}',
                },
              ],
            },
          },
        ],
      }),
    };
  };

  const result = await callGeminiProvider({
    requestId: 'free-translation-provider-attempt-test',
    apiKey: 'test',
    model: 'gemini-3.5-flash',
    instructions: '',
    input: '',
    schema: standardMuffinProviderSchema('translate').gemini,
    maxTokens: 2048,
    retryMaxTokens: 4096,
    thinkingLevel: 'MINIMAL',
    beforeGeminiAttempt: async (attempt) => reservedAttempts.push(attempt),
  });

  assert.equal(fetchCount, 1);
  assert.equal(reservedAttempts.length, 1);
  assert.equal(reservedAttempts[0].truncationRetry, false);
  assert.equal(result.parsedPayload.responseType, 'translation');
  assert.equal(result.parsedPayload.translatedText, 'Terjemahan.');
  global.fetch = originalFetch;
});

test('Gemini retry reserves a second provider attempt but one logical action succeeds', async () => {
  const originalFetch = global.fetch;
  const reservedAttempts = [];
  let fetchCount = 0;
  global.fetch = async () => {
    fetchCount += 1;
    if (fetchCount === 1) {
      return {
        ok: true,
        json: async () => ({
          candidates: [
            {
              finishReason: 'MAX_TOKENS',
              content: { parts: [{ text: '{"success":true' }] },
            },
          ],
        }),
      };
    }
    return {
      ok: true,
      json: async () => ({
        candidates: [
          {
            finishReason: 'STOP',
            content: {
              parts: [
                {
                  text: '{"success":true,"responseType":"hint","message":"Retry worked.","detectedLanguage":"en"}',
                },
              ],
            },
          },
        ],
      }),
    };
  };

  const result = await callGeminiProvider({
    requestId: 'attempts-test',
    apiKey: 'test',
    model: 'gemini-3.5-flash',
    instructions: '',
    input: '',
    schema: standardMuffinProviderSchema('smallHint').gemini,
    maxTokens: 2048,
    retryMaxTokens: 4096,
    thinkingLevel: 'MINIMAL',
    beforeGeminiAttempt: async (attempt) => reservedAttempts.push(attempt),
  });

  assert.equal(fetchCount, 2);
  assert.equal(reservedAttempts.length, 2);
  assert.equal(reservedAttempts[0].truncationRetry, false);
  assert.equal(reservedAttempts[1].truncationRetry, true);
  assert.equal(result.parsedPayload.message, 'Retry worked.');
  global.fetch = originalFetch;
});

test('Gemini retry is blocked at provider soft limit before second fetch', async () => {
  const originalFetch = global.fetch;
  let fetchCount = 0;
  let reservations = 0;
  global.fetch = async () => {
    fetchCount += 1;
    return {
      ok: true,
      json: async () => ({
        candidates: [
          {
            finishReason: 'MAX_TOKENS',
            content: { parts: [{ text: '{"success":true' }] },
          },
        ],
      }),
    };
  };

  await assert.rejects(
    () => callGeminiProvider({
      requestId: 'limit-test',
      apiKey: 'test',
      model: 'gemini-3.5-flash',
      instructions: '',
      input: '',
      schema: standardMuffinProviderSchema('smallHint').gemini,
      maxTokens: 2048,
      retryMaxTokens: 4096,
      thinkingLevel: 'MINIMAL',
      beforeGeminiAttempt: async () => {
        reservations += 1;
        if (reservations === 2) {
          const error = new Error('Muffin daily provider budget is exhausted.');
          error.category = 'blocked_daily_limit';
          error.nextProviderResetAt = new Date('2026-08-11T07:00:00.000Z');
          throw error;
        }
      },
    }),
    (error) => error.category === 'blocked_daily_limit',
  );

  assert.equal(reservations, 2);
  assert.equal(fetchCount, 1);
  global.fetch = originalFetch;
});

test('Gemini provider soft limit blocks before first fetch', async () => {
  const originalFetch = global.fetch;
  let fetchCount = 0;
  let reservationChecks = 0;
  global.fetch = async () => {
    fetchCount += 1;
    throw new Error('fetch should not be called');
  };

  await assert.rejects(
    () => callGeminiProvider({
      requestId: 'initial-limit-test',
      apiKey: 'test',
      model: 'gemini-3.5-flash',
      instructions: '',
      input: '',
      schema: standardMuffinProviderSchema('smallHint').gemini,
      maxTokens: 2048,
      retryMaxTokens: 4096,
      thinkingLevel: 'MINIMAL',
      beforeGeminiAttempt: async () => {
        reservationChecks += 1;
        const error = new Error('Muffin daily provider budget is exhausted.');
        error.category = 'blocked_daily_limit';
        error.nextProviderResetAt = new Date('2026-08-11T07:00:00.000Z');
        throw error;
      },
    }),
    (error) => error.category === 'blocked_daily_limit',
  );

  assert.equal(reservationChecks, 1);
  assert.equal(fetchCount, 0);
  global.fetch = originalFetch;
});

test('Gemini provider error keeps sent attempt reserved', async () => {
  const originalFetch = global.fetch;
  let reservations = 0;
  let fetchCount = 0;
  global.fetch = async () => {
    fetchCount += 1;
    return {
      ok: false,
      status: 500,
      json: async () => ({ error: { status: 'INTERNAL', message: 'provider failed' } }),
    };
  };

  await assert.rejects(
    () => callGeminiProvider({
      requestId: 'provider-error-attempt-test',
      apiKey: 'test',
      model: 'gemini-3.5-flash',
      instructions: '',
      input: '',
      schema: standardMuffinProviderSchema('smallHint').gemini,
      maxTokens: 2048,
      retryMaxTokens: 4096,
      thinkingLevel: 'MINIMAL',
      beforeGeminiAttempt: async () => {
        reservations += 1;
      },
    }),
    (error) => error.category === 'provider_http',
  );

  assert.equal(reservations, 1);
  assert.equal(fetchCount, 1);
  global.fetch = originalFetch;
});

test('Gemini second MAX_TOKENS returns truncated error after one retry', async () => {
  const originalFetch = global.fetch;
  let callCount = 0;
  global.fetch = async () => {
    callCount += 1;
    return {
      ok: true,
      json: async () => ({
        candidates: [
          {
            finishReason: 'MAX_TOKENS',
            content: {
              parts: [{ text: '{"success":true' }],
            },
          },
        ],
      }),
    };
  };

  await assert.rejects(
    () => callGeminiProvider({
      apiKey: 'test',
      model: 'gemini-3.5-flash',
      instructions: '',
      input: '',
      schema: standardMuffinProviderSchema('smallHint').gemini,
      maxTokens: 2048,
      retryMaxTokens: 4096,
      thinkingLevel: 'MINIMAL',
    }),
    (error) => error.category === 'truncated',
  );
  assert.equal(callCount, 2);
  global.fetch = originalFetch;
});

test('Muffin returns friendly error after Gemini retry also truncates', async () => {
  const originalFetch = global.fetch;
  let callCount = 0;
  global.fetch = async () => {
    callCount += 1;
    return {
      ok: true,
      json: async () => ({
        candidates: [
          {
            finishReason: 'MAX_TOKENS',
            content: {
              parts: [{ text: '{"success":true' }],
            },
          },
        ],
      }),
    };
  };

  const response = await callMuffinProvider({
    requestId: 'test-request',
    provider: 'gemini',
    openAiApiKey: '',
    openAiEndpoint: '',
    openAiModel: '',
    geminiApiKey: 'test',
    geminiModel: 'gemini-3.5-flash',
    request: {
      mode: 'learn',
      action: 'explainSimply',
      context: {
        mode: 'learn',
        currentScreen: 'learn',
        subjectId: 'math',
        chapterId: 'chapter-01',
        contextKey: 'learn_math_chapter-01',
        displayedLanguage: 'ms',
        currentQuestion: 'Apakah itu pola?',
        lessonBody: 'Pola ialah susunan yang mengikut peraturan tertentu.',
      },
    },
  });

  assert.equal(callCount, 2);
  assert.equal(response.success, false);
  assert.match(response.message, /could not respond/i);
  global.fetch = originalFetch;
});

test('Gemini safety block is not retried', async () => {
  const originalFetch = global.fetch;
  let callCount = 0;
  global.fetch = async () => {
    callCount += 1;
    return {
      ok: true,
      json: async () => ({
        promptFeedback: { blockReason: 'SAFETY' },
      }),
    };
  };

  await assert.rejects(
    () => callGeminiProvider({
      apiKey: 'test',
      model: 'gemini-3.5-flash',
      instructions: '',
      input: '',
      schema: standardMuffinProviderSchema('smallHint').gemini,
      maxTokens: 2048,
      retryMaxTokens: 4096,
      thinkingLevel: 'MINIMAL',
    }),
    (error) => error.category === 'blocked',
  );
  assert.equal(callCount, 1);
  global.fetch = originalFetch;
});

test('Gemini HTTP error logs sanitized provider diagnostics in development', async () => {
  const originalFetch = global.fetch;
  const originalNodeEnv = process.env.NODE_ENV;
  const originalConsoleError = console.error;
  let loggedMessage = '';
  process.env.NODE_ENV = 'test';
  console.error = (message) => {
    loggedMessage = String(message);
  };
  global.fetch = async () => ({
    ok: false,
    status: 400,
    json: async () => ({
      error: {
        status: 'INVALID_ARGUMENT',
        message: 'Unknown name "thinkingLevel" at generationConfig.',
      },
    }),
  });

  await assert.rejects(
    () => callGeminiProvider({
      requestId: 'diagnostic-request',
      apiKey: 'secret-api-key',
      model: 'gemini-3.5-flash',
      instructions: '',
      input: '',
      schema: standardMuffinProviderSchema('smallHint').gemini,
      maxTokens: 2048,
      retryMaxTokens: 4096,
      thinkingLevel: 'MINIMAL',
    }),
    (error) => error.category === 'provider_http',
  );

  assert.match(loggedMessage, /requestId=diagnostic-request/);
  assert.match(loggedMessage, /httpStatus=400/);
  assert.match(loggedMessage, /providerStatus=INVALID_ARGUMENT/);
  assert.match(loggedMessage, /Unknown name/);
  assert.equal(loggedMessage.includes('secret-api-key'), false);
  global.fetch = originalFetch;
  console.error = originalConsoleError;
  process.env.NODE_ENV = originalNodeEnv;
});

test('Gemini malformed JSON is categorized', async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => ({
    ok: true,
    json: async () => ({
      candidates: [
        {
          content: {
            parts: [{ text: '{bad json' }],
          },
        },
      ],
    }),
  });

  await assert.rejects(
    () => callGeminiProvider({
      apiKey: 'test',
      model: 'gemini-3.5-flash',
      instructions: '',
      input: '',
      schema: standardMuffinProviderSchema('smallHint').gemini,
      maxTokens: 10,
    }),
    /Invalid Gemini JSON/,
  );
  global.fetch = originalFetch;
});

test('Gemini page translation parser ignores thought text and strips fences', async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => ({
    ok: true,
    json: async () => ({
      candidates: [
        {
          finishReason: 'STOP',
          content: {
            parts: [
              { thought: true, text: 'internal translation reasoning' },
              {
                text: '```json\n{"success":true,"sourceLanguage":"ms","targetLanguage":"en","fields":[{"id":"question","translatedText":"What is a pattern?"}]}\n```',
              },
            ],
          },
        },
      ],
    }),
  });

  const result = await callGeminiProvider({
    apiKey: 'test',
    model: 'gemini-3.5-flash',
    instructions: '',
    input: '',
    schema: pageTranslationProviderSchema().gemini,
    maxTokens: 10,
  });

  assert.equal(result.parsedPayload.fields[0].translatedText, 'What is a pattern?');
  global.fetch = originalFetch;
});

test('Gemini generated question parser uses final answer text only', async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => ({
    ok: true,
    json: async () => ({
      candidates: [
        {
          finishReason: 'STOP',
          content: {
            parts: [
              { thought: true, text: 'choose a similar arithmetic pattern' },
              {
                text: '{"success":true,"responseType":"generatedQuestion","message":"Try this one.","detectedLanguage":"en","generatedQuestion":{"question":"Which sequence adds 3 each time?","options":["3, 6, 9, 12","2, 4, 8, 16","1, 3, 6, 10","9, 7, 5, 2"],"correctOptionIndex":0,"explanation":"The first sequence increases by 3 each step.","difficulty":"easy","topic":"patterns","generatedByMuffin":true}}',
              },
            ],
          },
        },
      ],
    }),
  });

  const result = await callGeminiProvider({
    apiKey: 'test',
    model: 'gemini-3.5-flash',
    instructions: '',
    input: '',
    schema: generatedQuestionProviderSchema().gemini,
    maxTokens: 10,
  });

  assert.equal(result.parsedPayload.generatedQuestion.correctOptionIndex, 0);
  global.fetch = originalFetch;
});

test('Gemini schema-invalid output is rejected by normalizer', async () => {
  assert.throws(
    () => normalizeProviderJson(
      {
        success: true,
        responseType: 'hint',
        detectedLanguage: 'ms',
      },
      {
        mode: 'practice',
        action: 'smallHint',
        context: {},
      },
    ),
    /Missing response message/,
  );
});

test('provider selection calls Gemini when configured', async () => {
  const originalFetch = global.fetch;
  let endpointCalled;
  global.fetch = async (endpoint) => {
    endpointCalled = endpoint;
    return {
      ok: true,
      json: async () => ({
        candidates: [
          {
            content: {
              parts: [
                {
                  text: '{"success":true,"responseType":"hint","message":"Hint","detectedLanguage":"en"}',
                },
              ],
            },
          },
        ],
      }),
    };
  };

  const result = await dispatchProvider({
    provider: 'gemini',
    apiKey: 'gemini-secret',
    model: 'gemini-3.5-flash',
    prompt: { instructions: 'policy', input: '{}' },
    schema: standardMuffinProviderSchema('smallHint'),
    maxTokens: 10,
  });

  assert.equal(result.provider, 'gemini');
  assert.match(endpointCalled, /generativelanguage\.googleapis\.com/);
  global.fetch = originalFetch;
});

test('provider selection calls OpenAI when configured', async () => {
  const originalFetch = global.fetch;
  let endpointCalled;
  global.fetch = async (endpoint) => {
    endpointCalled = endpoint;
    return {
      ok: true,
      json: async () => ({
        output_text:
          '{"success":true,"responseType":"hint","message":"Hint","detectedLanguage":"en"}',
      }),
    };
  };

  const result = await dispatchProvider({
    provider: 'openai',
    apiKey: 'openai-secret',
    endpoint: 'https://api.openai.com/v1/responses',
    model: 'gpt-5.6-luna',
    prompt: { instructions: 'policy', input: '{}' },
    schema: standardMuffinProviderSchema('smallHint'),
    maxTokens: 10,
    reasoning: { effort: 'minimal' },
  });

  assert.equal(result.provider, 'openai');
  assert.equal(endpointCalled, 'https://api.openai.com/v1/responses');
  global.fetch = originalFetch;
});

test('OpenAI provider without bound secret returns configuration error', async () => {
  await assert.rejects(
    () => dispatchProvider({
      provider: 'openai',
      apiKey: '',
      endpoint: 'https://api.openai.com/v1/responses',
      model: 'gpt-5.6-luna',
      prompt: { instructions: 'policy', input: '{}' },
      schema: standardMuffinProviderSchema('smallHint'),
      maxTokens: 10,
      reasoning: { effort: 'minimal' },
    }),
    /OpenAI provider is not configured/,
  );
});

test('unknown provider returns configuration error', async () => {
  await assert.rejects(
    () => dispatchProvider({
      provider: 'unknown',
      apiKey: 'secret',
      model: 'model',
      prompt: { instructions: '', input: '' },
      schema: standardMuffinProviderSchema('smallHint'),
      maxTokens: 10,
    }),
    /Unsupported AI provider/,
  );
});

test('Gemini failure does not silently invoke OpenAI', async () => {
  const originalFetch = global.fetch;
  const endpoints = [];
  global.fetch = async (endpoint) => {
    endpoints.push(endpoint);
    return {
      ok: false,
      status: 500,
      json: async () => ({ error: 'gemini unavailable' }),
    };
  };

  await assert.rejects(
    () => dispatchProvider({
      provider: 'gemini',
      apiKey: 'gemini-secret',
      model: 'gemini-3.5-flash',
      prompt: { instructions: '', input: '' },
      schema: pageTranslationProviderSchema(),
      maxTokens: 10,
    }),
    /Gemini provider HTTP error/,
  );
  assert.equal(endpoints.length, 1);
  assert.match(endpoints[0], /generativelanguage\.googleapis\.com/);
  global.fetch = originalFetch;
});

test('extracts Responses output_text after reasoning item', () => {
  const text = extractResponseOutputText({
    output: [
      { type: 'reasoning', summary: [] },
      {
        type: 'message',
        content: [
          {
            type: 'output_text',
            text: '{"success":true}',
          },
        ],
      },
    ],
  });

  assert.equal(text, '{"success":true}');
});

test('extracts multiple Responses output_text content items', () => {
  const text = extractResponseOutputText({
    output: [
      {
        type: 'message',
        content: [
          { type: 'output_text', text: '{"success":' },
          { type: 'output_text', text: 'true}' },
        ],
      },
    ],
  });

  assert.equal(text, '{"success":true}');
});

test('malformed Responses output is rejected', () => {
  assert.throws(() => extractResponseOutputText({ output: 'bad' }), /Missing Responses API output/);
});

test('missing Responses output_text is rejected', () => {
  assert.throws(
    () => extractResponseOutputText({
      output: [{ type: 'message', content: [{ type: 'refusal', text: 'No' }] }],
    }),
    /Missing Responses API output_text/,
  );
});

test('strict schemas are configured for standard, generated, and page translation', () => {
  const standard = standardMuffinTextFormat('smallHint');
  const generated = generatedQuestionTextFormat();
  const page = pageTranslationTextFormat();

  assert.equal(standard.type, 'json_schema');
  assert.equal(standard.strict, true);
  assert.equal(standard.schema.additionalProperties, false);
  assert.deepEqual(standard.schema.required, [
    'success',
    'responseType',
    'message',
    'detectedLanguage',
  ]);
  assert.equal(generated.strict, true);
  assert.equal(
    generated.schema.properties.generatedQuestion.properties.options.minItems,
    4,
  );
  assert.equal(
    generated.schema.properties.generatedQuestion.properties.options.maxItems,
    4,
  );
  assert.equal(page.strict, true);
  assert.deepEqual(page.schema.properties.fields.items.required, [
    'id',
    'translatedText',
  ]);
});

test('provider error is categorized without exposing body', async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => ({
    ok: false,
    status: 500,
    json: async () => ({ error: 'secret provider detail' }),
  });

  await assert.rejects(
    () => callOpenAiResponsesProvider({
      apiKey: 'test',
      endpoint: 'https://api.openai.com/v1/responses',
      model: 'model',
      instructions: '',
      input: '',
      textFormat: standardMuffinTextFormat('smallHint'),
      maxTokens: 10,
    }),
    /Provider HTTP error/,
  );
  global.fetch = originalFetch;
});

test('invalid provider JSON is categorized', async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => ({
    ok: true,
    json: async () => ({
      output: [
        {
          type: 'message',
          content: [{ type: 'output_text', text: '{not json' }],
        },
      ],
    }),
  });

  await assert.rejects(
    () => callOpenAiResponsesProvider({
      apiKey: 'test',
      endpoint: 'https://api.openai.com/v1/responses',
      model: 'model',
      instructions: '',
      input: '',
      textFormat: standardMuffinTextFormat('smallHint'),
      maxTokens: 10,
    }),
    /Invalid provider JSON/,
  );
  global.fetch = originalFetch;
});

test('provider timeout is categorized', async () => {
  const originalFetch = global.fetch;
  const originalTimeout = limits.providerTimeoutMs;
  limits.providerTimeoutMs = 5;
  global.fetch = async (_endpoint, options) =>
    new Promise((_resolve, reject) => {
      options.signal.addEventListener('abort', () => {
        const error = new Error('aborted');
        error.name = 'AbortError';
        reject(error);
      });
    });

  await assert.rejects(
    () => callOpenAiResponsesProvider({
      apiKey: 'test',
      endpoint: 'https://api.openai.com/v1/responses',
      model: 'model',
      instructions: '',
      input: '',
      textFormat: standardMuffinTextFormat('smallHint'),
      maxTokens: 10,
    }),
    (error) => error.category === 'timeout',
  );
  global.fetch = originalFetch;
  limits.providerTimeoutMs = originalTimeout;
});

test('translation field IDs are preserved and math can remain unchanged', () => {
  const result = normalizePageTranslationJson(
    {
      fields: [
        { id: 'question', translatedText: 'What is the common difference?' },
        { id: 'sequence', translatedText: '7, 12, 17, 22, ...' },
      ],
    },
    {
      sourceLanguage: 'ms',
      targetLanguage: 'en',
      fields: [
        { id: 'question', text: 'Apakah beza sepunya?' },
        { id: 'sequence', text: '7, 12, 17, 22, ...' },
      ],
    },
  );

  assert.deepEqual(
    result.fields.map((field) => field.id),
    ['question', 'sequence'],
  );
  assert.equal(result.unchangedFieldCount, 1);
});

function fakeResponse() {
  return {
    statusCode: null,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
}
