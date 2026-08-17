# StudySis

StudySis is a personal KSSM Form 2 learning platform for Qidah. It has three main parts:

- `app/` - Flutter student app.
- `dashboard/` - Next.js admin dashboard for curriculum/content management.
- `functions/` - Firebase Functions backend for Muffin AI, page translation, safety, budgets, and provider calls.

The configured Firebase project is `studysis-d2151`.

## Current Status

The current branch includes work through Sprint 3.6A.2:

- Content Studio for Mathematics chapters and learning modules.
- Student learning flow for Learn, Flashcards, Practice, Quiz, Progress, saved flashcards, and Muffin.
- Persistent anonymous-student progress in Firestore.
- Context-aware Muffin assistant with real Gemini provider support.
- Whole-page translation for dynamic learning screens.
- Muffin Bites wallet, cooldown, daily provider budget, and real-time regeneration.
- Wrong-question-safe Muffin response caching.
- Study Points, permanent XP, levels, daily streaks, and upgraded streak celebration UX.

Mock Muffin remains available for local Flutter development. Real Muffin uses Firebase Functions so provider API keys never enter Flutter source or client builds.

## Repository Layout

```text
app/
  lib/
    models/
    screens/
    services/
    widgets/
  test/

dashboard/
  app/
  components/
  lib/

functions/
  index.js
  muffinPolicy.js
  test/

firestore.rules
firebase.json
```

## Firestore Structure

Curriculum content:

```text
students/qidah
curriculum/form2/subjects/{subjectId}
curriculum/form2/subjects/{subjectId}/chapters/{chapterId}
curriculum/form2/subjects/{subjectId}/chapters/{chapterId}/modules/{moduleId}
curriculum/form2/subjects/{subjectId}/chapters/{chapterId}/modules/notes/sections/{sectionId}
curriculum/form2/subjects/{subjectId}/chapters/{chapterId}/modules/flashcards/cards/{cardId}
curriculum/form2/subjects/{subjectId}/chapters/{chapterId}/modules/practice/items/{itemId}
curriculum/form2/subjects/{subjectId}/chapters/{chapterId}/modules/quiz/questions/{questionId}
```

Student progress:

```text
student_progress/{uid}/chapters/{subjectId}_{chapterId}
student_progress/{uid}/engagement/state
student_progress/{uid}/engagement_days/{YYYY-MM-DD}
```

Muffin wallet:

```text
students/qidah/muffin/state
students/qidah/muffin/providerUsage/{providerDayKey}
```

Saved flashcards:

```text
student_private/{uid}/saved_flashcards/{subjectId}_{chapterId}_{cardId}
```

`form2` is treated as the current curriculum catalog ID. A future curriculum can use a sibling catalog such as `curriculum/kssm_2027_form2/subjects/...` with the same shape.

## Firebase Auth

The student app uses Firebase Anonymous Authentication. Startup must first reuse `FirebaseAuth.instance.currentUser`, then wait briefly for restored auth state, and only call `signInAnonymously()` if no existing user is available.

This preserves the anonymous UID across app restarts, which keeps progress and saved flashcards attached to the same user.

The dashboard uses Firebase Email/Password authentication for admin access.

## Student Progress

Progress is stored in Firestore under:

```text
student_progress/{uid}/chapters/{subjectId}_{chapterId}
```

The first write for a chapter creates a complete rules-compatible `ChapterProgress` document, including defaults for Learn, Flashcards, Practice, Quiz, timestamps, and overall progress. Later module writes update only the requested module state while preserving existing fields such as `createdAt`.

Learn completion persists before navigation to Flashcards. After a successful Learn write:

- Learn is completed.
- Flashcards unlock.
- Overall chapter progress is at least 25%.

Failed writes show a user-facing error and must not silently unlock later stages.

## Study Points, XP, Levels, And Streaks

Sprint 3.6A added a separate engagement system that does not replace chapter progress.

Firestore paths:

```text
student_progress/{uid}/engagement/state
student_progress/{uid}/engagement_days/{YYYY-MM-DD}
```

The daily date key uses Malaysia calendar days in `YYYY-MM-DD` format. Study Points reset per Malaysia day; XP, level, current streak, longest streak, and last qualified date persist.

Daily streak target:

```text
3 Study Points per Malaysia day
```

Engagement rewards:

```text
Learn completion:              +2 Study Points, +20 XP
Review 5 normal Flashcards:    +1 Study Point,  +10 XP
Complete 5 Practice questions: +2 Study Points, +20 XP
Complete Quiz:                 +3 Study Points, +40 XP
Review 3 Saved Flashcards:     +1 Study Point,  +10 XP
Muffin/translation/navigation:  +0 Study Points, +0 XP
```

XP levels:

```text
Level 1: 0-99 XP
Level 2: 100-249 XP
Level 3: 250-449 XP
Level 4: 450-699 XP
Level 5: 700-999 XP
Level 6+: extends in 400 XP bands
```

Streak qualification is transaction-based. The first time a day crosses the 3-point target:

- If the last qualified date was yesterday, `currentStreak` increments.
- If the last qualified date is older or missing, `currentStreak` restarts at 1.
- Same-day extra activity does not increment again.
- `todayStreakSecured=true` must never persist with `currentStreak=0`.

Sprint 3.6A.2 added defensive normalization and Firestore rules invariants for legacy or manually edited impossible states:

```text
longestStreak >= currentStreak
todayStreakSecured=false OR currentStreak >= 1
```

The streak celebration screen receives the newly persisted transaction result and can show the already-awarded XP reward. It does not award XP or streaks from the Continue button.

## Muffin AI

Muffin AI is implemented in Firebase Functions. The Flutter app sends authenticated StudySis requests to Functions; Functions call the active AI provider.

Key files:

- `functions/index.js` - `askMuffin`, `translateMuffinPage`, provider adapters, parser, wallet, budget logic.
- `functions/muffinPolicy.js` - safety policy helpers.
- `functions/README.md` - provider configuration and deploy details.
- `app/lib/services/muffin_service.dart` - Flutter Muffin client and mock service.
- `app/lib/widgets/floating_muffin_shell.dart` - global floating Muffin entry point.
- `app/lib/widgets/muffin_assist_sheet.dart` - Muffin action sheet and response UI.
- `app/lib/services/muffin_context_registry.dart` - current screen context registration.
- `app/lib/services/page_translation_service.dart` - whole-page translation client.

### Provider Configuration

Current hackathon/demo provider:

```text
AI_PROVIDER=gemini
GEMINI_MODEL=gemini-3.5-flash
secret=GEMINI_API_KEY
```

Gemini requests use Google `generateContent` REST format:

```text
https://generativelanguage.googleapis.com/v1beta/models/<GEMINI_MODEL>:generateContent
```

The Gemini API key is stored only as a Firebase Functions secret and sent server-side in the `x-goog-api-key` header.

Optional OpenAI adapter code remains available, but the current Gemini deployment does not require `AI_PROVIDER_API_KEY`.

### Muffin Safety

StudySis preserves safety boundaries for student assistance:

- Quiz context rejects correct-answer data and answer explanations.
- Quiz guidance must help thinking without revealing direct answers.
- Flashcard context excludes hidden answer data until the student reveals it.
- Stale context protection discards responses for no-longer-visible questions/cards.
- Generated practice questions are schema-validated before display.
- Provider errors are converted to friendly Muffin errors.

### Page Translation

Whole-page translation uses structured page content with stable field IDs. It preserves math/numeric fields when translation is unnecessary or unsafe.

Translation is supported across:

- Home
- Learn
- Flashcards
- Practice
- Quiz
- Saved Flashcards

Muffin response translation is free for student Muffin Bites, while provider attempts are still counted for backend provider budget protection.

## Muffin Bites

Muffin Bites are the student-facing usage wallet:

- Default maximum: `5`.
- Regeneration interval: 60 minutes per Bite.
- Paid Muffin actions consume Bites.
- Response/page translation is free for student Bites.
- Provider attempts are still tracked server-side.
- Daily provider budget uses the provider day, based on America/Los_Angeles, not UTC.

Sprint 3.5E added real-time effective Bite regeneration. Flutter derives the displayed effective balance from:

```text
currentBites
lastRegenAt
regenIntervalMinutes
maxBites
```

Examples:

```text
0 Bites + 59 minutes = 0
0 Bites + 60 minutes = 1
0 Bites + 3 hours = 3
2 Bites + 2 hours = 4
4 Bites + 3 hours = 5
0 Bites + 10 hours = 5
```

Partial elapsed time is preserved. Once the wallet reaches full, excess elapsed time is not banked, so spending after a long full period does not instantly regenerate another Bite.

The client only derives display state. Server-side Functions remain authoritative for spending, provider limits, and stored wallet updates.

## Run The Flutter App

Install dependencies:

```powershell
cd app
flutter pub get
```

Run with mock Muffin:

```powershell
flutter run --dart-define=MUFFIN_USE_MOCK=true
```

Run with real Muffin:

```powershell
flutter run `
  --dart-define=MUFFIN_USE_MOCK=false `
  --dart-define=MUFFIN_ENDPOINT=https://<region>-<project>.cloudfunctions.net/askMuffin `
  --dart-define=MUFFIN_TRANSLATION_ENDPOINT=https://<region>-<project>.cloudfunctions.net/translateMuffinPage
```

If `MUFFIN_TRANSLATION_ENDPOINT` is omitted, Flutter derives it by replacing `askMuffin` at the end of `MUFFIN_ENDPOINT` with `translateMuffinPage`.

Flutter checks:

```powershell
cd app
dart format lib test
flutter analyze
flutter test
```

## Run The Dashboard

`dashboard/.env.local` must contain the Web Firebase configuration. It is ignored by Git.

```powershell
cd dashboard
npm install
npm run dev
```

Open:

```text
http://localhost:3000
```

Dashboard checks:

```powershell
cd dashboard
npm run lint
npm run build
```

## Run Firebase Functions

Install dependencies:

```powershell
cd functions
npm install
```

Configure Gemini:

```powershell
firebase functions:secrets:set GEMINI_API_KEY
```

For Firebase v2 params, deploy may prompt for:

```text
AI_PROVIDER=gemini
GEMINI_MODEL=gemini-3.5-flash
```

Functions checks:

```powershell
cd functions
npm run lint
npm test
```

Deploy only the Muffin Functions:

```powershell
firebase deploy --only functions:askMuffin,functions:translateMuffinPage
```

Deploy Firestore rules:

```powershell
firebase deploy --only firestore:rules
```

Do not commit API keys, Firebase tokens, or local `.env` files.

## Validation Commands

Common full validation:

```powershell
cd app
dart format lib test
flutter analyze
flutter test

cd ..\functions
npm run lint
npm test
```

Android debug build:

```powershell
cd app
flutter clean
flutter pub get
flutter build apk --debug
```

Firebase SDK XML processing warnings are separate from real Android build failures. The app minimum Android SDK is 23 because Firebase Auth requires it.

## Sprint History

### Sprint 1 - Foundation

- Created the StudySis Firebase-backed project foundation.
- Added Flutter student app shell.
- Added initial Firebase project configuration.
- Added Qidah student profile and basic subject structure.

### Sprint 2 - Content Studio And Learning Flow

- Added dashboard Content Studio.
- Added Mathematics chapter and module CRUD.
- Added structured module types: Notes, Flashcards, Practice, Quiz, Test, Review.
- Added active/draft/archive status handling.
- Added ordered Notes sections.
- Added Flashcard, Practice, and Quiz editors.
- Added student Learn reader and Flashcard flow.
- Added chapter learning journey and overview.
- Added Student Preview newline preservation for question text.
- Added Muffin guidance skeleton UI.
- Added persistent student progress tracking under `student_progress/{uid}`.
- Fixed rules-compatible first progress writes by creating full `ChapterProgress` documents.
- Fixed anonymous auth reuse so progress survives app restarts.

### Sprint 3.1 - Progress Dashboard

- Added student-facing Progress dashboard.
- Made Firestore `ChapterProgress` the source of truth.
- Added chapter/module completion states and overall progress display.

### Sprint 3.2 - Context-Aware Muffin Assistance

- Added Muffin context registry.
- Added screen-aware Muffin actions.
- Added mock Muffin responses for Learn, Flashcards, Practice, and Quiz.
- Preserved quiz and flashcard answer safety.

### Sprint 3.3A-3.3F - Global Muffin And Page Translation

- Replaced inline-only Muffin access with a global floating Muffin button.
- Fixed floating button tap/drag separation and Navigator context handling.
- Added default Muffin fallback menu when no page context is registered.
- Added duplicate sheet prevention.
- Added whole-page translation support.
- Added translation banner and translation state reset behavior.
- Improved translation quality and stable field handling.
- Added per-card/per-question Muffin context updates.
- Reset stale Muffin response state before real AI integration.

### Sprint 3.4-3.4E - Real Muffin AI Integration

- Added Firebase Functions Muffin backend.
- Added provider adapter architecture.
- Migrated OpenAI adapter to Responses API format.
- Added Gemini provider as the active hackathon provider.
- Removed deployment-time dependency on OpenAI secrets for Gemini-only deploys.
- Fixed Gemini parser for thought parts, fenced JSON, malformed JSON, empty candidates, and truncation.
- Added single MAX_TOKENS retry with larger token ceilings.
- Fixed Gemini `thinkingConfig.thinkingLevel` REST request shape.
- Added safe provider error diagnostics.

### Sprint 3.5-3.5E - Muffin Bites, Budget, Saved Cards, And Regeneration

- Added Muffin Bites wallet, cooldown, and daily provider budget.
- Corrected provider attempt accounting.
- Added Dashboard Muffin Bites display.
- Added saved flashcards dashboard section and TikTok-style saved card deck.
- Made Muffin response translation free for student Bites.
- Fixed page translation returning zero fields.
- Added defensive translation normalization for `fields` and `translations`.
- Added real-time effective Muffin Bite regeneration after app close, app resume, and while Home is open.
- Added cap/no-bank behavior for full wallets.
- Added backend and Flutter tests for regeneration thresholds and provider-day budget behavior.

### Sprint 3.5F - Muffin Cache Identity And Assist Sheet Polish

- Versioned provider cache identity to include mode, action, uid, page/question/card context, language, and content hash.
- Rejected legacy or mismatched cache metadata to prevent wrong-question Muffin response reuse.
- Preserved quiz answer safety, flashcard hidden-answer safety, stale context protection, page translation, and provider budget behavior.
- Reset visible Muffin turn state when quiz/card context changes while the assist sheet remains open.
- Updated the Muffin assist sheet header to use the shared Muffin mascot icon.

### Sprint 3.6A-3.6A.2 - Study Points, XP, Daily Streaks, And Celebration

- Added Study Points as a daily meaningful-learning target, separate from permanent XP.
- Added XP levels and a compact Home dashboard engagement card.
- Added Malaysia-day daily reset behavior for Study Points.
- Added streak qualification after reaching 3 Study Points in a Malaysia calendar day.
- Added anti-farming milestone keys for Learn, Flashcards, Practice, Quiz, and Saved Flashcards.
- Added streak celebration screen with staged animation, one-shot confetti, Muffin mascot animation, milestone copy, optional XP reward display, haptics, and reduced-motion support.
- Fixed persisted `currentStreak=0` after qualification by enforcing transaction/model/rules invariants.
- Added regression tests for first streak, missed-day restart, consecutive-day increment, same-day no double increment, secured-zero normalization, celebration copy, reward display, and disposal.

## Current Test Baseline

Latest validation on Sprint 3.6A.2:

```text
dart format lib test - passed
flutter analyze - passed, no issues
flutter test - passed, 172 tests
npm run lint - passed
npm test - passed, 83 tests
```
