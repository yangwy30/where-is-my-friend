# Across Us 1.0.2 (12) — reliability and single-calendar ranges

User-authorized TestFlight release, September 16, 2026. This upload does not replace the public App Store review build, create a new tester group, or submit external Beta App Review.

## Included

- One calendar for selecting start/end dates in personal plans and Trips, with range highlighting, same-day/cross-month selection, cancel preservation and complete cross-year labels.
- Offline intent ordering and global/per-friend sharing controls that prevent stale settings restoring sharing.
- Account/login-generation checks around requests, token refresh and offline queues.
- Account-scoped plan/Trip cache cleanup, plus manual current-city selection and an explicit return to device location.
- Future-city administrative-area normalization and the final-retry lease fix.
- All previously integrated Friend plans, Trips redesign, flight management and invitation notification work.

## Build and verification

- Production App `com.yangwy30.whereismyfriend`, Widget `com.yangwy30.whereismyfriend.widget`, App Store Connect app `6807634842`.
- Version **1.0.2**, build **12**, changed only in production Release App/Widget configurations. Staging settings retained their prior values.
- Built with Xcode **27.0 (27A266a)** from frozen source at `/private/tmp/across-range-release-20260916.r8cehw7f/source`.
- Source manifest includes 977 files and was verified unchanged after export. Archive, IPA, deployment scripts and logs are in the parent release folder.
- Signed archive/export succeeded. Exported App and Widget report the expected bundle IDs and 1.0.2 (12), local Demo is disabled, and the production API is configured.
- IPA signature verified. Entitlements include production APNs, Sign in with Apple, expected App Group, beta reporting and `get-task-allow=false`.
- Exported IPA SHA-256: `2d3414b95c2e08a9f38ee021866226677cc7649ba754f1ced2649a1e611ddebd`.
- Pre-release verification: **131 unit tests, 90 backend tests and 7 distinct UI flows passed**. Details and the resolved calendar test-identifier issue are in `BUGFIX_AND_DATE_RANGE_20260916.md`.

## Backend migration completed

- Verified the live ledger through `20260915040000` and API v21 / push-worker v17 / trip-worker v4 before migration.
- Private business-data/schema/ledger backup: `.migration-backups/app-predeploy-bFBGBn`; SHA-256 `9c625c4f7951e0e01fd41a9e736b5f8ae118193db9b9e6029ecb990e3c416e23`. Excludes Auth/Storage; not a complete disaster-recovery backup.
- Applied only **20260916010000_travel_identity_and_retry**, with its ledger entry, in one transaction. Guarded by ledger state, live function fingerprints, lock/statement timeouts and table locks preventing a concurrent notification claim during identity rewriting.
- Temporarily paused only cron job 1 (`wif-push-worker-every-minute`); restored its original active state and schedule in the deployment script’s cleanup. Flight cron job 2 remained unchanged. Before/after cron metadata matched.
- Live verification used synthetic application-only profiles in a fully rolled-back transaction: NY/New York matched; different states and missing states did not; notification claim RPC privileges remained service-role-only.
- After rollback: **6 users / 2 Trips / 3 flights / 0 personal plans / 0 upcoming deliveries**. No real Auth accounts/devices were created and no synthetic APNs was sent.
- API, push-worker and trip-worker were not redeployed. Their versions and deployed bundle hashes matched the pre-release values exactly.
- Scheduled notification runs returned HTTP 200 with no timeout or invitation/upcoming error. Counters in the checked runs were zero claimed/delivered/retried/failed. Unauthenticated travel-plan API probe returned HTTP 401.

## Apple upload

- Xcode confirmed **Upload succeeded** at **12:35:00 PDT, September 16, 2026**.
- Apple build ID: `bba514c6-a7e1-4cbd-9bf6-7f243e24af7c`.
- App Store Connect verified upload status **Complete**, version **1.0.2 (12)**, and the existing **Testers / Internal / 1 tester** group. No new group/tester was added.
- Build-specific What to Test saved; the UI confirmed **Saved**. Notes cover single-calendar selection, offline/privacy/account fixes, manual city selection, city aliases and final-retry behavior.
- Build page: https://appstoreconnect.apple.com/teams/9b0eb9fa-54ee-4f56-83ae-1e79e3cf4125/apps/6807634842/testflight/ios/bba514c6-a7e1-4cbd-9bf6-7f243e24af7c

## Remaining physical-device acceptance

Verify weak-network sharing behavior, account lifecycle, manual location and actual APNs receipt on consenting test devices. Simulated/SQL checks and successful upload do not establish real-device notification delivery.
