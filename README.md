# StudySis — Sprint 2 Content Studio

StudySis is a personal KSSM Form 2 learning platform for Qidah.

- `app/` — Flutter student app with no login
- `dashboard/` — Next.js admin dashboard with Firebase Email/Password authentication
- `firestore.rules` — scoped student reads and authenticated content-management rules

The dashboard is the content-management source of truth. Chapters and modules should never need to be entered manually in Firebase Console.

## Firestore structure

```text
students/qidah
curriculum/form2/subjects/{subjectId}
curriculum/form2/subjects/math/chapters/{chapterId}
curriculum/form2/subjects/math/chapters/{chapterId}/modules/{moduleId}
```

`form2` is treated in code as the current curriculum catalog ID rather than being scattered as a hardcoded path. A future curriculum can use a sibling catalog such as `curriculum/kssm_2027_form2/subjects/...` with the same content shape and no database redesign.

Existing Sprint 1 subject documents remain compatible. Every subject needs a numeric `order` field. Mathematics must use document ID `math` to be editable in Sprint 2.

### Chapter fields

```text
chapterNumber, title, textbookChapterTitle, learningObjectives,
estimatedMinutes, status, order, createdAt, updatedAt
```

Chapter statuses are `draft`, `active`, and `archived`.

### Module fields

```text
title, type, content, summary, estimatedMinutes, difficulty,
order, status, createdAt, updatedAt
```

Module types are `notes`, `flashcards`, `practice`, `quiz`, `test`, and `review`. Difficulties are `easy`, `medium`, and `hard`. Module statuses are `draft`, `active`, and `archived`.

Only active chapters and active modules are available through Continue in the student app. Draft and archived content remain hidden.

## Firebase setup

The configured Firebase project is `studysis-d2151`.

1. Enable **Authentication → Sign-in method → Email/Password**.
2. Create the dashboard admin account under **Authentication → Users**.
3. Keep the existing `students/qidah` and Form 2 subject documents.
4. Log into Firebase CLI and deploy the Sprint 2 rules:

```powershell
firebase login
firebase deploy --only firestore:rules
```

The student app has no authentication, so public reads are limited to Qidah's profile, Form 2 subjects, chapters, and modules. Authenticated writes are limited to Qidah's editable profile fields and Mathematics content. No Storage or Cloud Functions are configured.

## Run the Flutter app

```powershell
cd app
flutter pub get
flutter run
```

The checked-in Flutter client configuration targets `studysis-d2151`. Run `flutterfire configure --project=studysis-d2151` only if Firebase app registrations change.

Checks:

```powershell
cd app
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

## Run the dashboard

`dashboard/.env.local` must contain the Web Firebase configuration. It is ignored by Git.

```powershell
cd dashboard
npm install
npm run dev
```

Open `http://localhost:3000`, sign in, then use:

```text
Content Studio → Mathematics → Add chapter → Add module
```

Set both the chapter and module status to `active` to publish the module to Qidah's Continue flow.

Dashboard checks:

```powershell
cd dashboard
npm run lint
npm run build
```

## Sprint 2 scope

- Permanent dashboard sidebar
- Functional Dashboard, Student, and Content Studio sections
- Mathematics chapter and module CRUD
- Server-generated Firestore timestamps
- Active-module Continue flow and Flutter module reader
- Placeholders only for Rewards, Muffin, Progress, and Settings
- No Mastery Engine, AI conversations, Coins, Abang Belanja, streaks, analytics, notifications, Storage, or Cloud Functions
