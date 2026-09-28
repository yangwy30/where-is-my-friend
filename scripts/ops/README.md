# Operational monitoring

Production backend: `cdhpaujazbuppbxyhjxq`. Its historical dashboard name contains “staging”; do not use the name to choose a target. Isolated tests use `tyeeulfevixeuttmrzeq`.

## Current rollout

The 2026-09-27 rollout installed only migration `20260927040000_operational_monitoring.sql` and instrumentation around the existing production functions. Pending migrations `20260927020000` and `20260927030000` and their API changes were deliberately excluded. Do not deploy the entire repository API or upload a new client as part of a monitoring-only repair.

- `prepare-production.mjs` is a **one-time rollout preparation script** that downloads the deployed source and proves a narrow patch against the pre-monitoring Git HEAD (`f2012c5`). It is not a general deployment command and must not be rerun over the completed deployment/backups.
- `deploy-production.mjs` requires a passing isolated smoke receipt, exact function versions and source hashes. Without `--apply`, it prepares SQL only. The rollout is already applied; do not replay it.
- `verify-production.mjs` checks the protected status URL, invalid-token rejection, unauthenticated collector rejection, worker state and function versions. It does not inject faults or send push notifications.
- `deploy-staging.mjs` and `staging-smoke.mjs` target the isolated project only. The smoke test temporarily changes a staging RPC, restores its original definition in `finally`, and deletes its synthetic account.
- `request-monitor.mjs` submits a UptimeRobot activation request. It must run **only after the owner explicitly authorizes disclosure to UptimeRobot of both the dedicated token-bearing health URL and alert email**. A successful HTTP response is not evidence of delivery or activation. The owner must complete the provider's email confirmation and activation step. The local receipt prevents blind duplicate submissions.

## Protected configuration

`.ops-private/` is ignored by Git and holds deployment backups, source hashes, smoke receipts, operator email, probe URL/token and provider submission receipt. Do not copy these to issues, logs or documentation. `production-monitor.json` contains `projectRef`, `probeToken`, `url`, and `recipient`; `operator.json` contains `recipient`. Secrets are generated locally during the initial rollout. Keep directories mode 0700 and secret files mode 0600.

Supabase secrets: `WIF_OBSERVABILITY_ENABLED=true`, `OPS_PROBE_TOKEN=<random 32-byte hex>`. This status token grants aggregate status access only; it is not a database/admin credential. If exposed, rotate the secret and update the external monitor together.

## Checks and limits

The HTTPS health endpoint returns 200 when healthy, 503 when degraded, and 404 for an incorrect token. It combines observed error events, eligible notification queue age, scheduled worker heartbeats, a read-only API probe, and push signing readiness. It does not verify delivery to a phone or query the paid flight provider.

Incidents include 5 server errors in 5 minutes, 3 client decode errors in 10 minutes, 5 timeouts in 5 minutes, persistent sampled latency, global push configuration failure, eligible notification backlog older than 10 minutes, and missing successful push/trip heartbeats after 10/30 minutes. Retries preserve original queue age; expired or opted-out deliveries do not create backlog alerts.

Diagnostics are bounded and sampled, not complete analytics or a true request error-rate denominator. Normal offline failures, cancellation, and expected authentication/conflict errors are excluded. No request bodies, raw error messages, names, city names, or access tokens are stored. Events expire after 3 days and are capped around 10,000 records. Direct database access is service-only.

Client reporting requires a future App release. Debug disables it; Staging and Release enable it. Reports are best effort, use the same Supabase project, reject redirects, and retain the original user-facing error behavior.

## Incident handling

1. Open the protected status page from the private configuration; identify the affected feature.
2. Inspect Supabase Edge logs and private health aggregates for that feature. Do not publish user data or the probe URL.
3. Check scheduled worker heartbeats and queue eligibility before replaying any job. Do not manually trigger push drains as a health test.
4. Repair the specific failure, then verify the endpoint returns 200 and the external provider reports recovery. Error windows may take up to 10 minutes to clear.

To disable event instrumentation safely, set `WIF_OBSERVABILITY_ENABLED=false`; coordinate external monitoring expectations to avoid misleading alerts. Preserve the additive schema and original function backups. No destructive rollback is required.

Provider references: [official setup](https://uptimerobot.com/quick-monitor-setup/), [pricing](https://uptimerobot.com/pricing/). Owner activation is confirmed for monitor `804105616`: the dashboard shows Up, a five-minute interval and the owner as alert recipient; a real external probe is recorded by the backend. Production outage/recovery mail delivery has not been artificially exercised.
