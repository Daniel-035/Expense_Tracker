# LedgerOne

Personal expense tracker for Android, iOS, and Web — Flutter + Firebase (Clean Architecture + Riverpod).

## Features (V1)

- Email/password & Google auth (Firebase) with demo-mode fallback
- Dashboard, income/expense transactions, accounts (with transfers), categories
- Budgets, bills & subscriptions, savings goals
- Analytics charts, calendar, profile & settings
- CSV export, dark/light theme, offline-capable sync (Firestore)
- Responsive web sidebar + mobile bottom navigation

## Quick start (demo mode)

Without Firebase credentials the app runs in **demo mode** (local SharedPreferences).

```bash
flutter pub get
flutter run -d chrome
# or
flutter run
```

1. Open the app → **Create an account**
2. Add income/expense via the FAB
3. Explore Budgets, Goals, Bills, Analytics

## Firebase setup (production)

1. Create a Firebase project named `ledgerone`
2. Enable **Authentication** (Email/Password + Google)
3. Create **Firestore** and **Storage**
4. Install FlutterFire CLI and configure:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

5. Deploy rules:

```bash
firebase deploy --only firestore:rules,storage:rules
```

6. Deploy web:

```bash
flutter build web
firebase deploy --only hosting
```

Security rules live in [`firebase/firestore.rules`](firebase/firestore.rules) and [`firebase/storage.rules`](firebase/storage.rules).

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
