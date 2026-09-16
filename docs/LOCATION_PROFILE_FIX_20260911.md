# First-use location and profile-save fixes — 2026-09-11

## Findings

- Onboarding was intentionally illustrative. Neither its completion nor authentication routed a first-time user to real location authorization. Existing manual controls were buried in city sharing/settings.
- The profile editor used the global `isWorking` state, so unrelated activity could disable Save and show a spinner. REST requests used the session's default timeout, and the complete save (including Auth refresh) had no UI deadline. The exact affected users' production network traces were not available; no claim is made that a specific server request was reproduced.

## Changes

- After authentication, live accounts without location access see a contextual setup screen. Enable location invokes the real When In Use system prompt. Declined permission offers Open Settings; restrictions and Not now remain supported. Authorized users and users who explicitly skipped are not repeatedly prompted. Demo/onboarding previews do not request permissions.
- Pending invitation sheets wait until setup completes rather than covering it. Granting permission, including via Settings, resolves the current city; it does not require enabling background tracking. Existing sharing choices are unchanged.
- Profile Save uses its own in-flight state and disables only its editable fields/Save. Server errors appear inside the editor. Profile-specific offline wording no longer falsely says a profile write has been queued.
- An overall 25-second save deadline includes Auth. It cancels its request and releases the UI even if the transport does not promptly cooperate; late results cannot apply a client snapshot. Timeout wording acknowledges that the server may already have accepted the write. Saves are not automatically retried or queued.
- Profile API requests have a 15-second request timeout; other endpoints retain their existing behavior. Pending location uploads do not hold the completed profile editor open.

## Verification

- iPhone 17 Pro Max simulator: 19 tests passed (17 policy/store/network unit tests and two UI tests). Real system permission dialog triggered; decline/settings/continue path passed. Both display name and username saved and the editor dismissed. Deadline, late-response, retry, conflict and offline paths passed. Result: `/private/tmp/wif-location-profile-fix.xcresult`.
- Local database: 6 tests passed, including a new atomic profile update / duplicate-username rollback test using all current migrations. No production user data was modified.
- iPad Air 11-inch (M4) simulator: 21 tests passed (18 policy/store/network unit tests and three UI tests). Covers granting location, declining and continuing, profile editing, and the authenticated PATCH payload/15-second timeout. Result: `/private/tmp/wif-location-profile-ipad.xcresult`.
- Final profile-only timeout scoping recompiled and its network contract test passed: `/private/tmp/wif-profile-final-network.xcresult`. Inspected the exported iPad setup screenshot: text and permission/skip actions are visible and unobstructed.

## Release boundaries

Client code only: no backend deployment, TestFlight upload, App Store submission, or changes to users' device permissions. Existing installs need a new build. Production Sign in with Apple/session/network behavior should be checked on a physical TestFlight device before release.
