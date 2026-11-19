# Reliability and usability changes

Implemented locally on 26 October 2026. Nothing has been deployed.

## Implemented

- Transaction edits load by ID, distinguish missing records from new entries, support transfers, and retain receipts/tags. Creation uses a stable operation ID and rejects conflicting replayed IDs.
- Ledger balance changes use integer minor-unit arithmetic. Money-bearing models write minor-unit fields alongside existing decimal fields and read older documents. Invalid, non-finite, excessive and sub-cent amounts are rejected by the app.
- Account edits update metadata without overwriting a stale balance. Accounts are archived/restored rather than hard-deleted, preserving transaction history.
- Device-local, user-specific PIN/device authentication gates private content on open and after backgrounding. PIN retry throttling, confirmation, disable cleanup and sign-out recovery are included. Lock read errors fail closed. Re-enable locks in Settings on each device; legacy cloud lock flags were never enforcement controls and are no longer used for device security.
- AI repositories and visible chats are scoped to authentication sessions. Stale sessions cannot continue querying. The direct embedded Gemini key path is removed. Historical/account/category queries calculate totals in code and send bounded samples; reports accept those same scopes. Future-month activity no longer enters current-month totals.
- Bill payment records a linked expense and account debit atomically in Firebase. Payment IDs prevent repeated posting for the same due date. Monthly dates clamp correctly and retain the original billing day. Payment transactions remain visible in Activity.
- New-entry drafts persist locally under the signed-in user, retain their operation ID across restoration, and are cleared after saving. Posting requires a connection; an offline write queue has not been introduced.
- Activity includes account/category filters and category-name search. Totals match the selected results. Export explicitly offers current results or all activity and shows its scope/count. CSV text is protected against formula prefixes.
- Add opens expense entry directly. The last account is remembered, optional details are collapsed, transfers are explicit, and receipts/tags are editable.
- Mobile navigation uses Home, Activity, Accounts, Budgets and More. More includes Analytics, Chat and the other secondary features.
- Dashboard, Analytics and Calendar distinguish missing/error data from zero balances. Budget calculations propagate transaction errors/loading. Dashboard sync text reflects snapshot metadata and refresh awaits data.
- Budgets are explicitly recurring limits, with a selected-date preview of the current rules. This is not a historical archive of past budget definitions.
- Goals are explicitly progress tracking and do not imply movement of account funds.
- Shared static labels and common field labels have Hindi translations; date formatting follows the selected locale. Entry displays the selected ledger currency. Changing currency after money has been recorded is rejected rather than relabeling an existing transaction history.
- Defaults use deterministic IDs and transactional create-if-missing writes. Concurrent bootstrap calls are coalesced. Profiles use live document subscriptions.
- Shared mutation buttons prevent repeated taps and show failures. Destructive actions use confirmation, and closing an unsaved transaction requires an explicit choice.
- Firestore rules validate shapes/references and require associated atomic ledger changes. Standalone balance changes, unposted transactions and hard account deletion are rejected. The exact locally tested calculation refactor was applied after explicit user approval.
- Storage rules support owner-authorized deletion. Receipt files use unique names. Retryable Functions clean up deleted goals' deposits and removed/replaced/deleted transaction receipts.
- Android declares biometric permission; iOS includes photo-library and Face ID usage descriptions.
- CI runs Flutter analysis/tests/web compilation, Functions compilation, and Firestore emulator tests. Local Firebase hosting caches are ignored; the cache file that was already staged before this work was left untouched.

## Explicit feature limits and follow-up work

- **Repeat entries are manual templates.** No automatic recurrence processor is advertised or run. The form now states this explicitly.
- **Push reminders are not implemented.** The nonfunctional notification switch was replaced with a clear status. Upcoming bills remain available on Home. Delivery infrastructure and platform notification registration are a separate feature.
- **Large-history scaling remains:** the shared transaction stream still reads full history to preserve complete totals and exports. Cursor pagination, server period aggregates and a timestamp backfill require a coordinated data-access change; records have not been silently truncated.
- Existing financial records are read compatibly and upgraded on write; no bulk historical data migration or balance reconciliation was run. Monetary values with more than two decimal places require explicit correction rather than silent rounding.
- Localization now covers common static labels and fields; some dynamic messages and descriptive text remain English. Favourites, merchant suggestions, “save and add another,” and persistent state across every tab remain product enhancements.
- iOS Firebase API keys are still placeholders in `lib/firebase_options.dart`. Register/configure the real iOS app and OAuth URL scheme with FlutterFire, and verify permissions/sign-in/device authentication on physical devices. No credentials or platform IDs were invented.
- Real Firebase/App Check settings, AI model availability, billing/quotas, native release signing and device behavior require deployment/device validation. The AI model identifier was not changed without verifying project availability.

## Release requirements

1. Review and deploy the updated Firestore and Storage rules plus the cleanup Functions. The active project rules were tested only against the local demo emulator.
2. Coordinate the rules and client rollout: older client versions do not supply ledger operation markers and their money writes will be rejected by the new rules. For web, release the matching app and rules together; plan a minimum-version transition for installed mobile clients.
3. Run the native device checks above before publishing Android/iOS builds.

Local validation:

- Flutter analysis: no issues found.
- Flutter tests: 36 passing tests; the former placeholder smoke test was replaced with a passing phone workflow that opens Home, adds an expense, returns, and verifies the balance.
- Firestore emulator: all 6 tests passed against the exact rules applied locally.
- Cloud Functions TypeScript compilation: passed.
- Final web release compilation: passed, including the Wasm compatibility dry run.
- Desktop-width and 360-pixel-wide transfer-edit widget checks: passed.

Tests cover replay safety, failed-post atomicity in demo mode, stale balance edits, archival/reversal, nullable metadata, money validation, monthly dates, bill payment replay, scoped activity totals, locking, cold transfer editing and narrow layouts. Emulator tests exercise ownership, malformed writes, atomic expense posting/editing/reversal, partial transfers and four-account transfer edits. Physical-device and deployed-service checks have not been run.
