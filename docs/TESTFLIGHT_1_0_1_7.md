# Across Us 1.0.1 (7) — invitation crash hotfix

## Scope

- User requested production upload after the client repair. This uploads to the existing production App's TestFlight, not staging; it does not submit or publish an App Store release.
- App: `com.yangwy30.whereismyfriend`, App Store Connect `6807634842`, team `93RUQ2A6KX`.
- App and widget Release build numbers advance from 6 to 7; version remains 1.0.1. Existing production backend and staging configurations unchanged.
- Fix: inject root environment objects outside both invitation sheet modifiers so friend and trip invitations inherit AppStore. Previously saved invitations no longer cause a missing-environment-object crash on relaunch.
- No account, session, trip or invitation data is cleared. No backend changes.
- Root cause and regression details: [invitation crash report](INVITE_CRASH_2026_09_11.md).

## Verification before upload

- Two invitation UI regression tests passed: actual URLs, persisted pending invitations across relaunch, dismissal and reopening.
- Additional regression run: 65 passed, 0 failed (all unit tests plus two onboarding UI tests).
- Release compile passed during repair. Signed archive for upload: `/private/tmp/AcrossUs-1.0.1-7.xcarchive`.

## What to Test

This build fixes a crash when opening friend or trip invitation links, including a repeat crash on launch when an invitation was saved.

Please update in place without deleting the app. Open a friend invitation, leave it pending, close and reopen the app, then dismiss the invitation. Confirm the app remains usable. Repeat with a trip invitation. Existing data should remain intact.

## Delivery

- Signed archive succeeded; app and widget both report build 7 and local demo is disabled.
- Distribution signature verified; production APNs, Apple sign-in and the existing App Group are present, with `get-task-allow=false`.
- Distribution logs: `/var/folders/z5/mwjh39j95h1dsxqs1m0c8f3r0000gn/T/WhereIsMyFriend_2026-09-11_13-16-30.463.xcdistributionlogs`.
- **Upload succeeded September 11, 2026 at 13:18:35 EDT** (`EXPORT SUCCEEDED`). Apple upload ID: `0faeff05-4ea9-4cf9-819e-cddf1a4eda7c`.
- Independently confirmed in App Store Connect: **1.0.1 (7), Processing, Sep 11 2026 1:18 PM**. Processing is not yet confirmation that testers can install it.
- No App Store review submission, public release, external-test review change or backend deployment was performed.
