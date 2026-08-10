# StudySis Muffin Backend

This Firebase Functions skeleton provides the secure backend boundary for Muffin Phase 1.

Endpoint:

- `askMuffin`
- Accepts authenticated `POST` requests from the Flutter app.
- Verifies Firebase Auth ID tokens.
- Validates Muffin `mode`, `action`, and safe context.
- Applies server-side safety policy before provider integration.

Secrets:

```powershell
firebase functions:secrets:set AI_PROVIDER_API_KEY
```

Provider runtime configuration:

- `AI_PROVIDER_ENDPOINT`, for an OpenAI-compatible chat completions endpoint
- `AI_PROVIDER_MODEL`, defaults to `gpt-4o-mini`

Firebase Functions params can be supplied during deploy when prompted, or via your CI/deployment environment.

Flutter configuration:

```powershell
flutter run --dart-define=MUFFIN_USE_MOCK=false --dart-define=MUFFIN_ENDPOINT=https://<region>-<project>.cloudfunctions.net/askMuffin
```

Development mock mode:

```powershell
flutter run --dart-define=MUFFIN_USE_MOCK=true
```

Data sent to the backend:

- Current mode and requested action.
- Subject/chapter identifiers and titles.
- Current lesson heading/body, current question, answer options, or selected student answer when relevant.
- Light progress context such as best practice score, best quiz score, quiz pass status, and mastered flashcard count.

Data intentionally excluded:

- Provider API keys.
- Firebase tokens in the AI prompt.
- Anonymous UID in the AI prompt.
- Correct quiz answer, correct option index, and answer explanations.
- Administrator data, unrelated progress records, or other students' data.

Provider-specific AI code should be added inside `callConfiguredProvider()` in `index.js`.
