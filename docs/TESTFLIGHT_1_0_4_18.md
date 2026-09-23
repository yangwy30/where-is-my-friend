# Across Us 1.0.4 (18) — friend-plan visibility default

## Change

- Existing and new personal plans now default to appearing in the Friend plans feed for the friends selected on each plan. The owner can still turn that switch off; an empty audience remains visible to no one.
- The migration backfills existing plans, increments their revisions to reject stale edits, sets the database default to `true`, and makes legacy writes preserve a later opt-out.
- No new plan-sharing notification or external tester group was added. Group Trips still do not automatically create personal plans.

## Hosted database

- Project `cdhpaujazbuppbxyhjxq`, migration `20260923010000` applied alone, excluding the intentionally undeployed colocation transition migration.
- Pre-deployment private backup: `.migration-backups/app-predeploy-a7V9ce/`, SHA-256 `1f0911418a2843a95bc923e333624d6595ef752c423c241a64a217bcf84fcc4e`. This backup is excluded from Git and does not include Auth, Storage, or secrets.
- Read-only post-deployment check: 1/1 personal plans browsable, 3 selected-friend feed entries, new-plan database default `true`, migration ledger present, zero pending upcoming notifications.

## Verification and Apple delivery

- Backend: 108/108 tests passed, including backfill, legacy writes, explicit opt-out, friendship removal and blocking.
- iOS 27 simulator: 4/4 `FriendTravelPlanTests` passed. The initial attempt with the Staging build configuration could not enable `@testable` imports; the matching Debug test scheme passed.
- Production App and Widget: 1.0.4 (18), production bundle IDs and API, local Demo disabled. Signed archive `/private/tmp/across-testflight18-20260923/AcrossUs-1.0.4-18.xcarchive` passed system signature verification.
- Frozen source archive SHA-256: `acdb9f95c1ad390d7437734eb27288036ed94b9805b28a45961413d087f5c344`; source commit `2356ba5`.
- Xcode upload succeeded September 23, 2026 at 16:29 PDT. App Store Connect subsequently showed upload status **Complete** for build **1.0.4 (18)**, assigned it automatically to the existing **Testers / Internal / 1 tester** group, and saved bilingual What to Test notes.
- Apple build ID: `2e0b3c16-033c-42c2-b21d-2080c19762dc`. [TestFlight build page](https://appstoreconnect.apple.com/teams/9b0eb9fa-54ee-4f56-83ae-1e79e3cf4125/apps/6807634842/testflight/ios/2e0b3c16-033c-42c2-b21d-2080c19762dc).
- No public App Store submission or external beta review was started. A physical-device check with two signed-in accounts remains useful to confirm the expected feed appearance after both devices refresh.
