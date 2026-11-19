# LedgerOne project review

Reviewed: 26 October 2026.

This is the initial review. See [IMPLEMENTATION_NOTES.md](IMPLEMENTATION_NOTES.md) for the fixes applied afterward, current limits, and release requirements.

Scope: source review of startup, routing, repositories, models, main screens, authentication, AI, exports, Firebase rules/functions, platform configuration, and existing tests. This is not a live-device usability test or an audit of deployed Firebase configuration. Findings describe the checked-in implementation; production enforcement and credentials were not inspected.

## Recommended direction

Focus the next release on reliable daily expense entry. The app already has a broad feature set. Balance accuracy, honest loading/sync states, working security controls, and dependable bills are more valuable now than adding more screens.

## Fix first: correctness and privacy

1. **Preserve transfers during editing.** `lib/features/transactions/presentation/screens/transaction_form_screen.dart:79` converts a loaded transfer into an expense. Saving constructs a new transaction without a destination. Opening a transfer and saving can therefore reverse its destination credit and replace the transfer with an expense. Add a dedicated transfer editor, or make transfers read-only until supported. Test changing amount and either account.

2. **Load an edited transaction by ID.** `_loadExisting()` reads `transactionsProvider` only once after bootstrap. A cold deep link can reach this point before the stream loads; `_existing` stays null and Save creates a new transaction. Fetch/watch the requested document, show loading/not-found/error states, and never allow create mode for an edit route. Preserve existing receipt URL and tags when editing; the current constructor drops both.

3. **Implement the PIN/biometric lock.** `lib/features/settings/presentation/screens/settings_screen.dart:64` authenticates only when turning biometrics on; the PIN is written to secure storage but is never read elsewhere. No startup/resume gate enforces either setting. Add a lock screen, background timeout, retry handling, recovery, and device/user-scoped configuration. Delete local PIN material when disabling it. Until complete, hide these controls so they do not imply protection.

4. **Scope AI sessions to the signed-in user.** `lib/features/ai/data/ai_repository.dart:429` creates a persistent repository without watching the UID. Logout does not reset its model chat sessions or last report. A subsequent user in the same app process could receive responses influenced by the previous user's finance context. Reset/dispose on UID changes and discard in-flight responses from a previous session. Test account switching.

5. **Make transaction creation idempotent.** `lib/features/transactions/data/transactions_repository.dart:65` applies balance deltas and sets a caller-provided transaction ID without checking whether that ID already exists. Retrying the same creation after a successful but uncertain response can apply the balance change again while overwriting the same record. Read the transaction first and reject or return an existing matching operation. This concerns separate create invocations, not Firestore's internal transaction retries.

6. **Protect account history and balance edits.** `lib/features/accounts/data/accounts_repository.dart:72` deletes an account while transactions still reference it. Later edits/deletes of those transactions fail when their account is missing. Archive used accounts, or explicitly migrate references. Account editing also writes a stale full balance from the form; even renaming can overwrite balance changes from another device. Separate metadata updates from opening balances and record reconciliation adjustments as ledger entries.

7. **Validate money consistently.** Amounts and balances use `double`; migrate financial values to integer minor units with an explicit rounding/migration policy. Bills, goals, budgets, and account repositories lack the finite/positive validation used for transactions. Several forms only check `amount <= 0`, which does not reject NaN. Validate finite values, allowed ranges, names, and references at repository and server-rule boundaries. Keep valid negative account balances possible where appropriate.

8. **Strengthen Firestore write validation.** `firebase/firestore.rules` isolates each user's documents, which is a useful baseline, but permits any document shape and arbitrary balance writes by that owner. Add field/type/size/enum validation and reference checks. For strict ledger consistency, use a trusted posting endpoint or rules validating related atomic writes. Client rate limits are usability controls and can be bypassed; do not treat them as server quotas.

9. **Remove the direct unrestricted Gemini key path from production.** `lib/features/ai/data/ai_repository.dart:60` accepts a build-time key embedded in the client. This is conditional; the review did not establish that a deployed build contains one. Keep Firebase AI with appropriate enforcement/quotas or move privileged calls to a server. Google advises against exposing Gemini keys in production web/mobile clients: https://ai.google.dev/gemini-api/docs/api-key

## Finish existing features

10. **Make recurrence executable.** Transactions save `recurrence` and `nextOccurrence`, but no occurrence processor was found in `lib` or `functions/src`. Implement an idempotent scheduler with pause/end/edit controls, or clearly label entries as reminders/templates. Handle short months and leap years; `DateTime(year, month + 1, day)` can overflow into a later month instead of using the last valid day.

11. **Turn bill payment into a complete flow.** `lib/features/bills/data/bills_repository.dart:61` only changes the paid state or advances the due date. It does not record an expense, debit an account, or preserve a payment history. Offer account/category selection and atomically create one linked payment transaction. Prevent double taps and record the original due date/payment ID. Clamp monthly due dates and preserve the intended billing day.

12. **Implement reminders behind Notifications.** The setting is persisted, but no messaging registration, permission flow, scheduling, or delivery implementation was found. Add due/overdue reminders, budget thresholds, a permission status, and a delivery strategy for each supported platform.

13. **Clarify savings deposits.** Goal deposits increase `savedAmount` without linking an account or ledger movement. Either call this a progress tracker or support real allocations/transfers and withdrawal history. Deleting a goal currently leaves its deposits subcollection behind; use server cleanup. Firestore does not recursively delete subcollections with their parent: https://firebase.google.com/docs/firestore/data-model

14. **Make budgets explicit about time.** `Budget.withLiveSpent()` uses the current week/month and ignores the stored `monthKey`. Decide whether a budget is a recurring rule or a historical period snapshot. Support clear period selection, renewal rules, and past-period review. Do not show zero spent while transactions load or silently substitute stored data after a fetch error.

## Make everyday use easier

15. **Reduce entry effort.** Make Add expense open directly with amount focused. Remember the last account, offer recent/favourite categories and merchant suggestions, and collapse location/notes/recurrence under More details. Provide Save and add another. Do not silently select an arbitrary first category when an existing category is missing. Keep income and transfer available as explicit alternatives.

16. **Simplify mobile navigation.** The current six destinations include Chat and Profile, while Accounts/Bills/Goals are reached through Profile. Consider Home, Activity, Accounts, Budgets, More, with Chat as a dashboard shortcut. Keep all secondary features in More and retain form/filter/scroll state across tabs where useful. Validate this layout on narrow phones and with large text before committing to it.

17. **Use honest data states.** Dashboard, analytics, calendar, and other screens turn loading/errors into empty lists or zero values with `asData?.value ?? []`. Show a skeleton on initial load, preserve last good values during refresh, and offer a clear retry state. The dashboard always says 'Synced across your devices'; replace that with actual pending/offline/sync status. Refresh should await the data rather than an arbitrary delay.

18. **Handle offline writes deliberately.** Firestore caching is enabled, but money changes use client transactions, which fail offline. Either clearly require a connection for posting and preserve drafts, or build a durable user-scoped outbox with operation IDs and safe server reconciliation. Do not switch real users into demo mode to handle ordinary connectivity loss. Reference: https://firebase.google.com/docs/firestore/manage-data/transactions

19. **Make filters and export agree.** Activity filters its visible list, while `showExportShareSheet()` exports the entire transactions provider. Offer 'Current results' and 'All activity', display the selected date range and count, and use the same filter for totals and export. Add account/category filters and let category names participate in search. Label period totals clearly if they intentionally ignore search/type filters.

20. **Prevent accidental or repeated actions.** Add loading/disabled states and useful error handling to account, transfer, bill, goal, profile, and settings mutations. Several callbacks currently await writes without catching failures or preventing repeated taps. Confirm transaction deletion or support Undo. Warn before dismissing a dirty transaction form via the backdrop/back button.

21. **Complete localization and currency semantics.** Dashboard, activity, accounts, analytics, and calendar contain many hardcoded English labels; route them through localization and use locale-aware dates. Transaction entry always displays a rupee icon despite a configurable currency. Changing currency currently relabels the same numbers; define it as a single ledger currency or implement account currencies and explicit conversion. Do not imply that changing the symbol converts historical values.

22. **Connect receipts and tags.** Storage upload and model fields exist, but the transaction form does not expose receipt attachment or tags and currently loses these fields on edits. Add attachment preview/remove controls, cancellation handling, and cleanup. Storage rules should separate create/update validation from owner-authorized deletion: `request.resource` is unavailable for deletes, so the current image/size checks prevent normal client deletion.

## Scale, AI quality, and release readiness

23. **Bound transaction reads.** `TransactionsRepository.watch()` streams the whole collection; filtering, charts, search, and budgets run locally over all records. Introduce date-bounded queries and cursor pagination for activity, with separate period summaries for dashboards/budgets. Keep all-history exports explicit and complete. Use Firestore timestamps plus a separate occurred-at date and server audit timestamps; current ISO strings can complicate ordering across timezones.

24. **Calculate answers before asking AI to explain them.** AI receives monthly totals and only 15 recent transactions. It cannot reliably answer arbitrary historical/category questions from that snapshot. Add bounded data-query tools and deterministic totals; send only the relevant context. Wait for finance providers to be ready. The monthly calculation also lacks an upper boundary and includes future-month transactions. Support explicit report date/category/account arguments; the current export tool has only format/title/summary and always exports all loaded activity.

25. **Fix profile subscriptions and initialization races.** `AuthRepository.watchProfile()` fetches the profile once per auth event rather than listening to profile changes. Profile edits can leave displayed data stale. Use a UID-scoped profile document stream. Default seeding runs from auth, routing, and form flows with random document IDs; concurrent initialization can create duplicate defaults. Use deterministic IDs/versioned initialization and a single guarded bootstrap path.

26. **Complete platform verification.** iOS still has the placeholder bundle ID documented in README; `Info.plist` lacks photo-library and Face ID usage descriptions and Google sign-in URL configuration. Complete Firebase/OAuth setup and permissions, then verify on a real device. Android release signing already avoids falling back to debug signing; retain that safeguard. Firebase project settings, App Check enforcement, live indexes, and deployed function health require separate verification.

27. **Add focused regression coverage and CI.** Current tests cover a login render, validators, budget calculations, dates, and pure ledger deltas; the root widget test is a placeholder. Add tests for transfer editing, cold edit deep links, idempotent create, metadata-preserving updates, account archiving, concurrent balance changes, user switching, locks, recurrence/month-end dates, and offline draft recovery. Use Firebase Emulator tests for user isolation, malformed writes, ledger invariants, and deletion. Add CI for analysis, tests, Functions compilation, and a web build. Keep generated `.firebase` hosting cache out of commits.

## Suggested implementation order

- **First release:** transfer/edit-route fixes, metadata preservation, idempotency, account history protection, real locking, AI user isolation, and mutation error handling. Add regression tests alongside each fix.
- **Second release:** faster entry, simpler navigation, honest loading/sync states, filtered exports, localization, and explicit currency behavior.
- **Third release:** bill payment history, recurring entries, reminders, receipts, and clear goal allocations.
- **As usage grows:** pagination, period aggregates, offline outbox, richer deterministic analytics, and bounded AI data tools.

Measure time to add an expense, failed/duplicate saves, balance reconciliation errors, reminder delivery, and successful data recovery/export. These will show whether changes actually improve daily use.

## Validation

- Cloud Functions TypeScript build: passed with `npm.cmd run build`.
- Flutter tests: all 21 tests passed (`flutter test --no-pub`).
- Flutter analysis: no errors or warnings; five informational issues. These are unnecessary underscores in routing/budgets/activity, a deprecated explicit Firebase AI `appCheck` argument, and a null-aware-element suggestion in shared widgets. The analyzer command exits nonzero for these infos.
- A separate direct Dart analyzer run reported the same five infos, then encountered a sandbox telemetry-file permission error. The Flutter analyzer above completed normally.
- The initial review made no application source changes; subsequent implementation is recorded in `IMPLEMENTATION_NOTES.md`.
