# Dedicated hosted test environment

These scripts target **only a separately named Supabase project**, never the historical project named `where-is-my-friend-staging` (which serves the live App). All three pre-existing project references are denied before credentials or test requests are loaded.

## Guardrails

- `target.json` must specify `isolated-staging`, exact project name `across-us-isolated-staging`, expected organization and `us-east-2` region.
- Before writes or load, the live inventory must match. Provider secrets and active cron jobs cause refusal. A database marker must explicitly disable real push and flight-provider integration.
- Real Supabase password sessions must belong to the target project, be unexpired and represent distinct test users. No live tokens, data, Apple credentials or push devices are copied.
- First pass is bounded to 20 users and increasing 1/5/10/20-user tiers, three sequential navigation journeys per user. The baseline gives each actor at most one request in flight. After it passes, the optional third CLI argument `5` runs five parallel journeys per account, still using only 20 distinct accounts, with at most 100 in-flight requests. Reports distinguish account count from request concurrency. Any failed response stops the current tier and further escalation.
- HTTP redirects are rejected. Credentials stay in ignored, private local files. Logs contain counts/statuses, never tokens, passwords or response bodies.
- Cleanup verifies each Auth user's exact run marker and email before deleting it. It retains the project and schema.

## Provisioning

Cloud creation and billing are separate actions. These scripts do not create organizations/projects, upgrade subscriptions, pause old projects or alter production. `initialize.mjs` only applies current migrations and deploys the API into a verified fresh isolated project (or resumes its recorded migrations). It deliberately does not deploy push/flight workers or copy provider secrets.

Copy `target.example.json` to `.staging-private/target.json` and fill the **new** project reference and its organization after creation. Do not link the main checkout to a different project; every command passes the target reference explicitly.

```sh
node scripts/staging/initialize.mjs
node scripts/staging/preflight.mjs
node scripts/staging/configure-client.mjs
node scripts/staging/prepare-users.mjs
node scripts/staging/seed.mjs
node scripts/staging/smoke.mjs
node scripts/staging/run.mjs
# Optional, after a clean baseline; archive latest.json before the next run.
node scripts/staging/run.mjs .staging-private/target.json 5
node scripts/staging/queue-check.mjs
node scripts/staging/cleanup.mjs
```

Prerequisites: existing Supabase CLI authentication, Node 22.22+, permission to administer the isolated project. Standard hosted password auth must be available for the confirmed synthetic accounts. Do not loosen production Auth limits to make a load test pass. If the hosted environment rejects initialization/sign-in (including rate limits or JWT gateway configuration), stop and diagnose the isolated environment before retrying.

`prepare-users.mjs` records each created Auth user before sign-in/bootstrap. A partial failure can therefore be cleaned up. `cleanup.mjs` replaces the session file with a receipt; archive that receipt separately before deliberately starting a fresh run. No implicit account creation loop or automatic reseeding occurs.

The small first fixture gives 20 users 19 accepted friends each, three plans per friend, 57 overlaps each, and one 5-person Trip. It is a hosted calibration and correctness check, **not** a substitute for the prior 1,000-user/100-friend local stress dataset. Larger hosted tiers must account for Auth limits, server metrics and capacity before adding users or traffic.

## iOS isolation

The `Staging` and `Staging TestFlight` configurations inherit `Config/Staging.xcconfig`; its defaults are blank, so unconfigured builds fail closed. `configure-client.mjs` writes ignored `Config/Staging.local.xcconfig` with the dedicated project URL and public anon key. Service-role keys and database passwords never enter an App build.

The staging bundle rejects known existing project hosts, mismatched API/Auth hosts, unexpected API paths and URL credentials/query fragments. Its App Group and URL scheme remain separate. Release retains its existing production configuration.

## Reports and limits

Reports are written to `.staging-private/results/`. Review aggregate reports before copying them into `docs`; never publish the session file or private backup directory.

Hosted measurements include internet, real Supabase Auth token validation, gateway, Edge runtime, PostgREST and Postgres. They do not prove real Apple sign-in, APNs delivery or end-user iPhone display. No flight lookup is performed. Record region, compute configuration, dataset, cold/warm state and failure boundaries rather than claiming a general production capacity number.

The harness is locally tested with synthetic responses, and migration/fixture generation is rehearsed against a fresh PostgreSQL-compatible database. Successful local harness tests do not mean cloud tests have run; use the dated environment report for actual execution status.


An optional fourth argument to `run.mjs` compares `us-east-1` or `us-west-1` for that run only. It adds the documented `x-region` header and records the observed `x-sb-edge-region`; it does not pin the App or permanently change a project. Explicit region requests lose automatic regional failover, so a one-off faster measurement is insufficient reason to ship a pin.

`queue-check.mjs` adds 100 fake device deliveries on the seeded 20-user fixture, checks concurrent claim uniqueness, drains follow-up batches, disables one recipient's reminders, then verifies five cancellations and 95 simulated acknowledgements. It calls real hosted SQL/PostgREST but never APNs. The fake device/reminder rows and temporary preference change are cleaned up in `finally`.
