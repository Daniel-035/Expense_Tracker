# LedgerOne

Personal expense tracker for Android, iOS, and Web — Flutter + Firebase (Clean Architecture + Riverpod).

## Features (V1)

- Email/password & Google auth (Firebase)
- Dashboard, income/expense transactions, accounts (with transfers), categories
- Budgets (multi-category), bills & subscriptions, savings goals
- Analytics charts, calendar, profile & settings
- CSV/PDF export, dark/light theme, Firestore sync
- Responsive web sidebar + mobile bottom navigation
- Crashlytics in release builds; Cloud Function account deletion

## Quick start (debug / demo)

**Demo mode only runs in debug/profile** when Firebase is unavailable or keys are placeholders. **Release builds never fall back to local demo data.**

```bash
flutter pub get
flutter run -d chrome
# or
flutter run
```

1. Open the app → **Create an account**
2. Add income/expense via the FAB
3. Explore Budgets, Goals, Bills, Analytics

## Platform IDs

| Platform | ID |
|----------|----|
| Android `applicationId` | `com.ledgerone.appshot.com` |
| Firebase Android package | `com.ledgerone.appshot.com` |
| Google Sign-In web client | see `lib/core/constants/platform_ids.dart` |
| iOS bundle (placeholder) | `com.ledgerone.ledgerone` |

Add your debug **and** upload-keystore **SHA-1** fingerprints in Firebase Console → Project settings → Android app (`com.ledgerone.appshot.com`).

## Android release signing

Release builds require a real upload keystore (debug signing is not used).

```bash
cd android
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
copy key.properties.example key.properties
# edit key.properties with passwords / paths
```

`android/key.properties` and `*.jks` are gitignored.

```bash
flutter build apk --release
# or
flutter build appbundle --release
```

## Firebase setup (production)

1. Firebase project: `expense-tracker-70365`
2. Enable **Authentication** (Email/Password + Google)
3. Create **Firestore**, **Storage**, and enable **Cloud Functions**
4. Place `android/app/google-services.json` (gitignored) from Firebase Console
5. Install FlutterFire CLI if regenerating options:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

6. Deploy rules + account-deletion function:

```bash
cd functions && npm ci && npm run build && cd ..
firebase deploy --only firestore:rules,storage:rules,functions:deleteUserAccount
```

7. Deploy web:

```bash
flutter build web --release
firebase deploy --only hosting
```

Security rules live in [`firebase/firestore.rules`](firebase/firestore.rules) and [`firebase/storage.rules`](firebase/storage.rules). Account deletion uses `functions/src/index.ts` (`deleteUserAccount` in `asia-south1`).

## Project structure

```
lib/
  core/           # theme, routing, providers, constants
  features/       # auth, dashboard, transactions, accounts, …
  shared/         # widgets, formatters
firebase/         # security rules
```

## Tests

```bash
flutter test
```

## Language

Settings → **Language** → English / हिन्दी. The shell, settings, budgets, profile, AI, and shared labels switch immediately.

## Rate limiting

Client-side sliding windows protect:
- Auth (login / register / Google / password reset)
- Transaction writes
- Storage uploads
- AI prompts

## Firebase AI (free Gemini tier)

1. Firebase Console → **Build → AI Logic**
2. Enable **Gemini Developer API** (no-cost tier)
3. Optional: enable **App Check** for production

In-app: open **AI Assistant** — answers use your live transactions/budgets snapshot.

## Storage (web)

Rules are deployed for `users/{uid}/profile` and `users/{uid}/receipts`.

For browser uploads, set bucket CORS (once) using [Google Cloud Console](https://console.cloud.google.com/storage/browser/expense-tracker-70365.firebasestorage.app) → bucket → **Configuration → CORS**, paste contents of [`firebase/storage-cors.json`](firebase/storage-cors.json).

Or with Cloud SDK:
```bash
gsutil cors set firebase/storage-cors.json gs://expense-tracker-70365.firebasestorage.app
```

Profile → camera icon uploads to Storage.
