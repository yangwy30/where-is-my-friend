# Operational monitoring rollout — 2026-09-27

## Delivered

Production now records bounded, structured API failure/latency signals and scheduled notification/flight worker heartbeats. A protected HTTPS endpoint combines these with database reachability, API reachability, push signing readiness and eligible notification backlog. It returns HTTP 503 for an incident and 200 after recovery, suitable for an independent uptime service.

The rollout added only `20260927040000_operational_monitoring.sql`. Production remains on the earlier business API: pending `20260927020000` / `20260927030000` migrations and pagination/bootstrap changes were excluded. Narrow deployment source backups and before/after hashes are stored privately. Function versions at verification: API 26, push-worker 21, trip-worker 7, ops-monitor 1.

No flight subscription, provider quota, app screens, or notification preferences changed. The cloud tests did not send real pushes or inject production failures. No new App Store/TestFlight binary was uploaded.

## Activation boundaries

- **Backend monitoring: deployed and verified.** Correct status token returns 200; wrong token returns 404; unauthenticated client collection returns 401. Both scheduled workers have naturally reported successful heartbeats after deployment.
- **Client diagnostics: available in TestFlight 1.0.5 (24), submitted for App Review.** Production migrations 0200/0300 and API 27 were subsequently deployed and verified as part of that release. Existing public 1.0.4 clients do not yet send the new decode/timeout reports; users need the new client. See the [1.0.5 release record](APP_STORE_1_0_5_24.md).
- **External monitoring: activated and checking.** The owner authorized the dedicated health URL/token and alert email disclosure, then completed activation. UptimeRobot monitor `804105616` shows **Up**, checks every **5 minutes**, and lists the owner's account under “To be notified”. The backend independently recorded its first external probe at `2026-09-28 03:01:04 UTC`; the protected health endpoint also returned 200. The private submission receipt alone was not used as activation evidence. Actual outage/recovery email delivery has not been exercised against production; no artificial production outage was introduced.

## Verification

- Full backend suite: **140 passed, 0 failed**.
- iOS unit suite: **189 passed, 0 failed**.
- Isolated cloud checks: **11 passed**, including actual staging API fault capture, client authentication/validation, threshold transitions from healthy to degraded and back, worker heartbeat failure detection, and cleanup of the synthetic account.
- A separate regression test applies monitoring directly to the production schema baseline without the two pending business migrations.
- The queue test confirms retries keep their original age and ineligible deliveries do not generate backlog alerts.
- Release configuration simulator build: **passed**, with diagnostics enabled and code signing disabled.
- Final environment cleanup: old TripFlights backend restored to `ACTIVE_HEALTHY`; isolated staging paused. All five legacy business tables matched the fresh pre-test backup exactly (7 trips, 26 participants, 31 flights, 2 notes, 0 push subscriptions). The production App backend stayed active. No paid plan was activated.

Test logs and `.xcresult` bundles are local temporary artifacts; protected deployment and smoke receipts live in `.ops-private/`. No probe URL, token, operator email, database key or user records belong in this report.

## Scope and next steps

This is incident detection, not complete analytics or automatic repair. Samples are rate limited; thresholds are counts rather than a full request error-rate denominator. Push signing and queue health do not prove that a specific phone displayed a notification. External checks are intended every five minutes, so alerts are not instantaneous.

See [operations runbook](../scripts/ops/README.md) for scripts, thresholds, safeguards and recovery procedure. The client code is included in the separately verified 1.0.5 release, currently awaiting Apple review. The active monitor is available in the owner's [UptimeRobot dashboard](https://dashboard.uptimerobot.com/monitors/804105616).
