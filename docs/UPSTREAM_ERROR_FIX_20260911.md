# Deployed upstream error classification and safe retry fix

## Scope

Deployed only the App `api` Edge Function to `cdhpaujazbuppbxyhjxq` on September 11, 2026 at approximately 22:56 EDT. Version **18**, **ACTIVE**, `verify_jwt: true` (unchanged from version 17). No database migration, user permission change, Apple provider configuration change, worker deployment or TestFlight upload.

Pre-deployment source backup: `/private/tmp/wif-api-before-fix.kyWyqE`. Deployment staging directory: `/private/tmp/wif-api-fix-deploy.jmWyDX`. Staged the deployed dependencies plus only the changed API and new policy module, excluding an unrelated local addition to `travel-plans.mjs`.

## Behavior

- Auth gateway/transport failures retain temporary status (503/504 or rate-limit 429). They no longer become 401 `The session expired.` Genuine rejected credentials still return 401; authorization is always checked before application RPCs.
- RPC errors preserve their upstream HTTP status for classification. Gateway 504 is no longer converted to user-input 400. SQL/internal failures are not exposed verbatim as user input errors. Existing domain validation, conflict, access and quota responses remain covered by regression tests.
- Retry allowlist: `GET /auth/v1/user`, `POST /rpc/wif_resolve_app_user`, and `POST /rpc/wif_snapshot`. Both RPCs are read-only. A transient failure can trigger **one** extra attempt, with 200–299 ms jitter. 400/401/403/429 responses are not retried.
- No automatic replay of profile saves, account initialization, invitations, flight lookups, token exchanges or other writes. SDK database retries are explicitly disabled so two retry mechanisms do not stack. The exact production SDK version was tested.
- Each upstream attempt has a 6.5-second abort deadline covering response body reading. Caller cancellation suppresses retry. These are per-upstream-call limits, not a claim that the complete user operation has a 6.5-second deadline.
- Structured upstream-failure logs include a fixed stage, status, attempt, elapsed time and the upstream request ID when present. They omit tokens, request bodies, query strings, profile values and raw error text.

## Verification

- Full backend suite: **64 tests passed**. Includes preserved permissions/business behavior and new classification/retry tests.
- Exact SDK `@supabase/supabase-js@2.112.3`: **5 local fault-injection scenarios passed**, using the actual API handler and SDK with a fake network transport. Covers persistent Auth 504, transient Auth recovery, profile 504 with exactly one write attempt, genuine invalid JWT, and account-resolution recovery. No live fault injection or network traffic in these cases.
- Hosted temporary-account smoke passed: Auth login, bootstrap, profile save, concurrent read/save, token refresh and persisted-profile verification. Profile PATCH responses were 200 in approximately **627 ms** and **526 ms**. Temporary Auth account and cascading data were deleted; no real user's profile was changed.
- Deployment metadata confirms version 18 and JWT verification enabled.

## Limits / remaining release work

This corrects how upstream failures are classified and how safe operations recover. It does not prove the underlying intermittent Supabase gateway 504 condition has disappeared. Writes that time out may have an unknown commit outcome and are not silently replayed.

Server behavior applies to existing clients immediately. The separately implemented client spinner/state/deadline fixes still require a new client build. Native Apple authorization on the affected person's phone remains to be matched to their screenshot/time; password-auth smoke is not a substitute for that test.

Reference for disabling the SDK's additional retry policy: [Supabase retry documentation](https://supabase.com/docs/guides/api/automatic-retries-in-supabase-js).
