# Across Us 1.0.3 (13) — city illustrations and Trip lifecycle

User-authorized TestFlight release, September 17, 2026.

## Included

- All integrated work through `0ce8556`, including the other task's force-unwrap/actor-conformance fixes.
- Compact city/state labels without flags, with full geography in detail views.
- Generic 3D neighborhood artwork and a frosted globe for unknown/private locations. Sharing-aware artwork protects cached geography; widgets no longer invent New York/Tokyo for missing presence.
- Trip member departure, creator member removal, cancellation/read-only archive and permanent deletion; explicit two-button confirmations and English/Chinese copy. Durable request receipts protect retries after lost responses.
- Existing single-calendar date ranges, friend plans and account/privacy reliability changes remain integrated.

## Frozen build and validation

- Xcode 27.0 (27A266a). Production app `com.yangwy30.whereismyfriend`, widget `com.yangwy30.whereismyfriend.widget`, team `93RUQ2A6KX`, App Store Connect app `6807634842`.
- Release App/Widget: **1.0.3 (13)**. Other build configurations retain their previous versions.
- Frozen source: `/private/tmp/across-testflight13-20260917.u29i_wun/source`. Manifest covers 1,237 versioned input files and was rechecked unchanged after archive/export.
- **97 backend tests, 139 iOS unit tests and 5 UI workflows passed** on the frozen source. UI covers creator/member lifecycle, city artwork including light/dark/private states, and the single calendar date range.
- Results: `verification.xcresult`, `verification.log`, `backend-tests.log` in the release folder. The initial backend command used an incompatible Node resolved by npm in the temporary directory; the completed passing run uses the explicit Node 22.22.1 executable.
- Initial 1.0.2 archive and signed export succeeded. Apple rejected that upload because 1.0.2 was already approved and its pre-release train closed. Production marketing versions were raised to 1.0.3; only that version metadata differs from the tested source. Final 1.0.3 archive/export and system signature verification also passed. Signature verification passed using system trust services. App/Widget both report build 13, local demo is disabled, the production API is configured, APNs is production, and debug entitlement is false.
- Initial rejected-version IPA SHA-256: `920d21ffa9bf761f0b211d39283685cb6479b5c632f53a793057c81d22d2edad`.

- Final **1.0.3 (13)** exported IPA SHA-256: `b8019e6ccddf730a067f0e63319b6e4426bbeb2a7cf37df20454077483b53acb`.

## Production backend completed

- Private public-schema/data/ledger backup: `.migration-backups/app-predeploy-u8Zadv`; SHA-256 `1802a9cf67d7ce5bb71bad258a76973640fc251b32b607aaea081d9654c985ef`. Auth/Storage/secrets excluded; not a complete disaster-recovery backup.
- Backed up the deployed API source. Source comparison found only the new lifecycle route in API code; existing imported helpers are unchanged.
- Applied only **20260916020000_trip_lifecycle**, with its ledger record, in one transaction. Guarded by the expected ledger baseline, five existing function fingerprints, and lock/statement timeouts. The unrelated local transition migration was not applied.
- Deployed **api v22**, preserving JWT verification. **push-worker v17** and **trip-worker v4** retained their exact deployed hashes and were not redeployed. Cron schedules were not changed.
- Hosted SQL verification passed in a fully rolled-back transaction with synthetic application-only profiles: removal/leave revoke access and old invitations; cancellation archives and blocks reopening; deletion cleans dependent data; repeat deletion request succeeds safely; RPC execution remains service-role-only. The first synthetic username exceeded the existing 20-character limit and rolled back; the corrected verification passed.
- After rollback: **6 users / 2 Trips / 3 flights / 5 memberships**, matching pre-deployment business counts. No test Auth account, registered device or APNs was created/sent.
- Unauthenticated HTTP request to the lifecycle endpoint returned **401**.

## Apple upload

Xcode confirmed **Upload succeeded** at **13:02:52 PDT, September 17, 2026**. App Store Connect verified **1.0.3 (13)** upload status **Complete**, with the existing **Testers / Internal / 1 tester** group attached. No new tester group or external Beta App Review submission was created.

Apple build ID: `5c3c9624-a8df-4d20-9290-4d9959332bd1`. Build-specific Chinese/English What to Test notes were saved; the App Store Connect UI confirmed **Saved**. Prepared notes are in the release folder's `what-to-test.txt`.

Build page: https://appstoreconnect.apple.com/teams/9b0eb9fa-54ee-4f56-83ae-1e79e3cf4125/apps/6807634842/testflight/ios/5c3c9624-a8df-4d20-9290-4d9959332bd1

The upload did not submit a new public App Store version or replace its store metadata.

## Physical-device follow-up

Verify the new operations with disposable test trips, including weak-network retry and two-account membership changes. Existing screenshots use local demo data. Hosted SQL verification and upload do not establish actual device notification delivery.
