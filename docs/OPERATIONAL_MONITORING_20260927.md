# Operational monitoring rollout — 2026-09-27

## Delivered

Production now records bounded, structured API failure/latency signals and scheduled notification/flight worker heartbeats. A protected HTTPS endpoint combines these with database reachability, API reachability, push signing readiness and eligible notification backlog. It returns HTTP 503 for an incident and 200 after recovery, suitable for an independent uptime service.

The rollout added only `20260927040000_operational_monitoring.sql`. Production remains on the earlier business API: pending `20260927020000` / `20260927030000` migrations and pagination/bootstrap changes were excluded. Narrow deployment source backups and before/after hashes are stored privately. Function versions at verification: API 26, push-worker 21, trip-worker 7, ops-monitor 1.

No flight subscription, provider quota, app screens, or notification preferences changed. The cloud tests did not send real pushes or inject production failures. No new App Store/TestFlight binary was uploaded.

## Activation boundaries

- **Backend monitoring: deployed and verified.** Correct status token returns 200; wrong token returns 404; unauthenticated client collection returns 401. Both scheduled workers have naturally reported successful heartbeats after deployment.
- **Client diagnostics: implemented, awaiting an App release.** Existing distributed clients do not yet send the new decode/timeout reports. The next release must also review the repository's other pending API dependencies before upload.
- **External email alerts: not activated.** UptimeRobot submission was blocked before execution pending explicit owner approval to disclose the dedicated read-only status URL/token and alert email to that provider. After approval, the owner must also complete UptimeRobot's email activation. Do not interpret an HTTP 200 submission receipt as an active monitor or delivered email.

## Verification

- Full backend suite: **140 passed, 0 failed**.
- iOS unit suite: **189 passed, 0 failed**.
- Isolated cloud checks: **11 passed**, including actual staging API fault capture, client authentication/validation, threshold transitions from healthy to degraded and back, worker heartbeat failure detection, and cleanup of the synthetic account.
- A separate regression test applies monitoring directly to the production schema baseline without the two pending business migrations.
- The queue test confirms retries keep their original age and ineligible deliveries do not generate backlog alerts.
- Release configuration simulator build: **passed**, with diagnostics enabled and code signing disabled.

Test logs and `.xcresult` bundles are local temporary artifacts; protected deployment and smoke receipts live in `.ops-private/`. No probe URL, token, operator email, database key or user records belong in this report.

## Scope and next steps

This is incident detection, not complete analytics or automatic repair. Samples are rate limited; thresholds are counts rather than a full request error-rate denominator. Push signing and queue health do not prove that a specific phone displayed a notification. External checks are intended every five minutes, so alerts are not instantaneous.

See [operations runbook](../scripts/ops/README.md) for scripts, thresholds, safeguards and recovery procedure. Finish provider authorization/owner activation before claiming email coverage; include the client code in a separately verified future app release.
