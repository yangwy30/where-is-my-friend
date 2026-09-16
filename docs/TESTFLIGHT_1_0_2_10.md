# Across Us 1.0.2 (10) — stability release, September 15, 2026

## Scope

User approved deploying the audited stability fixes and uploading the production App to TestFlight. This task does not replace the build in the existing App Store review or submit a new public review. No external Beta App Review or new tester invitations are included.

- Production App: `com.yangwy30.whereismyfriend`; Widget: `com.yangwy30.whereismyfriend.widget`; App Store Connect App ID `6807634842`.
- Version **1.0.2**, build **10**, changed only in Release App/Widget configurations.
- Frozen source and all archive/export/upload artifacts: `/private/tmp/across-stability-release-20260915.eL2gwl/`.
- Code verification before release: 106 unit tests, 3 UI tests and 73 backend tests passed; see `STABILITY_FIXES_20260915.md`.

## Production backend — completed

- Verified live prerequisite `20260915010000_city_region_metadata`, API v19, push-worker v15, and trip-worker v4 before changes.
- Private backup: `.migration-backups/app-predeploy-nTXRuG`; data manifest SHA-256 `5e5bcb39f4c1f45565f350c76aa7f1ab91f436e708b21e962ce2a28d87650b03`. Includes public data/schema/ledger, not a complete Auth/Storage disaster-recovery backup. Deployed API and push-worker source/dependencies were backed up separately.
- Applied **only** `20260915020000_presence_identity_and_freshness` with its ledger entry, in one transaction with lock/statement timeouts and exact live-function fingerprint checks. Did not run a blanket migration push or separately apply the unrelated historical transition migration.
- Deployed **api v20 / ACTIVE / verify_jwt=true** and **push-worker v16 / ACTIVE / verify_jwt=false**. The push-worker retains its existing private bearer authorization.
- Trip-worker stayed **v4**, hash `c8668db872720ca6123da5a78f8e484eb7ba6ac6cf1e673f9d0b9a52d001d31b`.
- Paused only cron job 1 (`wif-push-worker-every-minute`) for the migration window; restored it with its original schedule. Job 2 (`wif-trip-worker-every-five-minutes`) remained active throughout.
- No claimed deliveries or queued HTTP requests were present immediately before migration. No pending same-city deliveries needed retiring. User, trip and flight counts remained 6 / 2 / 3; no user or trip deletion was performed.
- Live pure-function checks passed: cross-state Pasadena rejected, NY/New York aliases equal, missing administrative area unknown, live evaluator uses 24 hours, alternate entry forwards correctly, stored keys match the new identity function.
- New delivery-check RPC: anon/authenticated cannot execute, service_role can. Unauthenticated API and worker probes both returned HTTP 401.
- The resumed push worker returned HTTP 200 with no timeout, zero claimed/delivered/retried/failed, and no invitation/upcoming errors. This is a worker health check, not a real-device APNs test.

## Client packaging

- Release archive and App Store export succeeded. App and Widget versions both verified as 1.0.2 (10), with `WIFAllowsLocalDemo=NO`.
- Exported IPA signature verified; App has production APNs, Sign in with Apple, App Group, beta reporting, and `get-task-allow=false`.
- **Upload succeeded at 14:00:19 PDT on September 15, 2026**. Apple accepted build ID `791b849d-ad7e-4545-a518-e7c72301e6fb`; processing completed and the build detail page is available.
- Build is associated with the existing **Testers / Internal / 1 tester** group. Build-specific What to Test was saved and the UI confirmed **Saved**. No new groups/testers or external Beta App Review were added.
- The internal tester page subsequently showed **Installed 1.0.2 (10)**. Returning to the build detail confirmed the test instructions remained saved. The build page was retained for the user. Installation status is not evidence of successful Apple sign-in or APNs delivery.
- Exported IPA SHA-256: `e5011e65b8029a6380b6023de25114add374eaaf325b0c4175dbe35327dfb892`.

## Acceptance notes

Update in place. Refresh current location to provide missing administrative-area metadata; locations that remain ambiguous are deliberately excluded from current same-city matching. Current presence must be confirmed within 24 hours. Older history remains visible without becoming a new arrival alert.

Real Apple sign-in, actual APNs delivery to the production App and Staging TestFlight, provider-key topic permissions, and real background travel still require physical-device testing. No synthetic notification was sent to real users and no real account was deleted during this release task.
