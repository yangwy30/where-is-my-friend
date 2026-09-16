# Across Us 1.0.2 (8) — profile and first-use reliability beta

## Scope

User requested the first next step: distribute the existing client fixes through TestFlight. Target is the production App's TestFlight, not the separate staging App. No App Store update submission/release and no backend changes in this turn.

- App Store Connect App ID: `6807634842`.
- Bundle IDs: `com.yangwy30.whereismyfriend` and `com.yangwy30.whereismyfriend.widget`.
- Team: `93RUQ2A6KX`.
- App and widget Release configuration: **1.0.2 / build 8**. Debug and staging versions unchanged.
- Apple's public lookup reports production 1.0.1 released September 11 at 23:49:17 UTC; the candidate therefore uses the next version train instead of reusing the released 1.0.1 train.

## Included client fixes

- Save-specific progress/error state instead of the global loading flag.
- Bounded profile-save request, readable inline failure state, safe retry by the user and protection against late results.
- Background refresh cannot discard a successful profile-save response.
- Network failures/username conflicts during authentication refresh are not indiscriminately treated as expired sessions.
- First authenticated use offers contextual location setup, with the real system permission prompt and supported decline/Settings paths.
- Existing friend/Trip invitation crash protection remains. Current Trips, personal-travel and same-city UI work is retained, including the Trip notification-permission hint.

## Verification

- iPhone 17 Pro Max simulator: **85 unit tests + 5 UI tests passed**. Includes profile reliability/network/session tests, location allow/decline, profile editing, and friend/Trip invitation relaunch/dismissal.
- iPad Air 11-inch (M4) simulator: **3 UI tests passed**, covering location allow/decline and profile editing. These are iPhone-compatibility tests; supported-device settings were not changed.
- Archive succeeded. Export to App Store distribution IPA succeeded.
- IPA checked: both version/build fields match; production Bundle IDs and backend; `WIFAllowsLocalDemo=NO`; production APNs entitlement, Sign in with Apple, existing App Group, `beta-reports-active=true`, and `get-task-allow=false`. Signature validates on disk.
- Validation directory: `/private/tmp/wif-testflight-validation.MyaCIb`.
- Results: `iphone.xcresult`, `ipad.xcresult`; archive `AcrossUs-1.0.2-8.xcarchive`; exported IPA `distribution/Where Is My Friend.ipa`.

## What to Test

Please update in place from the previous build; do not delete the App unless specifically testing a fresh installation.

1. Open Edit profile before saving. It should not show a Save spinner because unrelated work is running.
2. Change your display name and username, save, close/reopen the editor, and confirm the saved values persist.
3. Try a username already in use. Confirm the error is readable, the editor stays usable, and your login is preserved.
4. Test a save with a weak/offline connection. Confirm progress ends and an error is shown rather than spinning indefinitely. Reconnect and check your actual saved profile before retrying, since a timed-out request may already have reached the server.
5. Test Sign in with Apple with returning and first-time users on real devices. Report the build, approximate time, and screenshot if it fails.
6. On first authenticated use, test allowing location and declining it. Settings/Not now should remain usable; denial must not trap the user.
7. Open friend and Trip invitations, leave them pending, close/reopen the App and dismiss/reopen them. Confirm no crash and no loss of existing account/Trip data.

The intermittent upstream gateway timeout is not declared fully fixed. Simulator/password-auth checks do not establish success of a specific user's native Apple authorization. Real-device verification remains part of this beta.

## Delivery status

- **Upload succeeded September 12, 2026 at 00:31:23 EDT / 04:31:23 UTC.** Xcode reported `Uploaded package is processing.`, `Upload succeeded.`, and `EXPORT SUCCEEDED` using `Config/TestFlightUploadOptions.plist`.
- Upload log: `/private/tmp/wif-testflight-validation.MyaCIb/upload.log`.
- Navigating to this App's TestFlight page redirected to App Store Connect login. The browser session is still unauthenticated; a user login request was presented and the login tab retained.
- **Processing completion, tester-group assignment and install availability have not yet been confirmed.** What to Test is prepared above but has not been saved in App Store Connect. No Beta App Review submission or tester notifications were performed in this turn.
- No App Store update draft was submitted or published. Existing public 1.0.1 was not replaced.
