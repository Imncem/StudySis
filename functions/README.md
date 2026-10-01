# StudySis Muffin Backend

Firebase Functions is the only place that talks to the AI provider. Flutter sends an authenticated StudySis request to these endpoints and never receives or stores the provider API key.

## Endpoints

- `askMuffin`: context-aware Learn, Flashcards, Practice, Quiz, and Muffin-turn translation.
- `translateMuffinPage`: structured whole-page dynamic content translation.

Both endpoints require a Firebase Auth ID token.

The provider adapter supports Gemini and OpenAI. Gemini is the preferred hackathon/demo provider. StudySis owns conversation state through current page context and `MuffinTurn`; provider-hosted conversation persistence is not used in this phase.

## Provider Configuration

### Gemini hackathon setup

Set the Gemini key as a Firebase Functions secret:

```powershell
firebase functions:secrets:set GEMINI_API_KEY
```

Use these backend params:

```text
AI_PROVIDER=gemini
GEMINI_MODEL=gemini-3.5-flash
```

The Gemini endpoint is constructed server-side as:

```text
https://generativelanguage.googleapis.com/v1beta/models/<GEMINI_MODEL>:generateContent
```

The API key is sent only from Firebase Functions in the `x-goog-api-key` header. It is never sent to Flutter and must not be committed to git.

You can obtain a Gemini API key from Google AI Studio. Keep in mind that free-tier usage has request and quota limits, so mock mode remains useful during development.

### Optional OpenAI setup

OpenAI adapter code remains available for later. The current hackathon functions are statically bound only to `GEMINI_API_KEY`, so a Gemini deployment does not require an OpenAI secret. To deploy OpenAI as the active provider later, reintroduce an OpenAI Firebase secret declaration and bind that secret to the target function options.

For v2 params, the Firebase CLI prompts for values on deploy when they are not already configured:

- `AI_PROVIDER`: `gemini` or `openai`.
- `GEMINI_MODEL`: Gemini model for hackathon/demo mode, recommended `gemini-3.5-flash`.
- `AI_PROVIDER_ENDPOINT`: optional OpenAI Responses API endpoint, default `https://api.openai.com/v1/responses`.
- `AI_PROVIDER_MODEL`: optional OpenAI model, default `gpt-5.6-luna`.

Do not commit real secrets.

## Deploy

```powershell
cd functions
npm install
npm run lint
npm test
cd ..
firebase deploy --only functions
```

For only the Muffin endpoints:

```powershell
firebase deploy --only functions:askMuffin,functions:translateMuffinPage
```

After deploy, get the function URLs from the Firebase CLI output or Firebase Console. They usually look like:

```text
https://<region>-<project>.cloudfunctions.net/askMuffin
https://<region>-<project>.cloudfunctions.net/translateMuffinPage
```

## Flutter Modes

Mock mode remains the default:

```powershell
cd app
flutter run --dart-define=MUFFIN_USE_MOCK=true
```

Real Muffin mode:

```powershell
cd app
flutter run `
  --dart-define=MUFFIN_USE_MOCK=false `
  --dart-define=MUFFIN_ENDPOINT=https://<region>-<project>.cloudfunctions.net/askMuffin `
  --dart-define=MUFFIN_TRANSLATION_ENDPOINT=https://<region>-<project>.cloudfunctions.net/translateMuffinPage
```

If `MUFFIN_TRANSLATION_ENDPOINT` is omitted, Flutter derives it by replacing `askMuffin` at the end of `MUFFIN_ENDPOINT` with `translateMuffinPage`.

## Verify No Key Is In Flutter

From the repo root:

```powershell
rg "GEMINI_API_KEY|sk-|AIza" app
```

Provider keys should only be configured as Functions secrets and should not appear in Flutter source or build definitions.

## Test askMuffin

Use a Firebase Auth ID token from a signed-in development session:

```powershell
$body = @{
  mode = "quiz"
  action = "guideQuestion"
  context = @{
    mode = "quiz"
    currentScreen = "quiz"
    subjectId = "math"
    chapterId = "chapter-1"
    questionId = "q2"
    contextKey = "quiz_math_chapter-1_question_q2"
    displayedLanguage = "ms"
    currentQuestion = "Apakah beza sepunya bagi jujukan berikut?`n7, 12, 17, 22, ..."
    answerOptions = @("3", "5", "7", "12")
  }
} | ConvertTo-Json -Depth 8

Invoke-RestMethod `
  -Method Post `
  -Uri "https://<region>-<project>.cloudfunctions.net/askMuffin" `
  -Headers @{ Authorization = "Bearer <firebase-id-token>" } `
  -ContentType "application/json" `
  -Body $body
```

Expected: a JSON `guidance` or `hint` response that references comparing neighbouring numbers without revealing the answer.

## Test translateMuffinPage

```powershell
$body = @{
  pageType = "quiz"
  pageId = "quiz_math_chapter-1_q2"
  sourceLanguage = "ms"
  targetLanguage = "en"
  fields = @(
    @{ id = "question_q2"; type = "question"; text = "Apakah beza sepunya bagi jujukan berikut?" },
    @{ id = "sequence_q2"; type = "question"; text = "7, 12, 17, 22, ..." }
  )
} | ConvertTo-Json -Depth 8

Invoke-RestMethod `
  -Method Post `
  -Uri "https://<region>-<project>.cloudfunctions.net/translateMuffinPage" `
  -Headers @{ Authorization = "Bearer <firebase-id-token>" } `
  -ContentType "application/json" `
  -Body $body
```

Expected: field IDs are unchanged; the question translates to English; the numeric sequence remains unchanged.

## Runtime Diagnostics

Development logs include request IDs, context keys/page IDs, mode/action, question/card IDs, selected model, provider duration, and validation result. Logs must not include API keys, Firebase tokens, or private credentials.
