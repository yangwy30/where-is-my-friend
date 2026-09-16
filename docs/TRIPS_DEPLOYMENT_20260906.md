# Trips backend deployment — September 6, 2026

User authorized deployment to the App project and asked to include the previous flight departure/arrival lookup.

## Deployed

- Project: `cdhpaujazbuppbxyhjxq` (shared by checked-in App Release/Staging configurations).
- Applied only `20260906010000`, `20260906020000`, `20260906030000` together in one transaction, with an advisory lock, baseline guard, lock/statement timeouts and migration-history entries. The exact deployment bundle was rehearsed against the hosted baseline first.
- Deliberately excluded the unrelated pending `20260901220000_transition_based_colocation.sql`. Do not blindly run `db push --include-all` to fix the resulting local/remote history gap.
- App `api` is ACTIVE, version 11, JWT verification remains enabled. Bundle SHA-256: `0ee05bbd25f01223c7bf9b2d208d8c75123461fd0e899cac2893ec8fc2d17c12`.
- Added only the server secret `RAPIDAPI_KEY`, using the existing validated AeroDataBox/RapidAPI credential. No key values were logged or added to source. No Apple Auth or APNs secret was changed.
- No push-worker code was deployed. Its bundle hash stayed `f4c127513506f333473e0543323e1ac761c6bac0a1493db541e56f046dcf8518`; its listed version advanced from 4 to 5 after project secret configuration. API advanced from 9 before the secret change to 11 after deployment.
- Old Web project and client endpoints remain untouched. No legacy records were imported or assigned accounts.

## Flight lookup contract

The old Web's flight-number/date lookup is AeroDataBox through RapidAPI (`src/data/flightService.js`), not its `search-flights` SerpAPI ticket-price search. The new API proxies the existing provider server-side:

```http
POST /functions/v1/api/v1/trips/{tripID}/flight-lookup
Authorization: Bearer <signed-in App Supabase access token>
apikey: <App project public key>
Content-Type: application/json

{"flightNumber":"UA353","date":"2026-09-06"}
```

The caller must be an account-linked member of that trip. No participant/account ID is accepted in the body. Response includes provider source, requested departure date, fetch timestamp and all distinct matching route candidates. Each candidate keeps scheduled, revised, predicted and runway times separately, plus original time-zone offsets, provider status and update time. Revised/runway fields may be estimates; they are not automatically labeled actual. Unknown statuses remain unknown. No mock fallback is used.

The provider query explicitly uses `dateLocalRole=Departure`, avoiding a previous-day overnight flight appearing just because it lands on the chosen date. See [official date-filter explanation](https://aerodatabox.com/flight-history/) and [official API specification](https://doc.aerodatabox.com/docs/openapi-rapidapi-v1.json).

Five-minute shared cache, protected by membership checks even on cache hits. Durable launch limits: 10 uncached requests/hour/account and 50/day across this App integration. Failures consume a reservation; no automatic retry loop or recurring provider polling was enabled. These are application guardrails, not a statement of the provider subscription's quota. Cache writes are service-only.

Lookup returns candidates; it does not silently attach the first route to a saved flight. UI route confirmation and validated persistence of the selected provider result still need integration.

## Verification and cleanup

- 27 local backend tests passed, including provider error handling, credential non-disclosure, multiple routes/date handling, account-only access, spoofing denial and durable quota/cache checks.
- Eight Trips database tests also passed against the actual hosted migration baseline, excluding the unrelated pending migration.
- One direct provider check returned HTTP 200 and two UA353 route candidates. Scheduled vs predicted times were preserved separately.
- Nine hosted smoke checks passed using two temporary accounts: anonymous denial, existing Auth/bootstrap, trip creation, recipient-only invitation acceptance, no pending-invite access, flight ownership, creator-to-member edit/delete denial, real provider lookup, cache reuse, own-flight deletion and trip completion. Some checks combine multiple assertions.
- Removed the exact generated smoke trip and both temporary Auth accounts after testing. Their account/trip data was test-only, not user data. No test emails were sent.
- Final read-only verification at `2026-09-06T15:54:06.215Z`: all 21 pre-existing database function definitions and ACLs unchanged; zero temporary accounts or trips remained; zero legacy trips imported.
- No iOS source changed in this deployment turn. Prior 53 distinct iOS tests remain the local UI verification, not evidence of an end-to-end App-to-cloud flow.

## Backup and recovery

Private backup: `.migration-backups/app-predeploy-FMkxfv/` (Git-ignored, restricted directory/files). Snapshot timestamp `2026-09-06T15:41:38.83991+00:00`; SHA-256 `d6024b817a04c94e30bfff5a8722e0c77e90d743666f2cf9525c3b87981555ed`.

Contains public data/schema metadata, function definitions/permissions, migration ledger, downloaded pre-deployment API source in `deployed-supabase/`, hosted smoke report, and post-deployment verification. It is not a full Auth/Storage/secrets disaster-recovery backup. Do not commit or upload it.

If API rollback becomes necessary, redeploy the backed-up API source with JWT verification enabled; the additive Trips schema can remain without affecting old routes. Do not drop tables or roll back migration history after user writes begin. Review the exact deployed revision before any recovery action. Secret removal/rotation must be coordinated, particularly since the old Web still uses its existing credential.

## What is NOT yet live in the App

The Trips iOS UI still uses account-isolated local storage. It does not yet call the cloud CRUD/invitation/lookup endpoints. Connecting those endpoints, selecting and persisting the correct provider route, refreshing the board, offline reconciliation, and release UI testing are the next implementation stage. No new App Store binary was submitted.

SerpAPI price shopping, the old Web `flight-monitor` cron/Web Push worker, and calendar feeds were not migrated or activated. The old monitor cannot be copied verbatim: its account model, date/route selection and push mechanism differ. No automatic flight polling or flight-status notifications are claimed by this deployment.

The old Web uses `VITE_RAPIDAPI_KEY`, which is browser-exposed by design. Moving a copy server-side protects the new App client but does not retract the old exposure. Coordinate credential rotation when the Web is moved behind account-authenticated server access; do not break the current Web by rotating without that cutover.
