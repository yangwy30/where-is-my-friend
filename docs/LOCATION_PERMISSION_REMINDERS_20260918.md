# Occasional location-permission reminders

## Product behavior

The user selected a reminder **at most once every seven days, with three total presentations**.

- An inline invitation temporarily replaces the existing Your city card on the visible Friends home screen. It does not add a modal or another permanent feed section.
- “Enable location” is the only action that requests the iOS When In Use permission. If permission was previously denied, the action becomes “Open Settings.” No Always or precise-location upgrade is requested by this feature.
- “Not now” immediately restores the normal city card and defers another reminder for at least seven days. Presentations are counted even if ignored, preventing indefinite weekly nudging.
- The initial full-screen location setup remains separate. Skipping it starts a seven-day delay without consuming one of the three follow-up reminders.
- Already-authorized users, system-restricted access, paused city sharing, and a manually selected city are excluded. Signed-out users and demo mode are excluded, except explicit debug UI-test fixtures.
- Reminders are suppressed off the Friends home screen, while inactive, during the Add friend/city-sharing flow, and while handling an invitation or a selected same-city/upcoming notification.

## Persistence and scope

History is stored per account on this device, under `location.permission-reminder.v1.<account UUID>`. Navigation, relaunching, signing out, and signing back in do not reset the interval or count. Confirmed account deletion removes the history. It is not a server-wide schedule: another installation maintains its own history.

The presentation is recorded before the card is rendered. Repeated UI updates do not consume additional impressions. A backward clock change or unreadable history cannot cause a burst of prompts. A manual dismissal also defers from dismissal time if the card was left visible for more than a week.

There are no new push notifications, emails, server jobs, or backend changes. Existing sharing choices and automatic-location rules remain in force.

## Apple permission behavior

Apple allows a When In Use request while authorization is undetermined; a prior denial is handled by directing the user to Settings after an explicit tap. See [requestWhenInUseAuthorization](https://developer.apple.com/documentation/corelocation/cllocationmanager/requestwheninuseauthorization%28%29?language=swift).

## Verification

- All **151 unit tests passed**, including seven new tests for exact cooldown boundaries, the three-presentation cap, fresh store instances/relaunches, account isolation, initial setup deferral, eligibility, late dismissal, clock rollback, and invalid saved history.
- **Six distinct iOS 27 UI flows passed**: explicit permission requests, denied access opening Settings, snoozing across tabs/relaunches, initial setup skip, Chinese copy, and returning from Friend plans without another reminder. Final visible-screen gating was rechecked with navigation, permission, and relaunch tests.
- **Two iOS 26 UI flows passed**: explicit permission requests and snoozing across navigation/relaunch.
- Reviewed English and Chinese screenshots; validated the catalog and `git diff --check`.
- Result bundles: `/private/tmp/across-location-reminders-v2-20260918.xcresult`, `/private/tmp/across-location-reminders-final-20260918.xcresult`, and `/private/tmp/across-location-reminders-ios26-20260918.xcresult`.

## Release status

Code change only; TestFlight 1.0.4 (17) predates this feature.
