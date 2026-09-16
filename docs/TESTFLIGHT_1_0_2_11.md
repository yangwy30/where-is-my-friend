# Across Us 1.0.2 (11) — Friend plans and integrated updates

Released to the existing internal TestFlight group on September 15, 2026, following the user’s upload request. No public App Store review build was replaced, no external Beta App Review was submitted, and no new testers were invited.

## Included

- Friend plans beside Around the World, shared-plan list/detail, private copying with “I’ll be there too,” explicit browsing consent and Chinese translations.
- Existing Trips redesign: people/flights before the smaller map, arrival dates/time zones, outbound/return views.
- Trip-based initial flight date and the other task’s friend/Trip invitation notification reliability improvements.
- Prior stability fixes already included in build 10.

## Frozen build and verification

- Release App and Widget: **1.0.2 (11)**. Only their Release build numbers changed; Staging/TestFlight variant settings were preserved.
- Production bundle IDs: `com.yangwy30.whereismyfriend` and `com.yangwy30.whereismyfriend.widget`; App Store Connect App ID `6807634842`.
- Source snapshot, hash manifest, archive, exported IPA and all release logs: `/private/tmp/across-friend-plans-release-20260915.a5vum4es/`.
- 987 frozen input files; the manifest was rechecked after upload with no changed source files.
- Signed Release archive and App Store export succeeded. Exported App/Widget version and bundle identifiers verified; `WIFAllowsLocalDemo=NO`; expected production API configured.
- IPA signature verified using the system trust chain. Entitlements include production APNs, Sign in with Apple, correct App Group, beta reporting and `get-task-allow=false`.
- Exported IPA SHA-256: `ff4afd64d830ed223a121e855fa336553c5f9080142bcc4272378d7c9a163354`.
- Pre-release verification: 123 unit tests, 85 backend tests and 7 distinct UI regression flows passed. Final translations/layout also passed both new UI flows; see `FRIEND_TRAVEL_PLANS_20260915.md`.

## Backend deployment completed

- Verified live starting point: API v20, push-worker v16, trip-worker v4; migration ledger through `20260915020000`.
- Private business-data/schema/ledger backup: `.migration-backups/app-predeploy-MixDBG`, manifest hash `392a43bb4e8767244f7ca8e6e3a13437c994782ebb2596b7cf75ed41a2e711cc`. This excludes Auth/Storage and is not a full disaster-recovery backup. Deployed API and push-worker source were backed up separately in the release folder.
- Applied **only** `20260915030000_friend_invitation_notifications` and `20260915040000_friend_travel_plans`, with ledger entries, in one transaction guarded by ledger state, previous function fingerprints and lock/statement timeouts.
- New API **v21 / ACTIVE / verify_jwt=true** and push-worker **v17 / ACTIVE / verify_jwt=false** deployed from frozen source. The worker retains private bearer authorization. Trip-worker remained **v4**, unchanged bundle hash `c8668db872720ca6123da5a78f8e484eb7ba6ac6cf1e673f9d0b9a52d001d31b`.
- Both existing cron jobs retained their schedules and active state. No flight-query budget was changed.
- Live SQL verification used two synthetic application-only profiles in a transaction that was fully rolled back. It checked new-request outbox creation, matching-only privacy, explicit one-sided plan browsing, revocation, blocking and function privileges. No real Auth account, device or push was created.
- After rollback, counts remained 6 users / 2 Trips / 3 flights / 0 personal plans / 0 friend alerts. No historical invitation backfill was performed.
- Unauthenticated API and worker probes returned HTTP 401. The scheduled worker returned HTTP 200 with no timeout or friend-invitation/upcoming/invitation error; latest checked counters were zero claimed/delivered/retried/failed. This is service health evidence, not proof of phone delivery.

## Apple upload and availability

- Xcode reported **Upload succeeded** at **16:36:09 PDT, September 15, 2026**.
- Apple build ID: `f3d3aa27-9595-4d08-9aee-6a570f4ded4c`.
- App Store Connect subsequently showed build upload status **Complete** and the build detail **1.0.2 (11)**.
- Existing group verified on the build detail: **Testers / Internal / 1 tester**. No group additions were necessary.
- Build-specific What to Test was saved; App Store Connect confirmed **Saved**. Instructions cover new friend plans, private defaults, revocation, integrated Trips changes and real-device push checks.
- Build link: https://appstoreconnect.apple.com/teams/9b0eb9fa-54ee-4f56-83ae-1e79e3cf4125/apps/6807634842/testflight/ios/f3d3aa27-9595-4d08-9aee-6a570f4ded4c

## Privacy page

- Published only the two reviewed consent/sharing paragraphs from an isolated clone. The development working tree and its unrelated uncommitted changes were not committed or pushed.
- Commit: `da91950669b92ed3755e40c5b13b77f16071bdda`.
- Existing GitHub Pages workflow succeeded: https://github.com/yangwy30/where-is-my-friend/actions/runs/35044154258
- The system’s old GitHub CLI binary had an incompatible CPU architecture. An official ARM64 GitHub CLI release was downloaded into the release folder, verified against the release SHA-256, and used with the existing credentials. No system binary or global credential configuration was replaced.

## Remaining acceptance

The build is available to the existing internal group. Real Apple sign-in, APNs delivery on production/staging devices, real two-account plan browsing/revocation, and background travel still need physical-device verification. App Store Connect availability does not establish successful installation or notification receipt.
