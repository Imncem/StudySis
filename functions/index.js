const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret, defineString } = require('firebase-functions/params');
const admin = require('firebase-admin');

const {
  buildSafetyPrompt,
  validateMuffinRequest,
} = require('./muffinPolicy');

admin.initializeApp();

const aiProviderApiKey = defineSecret('AI_PROVIDER_API_KEY');
const aiProviderEndpoint = defineString('AI_PROVIDER_ENDPOINT', {
  default: '',
});
const aiProviderModel = defineString('AI_PROVIDER_MODEL', {
  default: 'gpt-4o-mini',
});

exports.askMuffin = onRequest(
  {
    secrets: [aiProviderApiKey],
    timeoutSeconds: 30,
    cors: true,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({
        success: false,
        responseType: 'error',
        message: 'Method not allowed.',
      });
      return;
    }

    const authorization = req.get('authorization') || '';
    const idToken = authorization.startsWith('Bearer ')
      ? authorization.substring('Bearer '.length)
      : '';
    if (!idToken) {
      res.status(401).json({
        success: false,
        responseType: 'error',
        message: 'Authentication is required.',
      });
      return;
    }

    try {
      await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      console.error('[StudySis][muffin] auth verification failed', error);
      res.status(401).json({
        success: false,
        responseType: 'error',
        message: 'Authentication is required.',
      });
      return;
    }

    const validationError = validateMuffinRequest(req.body);
    if (validationError) {
      res.status(400).json({
        success: false,
        responseType: 'refusal',
        message: validationError,
      });
      return;
    }

    const body = req.body;
    const response = await callConfiguredProvider({
      apiKey: aiProviderApiKey.value(),
      endpoint: aiProviderEndpoint.value(),
      model: aiProviderModel.value(),
      safetyPrompt: buildSafetyPrompt(body.mode),
      request: body,
    });
    res.status(200).json(response);
  },
);

exports.translateMuffinPage = onRequest(
  {
    secrets: [aiProviderApiKey],
    timeoutSeconds: 30,
    cors: true,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({
        success: false,
        message: 'Method not allowed.',
      });
      return;
    }

    const authorization = req.get('authorization') || '';
    const idToken = authorization.startsWith('Bearer ')
      ? authorization.substring('Bearer '.length)
      : '';
    if (!idToken) {
      res.status(401).json({
        success: false,
        message: 'Authentication is required.',
      });
      return;
    }

    try {
      await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      console.error('[StudySis][page-translation] auth failed', error);
      res.status(401).json({
        success: false,
        message: 'Authentication is required.',
      });
      return;
    }

    const validationError = validatePageTranslationRequest(req.body);
    if (validationError) {
      res.status(400).json({
        success: false,
        message: validationError,
      });
      return;
    }

    const response = await translatePageWithProvider({
      apiKey: aiProviderApiKey.value(),
      endpoint: aiProviderEndpoint.value(),
      model: aiProviderModel.value(),
      request: req.body,
    });
    res.status(200).json(response);
  },
);

async function callConfiguredProvider({
  apiKey,
  endpoint,
  model,
  safetyPrompt,
  request,
}) {
  if (!apiKey || !endpoint) {
    console.warn('[StudySis][muffin] AI provider is not fully configured.');
    return fallbackResponse(request);
  }

  const providerResponse = await fetch(endpoint, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${apiKey}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: 'system',
          content: safetyPrompt.join('\n'),
        },
        {
          role: 'user',
          content: JSON.stringify(redactPromptInput(request)),
        },
      ],
      response_format: { type: 'json_object' },
      max_tokens: 450,
    }),
  });

  if (!providerResponse.ok) {
    console.error(
      '[StudySis][muffin] provider request failed',
      providerResponse.status,
    );
    return {
      success: false,
      responseType: 'error',
      message:
        'Muffin could not respond right now. Your learning progress is safe. Please try again.',
    };
  }

  const data = await providerResponse.json();
  const content = data?.choices?.[0]?.message?.content;
  if (typeof content !== 'string') return fallbackResponse(request);
  try {
    return normalizeProviderJson(JSON.parse(content));
  } catch (error) {
    console.error('[StudySis][muffin] provider JSON parse failed', error);
    return fallbackResponse(request);
  }
}

function redactPromptInput(request) {
  return {
    mode: request.mode,
    action: request.action,
    context: request.context,
    outputShape: {
      success: true,
      responseType: 'explanation | translation | example | hint | generatedQuestion | refusal | error',
      message: 'short supportive response',
      translatedText: 'optional translation',
      generatedQuestion:
        request.action === 'generateSimilarQuestion'
          ? {
              question: 'one generated MCQ',
              options: ['option 1', 'option 2', 'option 3', 'option 4'],
              difficulty: 'easy',
              topic: 'topic',
              generatedByMuffin: true,
            }
          : undefined,
      suggestedNextAction: 'optional short next step',
    },
  };
}

function normalizeProviderJson(data) {
  const allowedTypes = new Set([
    'explanation',
    'translation',
    'example',
    'hint',
    'generatedQuestion',
    'refusal',
    'error',
  ]);
  const responseType = allowedTypes.has(data.responseType)
    ? data.responseType
    : 'error';
  const response = {
    success: responseType !== 'error',
    responseType,
    message: String(data.message || ''),
  };
  if (typeof data.translatedText === 'string') {
    response.translatedText = data.translatedText;
  }
  if (
    data.generatedQuestion &&
    typeof data.generatedQuestion.question === 'string' &&
    Array.isArray(data.generatedQuestion.options)
  ) {
    response.generatedQuestion = {
      question: data.generatedQuestion.question,
      options: data.generatedQuestion.options.map((option) => String(option)),
      difficulty: String(data.generatedQuestion.difficulty || 'easy'),
      topic: String(data.generatedQuestion.topic || ''),
      generatedByMuffin: true,
    };
  }
  if (typeof data.suggestedNextAction === 'string') {
    response.suggestedNextAction = data.suggestedNextAction;
  }
  return response;
}

function fallbackResponse(request) {
  if (request.action === 'generateSimilarQuestion') {
    return {
      success: true,
      responseType: 'generatedQuestion',
      message: 'Generated by Muffin. Try this similar question for practice.',
      generatedQuestion: {
        question: 'Which sequence adds the same amount each time?',
        options: ['2, 4, 6, 8', '1, 2, 4, 8', '9, 7, 4, 0', '3, 3, 6, 9'],
        difficulty: 'easy',
        topic: 'patterns',
        generatedByMuffin: true,
      },
    };
  }
  if (request.action === 'translate') {
    return {
      success: true,
      responseType: 'translation',
      message: 'Here is a gentle translation.',
      translatedText:
        'Terjemahan ringkas: perhatikan corak, cari peraturan, kemudian gunakan peraturan itu.',
    };
  }
  return {
    success: true,
    responseType: request.mode === 'quiz' ? 'hint' : 'explanation',
    message:
      'Look at the idea one step at a time. What changes first, and what stays the same?',
  };
}

async function translatePageWithProvider({ apiKey, endpoint, model, request }) {
  if (!apiKey || !endpoint) return fallbackPageTranslation(request);

  const providerResponse = await fetch(endpoint, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${apiKey}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: 'system',
          content: [
            'Translate the provided StudySis page fields only.',
            'Translate every supplied field fully into the target language.',
            'Return JSON with success, sourceLanguage, targetLanguage, and fields.',
            'Preserve field IDs exactly.',
            'Do not prefix the output with the language name.',
            'Do not explain the translation.',
            'Do not answer questions.',
            'Do not solve Quiz or Practice questions.',
            'Preserve numbers, equations, variables, punctuation where meaningful, and option order.',
            'Do not return original text unless it is a proper name, mathematical expression, or already in the target language.',
          ].join('\n'),
        },
        {
          role: 'user',
          content: JSON.stringify({
            pageType: request.pageType,
            pageId: request.pageId,
            sourceLanguage: request.sourceLanguage,
            targetLanguage: request.targetLanguage,
            fields: request.fields,
          }),
        },
      ],
      response_format: { type: 'json_object' },
      max_tokens: 1200,
    }),
  });

  if (!providerResponse.ok) {
    console.error(
      '[StudySis][page-translation] provider failed',
      providerResponse.status,
    );
    return {
      success: false,
      message: 'Muffin could not translate this page right now.',
    };
  }

  const data = await providerResponse.json();
  const content = data?.choices?.[0]?.message?.content;
  if (typeof content !== 'string') return fallbackPageTranslation(request);
  try {
    return normalizePageTranslationJson(JSON.parse(content), request);
  } catch (error) {
    console.error('[StudySis][page-translation] provider JSON parse failed', error);
    return fallbackPageTranslation(request);
  }
}

function validatePageTranslationRequest(request) {
  const pageTypes = new Set(['home', 'learn', 'flashcards', 'practice', 'quiz']);
  const languages = new Set(['en', 'ms', 'unknown']);
  if (!request || typeof request !== 'object') return 'Invalid request.';
  if (!pageTypes.has(request.pageType)) return 'Unsupported page type.';
  if (typeof request.pageId !== 'string' || request.pageId.length > 160) {
    return 'Invalid page ID.';
  }
  if (!languages.has(request.sourceLanguage)) return 'Unsupported source language.';
  if (!new Set(['en', 'ms']).has(request.targetLanguage)) {
    return 'Unsupported target language.';
  }
  if (!Array.isArray(request.fields)) return 'Fields are required.';
  if (request.fields.length < 1 || request.fields.length > 80) {
    return 'Invalid field count.';
  }
  let totalText = 0;
  for (const field of request.fields) {
    if (!field || typeof field !== 'object') return 'Invalid field.';
    if (typeof field.id !== 'string' || field.id.length > 80) {
      return 'Invalid field ID.';
    }
    if (typeof field.type !== 'string' || field.type.length > 40) {
      return 'Invalid field type.';
    }
    if (typeof field.text !== 'string' || field.text.length > 1200) {
      return 'Invalid field text.';
    }
    totalText += field.text.length;
    if (request.pageType === 'quiz' && hasProhibitedQuizTranslationField(field)) {
      return 'Quiz translation request contains prohibited answer data.';
    }
  }
  if (totalText > 9000) return 'Page text is too long.';
  return null;
}

function hasProhibitedQuizTranslationField(field) {
  const id = field.id.toLowerCase();
  const type = field.type.toLowerCase();
  const text = field.text.toLowerCase();
  return (
    id.includes('correct') ||
    type.includes('correct') ||
    type.includes('explanation') ||
    text.includes('correctoptionindex') ||
    text.includes('correct answer')
  );
}

function normalizePageTranslationJson(data, request) {
  const allowedIds = new Set(request.fields.map((field) => field.id));
  const originalById = new Map(request.fields.map((field) => [field.id, field.text]));
  const fields = [];
  const seenIds = new Set();
  let unchangedFieldCount = 0;
  let failedFieldCount = 0;
  for (const field of data.fields || []) {
    const id = String(field.id || '');
    if (!allowedIds.has(id) || seenIds.has(id)) {
      failedFieldCount += 1;
      continue;
    }
    seenIds.add(id);
    const translatedText = String(field.translatedText || '').trim();
    const originalText = String(originalById.get(id) || '').trim();
    if (!translatedText || hasFakeTranslationPrefix(translatedText)) {
      failedFieldCount += 1;
      continue;
    }
    if (translatedText === originalText) {
      if (preserveValue(originalText)) {
        unchangedFieldCount += 1;
      } else {
        failedFieldCount += 1;
        continue;
      }
    }
    fields.push({
      id,
      translatedText,
    });
  }
  failedFieldCount += request.fields.length - seenIds.size;
  const translatedFieldCount = fields.length - unchangedFieldCount;
  return {
    success: true,
    sourceLanguage: request.sourceLanguage,
    targetLanguage: request.targetLanguage,
    translatedFieldCount,
    unchangedFieldCount,
    failedFieldCount,
    totalFieldCount: request.fields.length,
    isComplete: failedFieldCount === 0,
    fields,
  };
}

function fallbackPageTranslation(request) {
  const fields = request.fields
    .filter((field) => preserveValue(field.text))
    .map((field) => ({
      id: field.id,
      translatedText: field.text,
    }));
  return {
    success: fields.length > 0,
    sourceLanguage: request.sourceLanguage,
    targetLanguage: request.targetLanguage,
    translatedFieldCount: 0,
    unchangedFieldCount: fields.length,
    failedFieldCount: request.fields.length - fields.length,
    totalFieldCount: request.fields.length,
    isComplete: fields.length === request.fields.length,
    fields,
  };
}

function preserveValue(text) {
  return /^[A-D]$|^\d+(\s*\/\s*\d+)?$|^\d+%$/.test(String(text).trim());
}

function hasFakeTranslationPrefix(text) {
  return /^\s*(english|malay|bahasa melayu)\s*:/i.test(String(text));
}

Object.defineProperty(module.exports, '_test', {
  value: {
    validatePageTranslationRequest,
    hasProhibitedQuizTranslationField,
    fallbackPageTranslation,
    normalizePageTranslationJson,
    hasFakeTranslationPrefix,
  },
});
