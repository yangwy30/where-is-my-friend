# Invitation presentation crash — September 11, 2026

## Reproduction and root cause

The existing simulator client crashed when opening the reported friend invitation and again on a normal relaunch without another URL:

```text
SwiftUICore/EnvironmentObject.swift:93: Fatal error:
No ObservableObject of type AppStore found.
```

`AppRootView` injected its environment objects into the main content before attaching its invitation presentation modifiers. `IncomingInviteView` requires `AppStore`, but the sheet presentation did not inherit that injection. The trip invitation sheet has the same dependency and presentation arrangement.

`handleIncomingURL` persists the invitation before presenting it. `AppStore.init` restores it on launch, so the presentation defect causes a repeatable launch crash. This is a client presentation defect, not a Supabase failure or a malformed username.

## Fix

Move the existing AppStore, CityLocationService and WIFAppearanceController environment injections outside both root-level sheet modifiers. Main content and all presentations inherit the same live instances. No accounts, sessions, pending invitations or trips are deleted. A previously saved invitation remains usable after installing the corrected client.

## Regression checks

- Friend invite: actual custom URL open, confirmation and action rendering, terminate with invite pending, relaunch with storage retained, dismiss, relaunch without re-presentation, open the same URL again.
- Trip invite: actual custom URL open, presentation and close action, terminate with invite pending, relaunch with storage retained, dismiss and relaunch.
- Release configuration compile, without signing or upload.

Both invitation UI regression tests passed. Release configuration build succeeded with signing disabled. The tests use only the local demo repository and make no production friend requests.

The complete unit suite and the two existing onboarding navigation/skip/completion UI tests also passed after the fix.

Invitation UI result: `/private/tmp/wif-trips-jade-build/Logs/Test/Test-WhereIsMyFriend-2026.09.11_13-04-41--0400.xcresult`.

This change is local only; no new TestFlight upload or backend deployment is authorized in this repair turn.

Follow-up: the user subsequently authorized production-app upload. The fix was uploaded as **1.0.1 (7)** to the production App's TestFlight at 13:18 EDT; see [delivery record](TESTFLIGHT_1_0_1_7.md). This is not an App Store public release.
