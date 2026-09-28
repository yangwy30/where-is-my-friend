# Same-city delivery and Always-location reminders

## Findings

The reported device had While Using location authorization even though its stored background-update preference was on. The implemented significant-change/visit monitoring requires Always authorization. Opening the app obtains a fresh foreground city, which can create a same-city event only at that point. Three recent production deliveries also waited 31–87 seconds from event creation to APNs acceptance, mostly before a delivery was claimed by the scheduled worker. APNs acceptance is not proof of a banner appearing on a phone.

The earlier app kept the location service and city-upload subscription in `AppRootView`. There was no scene-independent startup owner or short background execution allowance spanning resolution and upload.

## Changes

### Gentle permission reminder

- The existing Friends city-card reminder now includes While Using authorization and directs the user to choose Always in iOS Settings.
- The existing account-scoped history remains unchanged: at most one presentation every seven days, at most three presentations total. Permission upgrades do not reset the budget. Initial setup deferral, dismissal and app relaunch keep the same cooldown.
- Always-authorized users, restricted users, signed-out users, paused city sharing and intentionally selected manual cities are excluded. Only the visible, active Friends home screen can consume an impression.
- No recurring push/email campaign or automatic system permission prompt was added. The user taps the action to open settings. If they explicitly choose this action with the app's background preference off, the preference is saved first; actual monitoring still waits for iOS Always authorization.
- Location settings and the city-sharing sheet distinguish While Using from available background authorization. English and Simplified Chinese copy are included.

### Scene-independent city updates

- `PushRegistrationDelegate` owns one `CityUpdateRuntime`, initialized before scene construction. The view receives the same store and location service; city publication is observed independently of SwiftUI view subscriptions.
- Cached account identity and sharing preferences restore the existing significant-change/visit subscription during startup. Foreground UI refreshes run only when the scene is active.
- A short, bounded UIKit background execution allowance covers reverse geocoding, upload, and a city write deferred behind another AppStore mutation. Idle completion or foreground return releases it. Expiration cancels outstanding work; account changes invalidate old work.
- A stale background location callback requests one fresh fix, throttled to avoid a request loop. Old coordinates are not published with an invented fresh timestamp.
- Existing Always consent, sharing/manual-city checks, account isolation, freshness validation and geocoder generation guards remain in force. There is no continuous background GPS polling.

### Immediate server wake

- A successful presence RPC triggers a best-effort `colocation` worker action after the write has committed.
- This action drains only the same-city queue using the existing interactive lease. Scheduled jobs retain their reserved lane, retries, claim-token deduplication and eligibility checks.
- Per-isolate same-city wake requests coalesce within five seconds. Failed/coalesced wake-ups retain the durable queue and scheduled fallback; city updates do not fail because of push delivery.
- The worker was deployed before the API. No database migration, secret, cron schedule, recipient enrollment, flight-provider setting or subscription changed.

## Verification and rollout

- Full backend suite: **143 passed**.
- Final serial iOS suite: **193 unit tests and 4 UI tests passed**. New checks cover startup without a root view, background expiration and late callbacks, stale wake recovery, While Using restrictions, weekly limits, settings navigation and cooldown across relaunch. Existing friend-plan navigation also passed.
- UI screenshots were exported from `/tmp/across-background-final.xcresult` and inspected in `/tmp/across-background-ui-evidence/`; English Always and Chinese location reminders fit the existing card layout.
- Production **API 28 / push-worker 22** deployed with exact baseline/source checks and private backups under `.ops-private/same-city-wake/`. Post-deploy monitor returns 200, with no active failure/backlog flags.
- Release configuration simulator compilation: **passed**.
- **Client code is available in TestFlight 1.0.5 (25) and submitted for App Review.** After owner approval, the earlier build24 submission was withdrawn and replaced with build25; see the [release record](APP_STORE_1_0_5_25.md). The backend wake improvement is already active for compatible existing clients. Public users need the new client for the reminder/lifecycle changes.

Simulator tests do not establish physical-device wake timing, arrival-to-banner latency, or APNs screen presentation. A real journey with two opted-in devices, Always location, automatic updates and notifications enabled remains the acceptance check. Low power, Background App Refresh, network availability, Focus and iOS scheduling can affect results; no immediate-delivery guarantee is made.

References: [Apple location authorization](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services), [background location](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background), [notification delivery](https://developer.apple.com/documentation/usernotifications/).
