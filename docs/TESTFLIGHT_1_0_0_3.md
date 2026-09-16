# Across Us 1.0.0 (3) — TestFlight handoff

## Build scope

- Production App: `com.yangwy30.whereismyfriend`, App Store Connect ID `6807634842`, team `93RUQ2A6KX`.
- Release configuration, version `1.0.0`, build `3` for both app and widget. Local demo disabled. Existing App Supabase project; not the separately named staging App.
- Release now uses the existing domain-free TestFlight entitlement file. Apple sign-in, App Group and APNs remain; no empty `applinks:` declaration is shipped while the user has no invitation domain.
- Includes cloud Trips, secure recipient invitations, own-flight editing, meeting point, self-check-in, optional friends' flight alerts and stale status labels.
- Uploading to TestFlight does not replace the currently submitted App Store build. Do not submit a new App Store review as part of this task.

## What to test

1. Install build 3 through TestFlight. Confirm the version/build in TestFlight before opening the app.
2. Test Sign in with Apple with a returning account and a previously unused account, including Hide My Email. Record the exact error and local time if it fails. Do not send tokens/passwords/screenshots containing credentials.
3. Repeat login on a physical iPad in compatibility mode; the review device was an iPad Air. Simulator/password-auth tests do not establish Apple login success.
4. With two different Apple accounts on two devices: create a trip, invite the other account, explicitly accept, and confirm both see the same trip. Forwarded invitations must not authorize a different account.
5. Each member adds their own flight. Neither can edit the other's flight. The owner edits a meeting point; the other member sees it. Each updates/clears their own check-in, independently of airline status.
6. Confirm friends' flight alerts initially OFF. Enable them on one device and allow system notifications. Keep the other member's preference OFF to check isolation.
7. With a real near-departure verified flight, validate an actual status transition and push arrival on the opted-in recipient. Background checks are quota-limited, not guaranteed instant. Do not simulate a real friend's cancellation or landing to create test notifications.
8. Tap the notification: it should open the correct accessible trip. Turn alerts off and verify no future pending alerts are delivered. Test with previews disabled to confirm generic notification content.
9. Test sign-out/relogin and cache account isolation. Before any uninstall/reinstall test, preserve any local-only drafts; do not delete user data automatically.

## Release gate

Real-device Apple sign-in, cross-device invitation/sync, and real APNs delivery must be recorded as passed before declaring end-to-end readiness. Existing simulator/backend test results are documented in `TRIPS_LIVE_20260909.md`.

## Current status

- Uploaded successfully on **September 10, 2026 at 22:31:34 EDT** (`2026-09-11T02:31:34Z`); Xcode returned `EXPORT SUCCEEDED`.
- Apple processing completed. The existing **Testers** internal group automatically received build 3; its Builds page visibly shows **1.0.0 (3), Testing, expires in 90 days**. No additional testers or external groups were added.
- Saved build-specific What to Test instructions in App Store Connect (Saved confirmation). Build ID: `08238d1e-237b-49f2-8219-b578ca96b3f5`.
- Build page: https://appstoreconnect.apple.com/teams/9b0eb9fa-54ee-4f56-83ae-1e79e3cf4125/apps/6807634842/testflight/ios/08238d1e-237b-49f2-8219-b578ca96b3f5
- Final archive: `/private/tmp/AcrossUs-1.0.0-3-20260910-final.xcarchive`. A first pre-cleanup archive also exists and was **not uploaded**.
- Verified main/widget build 3, production bundle/API, local demo disabled, valid archive signature. Distribution pipeline re-signed for App Store with `aps-environment=production`, `get-task-allow=false`, Apple sign-in and the production App Group, and no associated-domains entitlement.
- Distribution logs: `/var/folders/z5/mwjh39j95h1dsxqs1m0c8f3r0000gn/T/WhereIsMyFriend_2026-09-10_22-29-31.778.xcdistributionlogs`. Keep raw logs private.
- No real-device Apple login or actual APNs notification delivery has been claimed as passed.
