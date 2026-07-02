# StudySis — Sprint 1

StudySis is a personal Form 2 learning app for Qidah. This repository contains:

- `app/` — Flutter student app (no authentication)
- `dashboard/` — Next.js admin dashboard (Firebase Email/Password authentication)
- `firestore.rules` — Sprint 1 Firestore access rules

The app and dashboard both use real-time Firestore listeners. Saving Qidah's profile in the dashboard is reflected in the open Flutter app automatically.

## Required Firestore data

The implementation expects this existing structure:

```text
students/qidah
curriculum/form2/subjects/{subjectId}
```

Suggested `students/qidah` fields:

```json
{
  "name": "Qidah",
  "preferredLanguage": "Bahasa Melayu",
  "dailyTargetMinutes": 20,
  "status": "active"
}
```

Each subject document should contain:

```json
{
  "displayName": "Mathematics",
  "shortName": "Maths",
  "contentStatus": "available",
  "iconName": "math",
  "themeColor": "#527A71",
  "order": 1
}
```

Use `contentStatus: "coming_soon"` to display the Coming soon label. All 10 subject documents need a numeric `order` field because both clients query with `orderBy("order")`; documents without this field are omitted by Firestore.

## 1. Firebase project setup

1. Open the Firebase console and select the project that already contains the StudySis data.
2. Under **Build → Authentication → Sign-in method**, enable **Email/Password**.
3. Under **Authentication → Users**, create the admin email/password user. Do not create a student account.
4. Register an Android app with package ID `com.studysis.studysis`, an iOS app with bundle ID `com.studysis.studysis` if needed, and a Web app for the dashboard.
5. Install the Firebase CLI if needed: `npm install -g firebase-tools`, then run `firebase login`.
6. Copy `.firebaserc.example` to `.firebaserc` and replace the project ID.
7. Deploy only the Firestore rules:

```powershell
firebase deploy --only firestore:rules
```

The rules allow public reads only for Qidah's profile and Form 2 subjects because the student app intentionally has no authentication. Only authenticated dashboard users can update the three supported profile fields. Everything else is denied. For production with multiple authenticated users, add an admin custom-claim check.

No Firebase Storage bucket or Cloud Functions are required or configured.

## 2. Flutter app setup and run

Install the FlutterFire CLI once:

```powershell
dart pub global activate flutterfire_cli
```

Configure the app from its folder. Select the same Firebase project and the Android/iOS/Web targets you intend to run:

```powershell
cd app
flutter pub get
flutterfire configure
flutter run
```

`flutterfire configure` replaces the checked-in placeholder `lib/firebase_options.dart` and adds the platform Firebase configuration files where required. Do not commit real configuration if your team's credential policy excludes it.

Useful checks:

```powershell
cd app
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

The app opens directly to Home. There is no student login or registration flow.

## 3. Dashboard setup and run

In Firebase console, open **Project settings → Your apps → Web app → SDK setup and configuration**. Copy `dashboard/.env.local.example` to `dashboard/.env.local`, then fill in the matching Web app values:

```powershell
Copy-Item dashboard/.env.local.example dashboard/.env.local
```

Install and run:

```powershell
cd dashboard
npm install
npm run dev
```

Open `http://localhost:3000` and sign in with the admin account created in Firebase Authentication.

Dashboard checks:

```powershell
cd dashboard
npm run lint
npm run build
```

## Current Sprint 1 scope

- Flutter Home with Qidah's target, language, one Continue action, Muffin placeholder, and ordered subject cards
- Admin login and Qidah profile editing
- Real-time subject/profile reads
- No lesson, quiz, reward, Mastery Engine, Coins, Abang Belanja, Storage, or Cloud Functions implementation yet
