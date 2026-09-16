# Same-city alert client integration — 2026-09-11

## Implemented

- Friends retains the existing city header, two-column city cards and bottom navigation. A compact “Here together” card expands beneath Your city.
- The card uses the existing city emblem assets and separate avatars. Multiple people appear as a selectable list rather than overlapping avatars.
- “Say hello” opens the system share sheet with a message draft. This is not in-app chat and does not automatically address or send a message.
- Foreground same-city notifications are rendered as a dismissible in-app banner; the system foreground banner is suppressed for these events only. Other notification types retain their existing presentation.
- Existing production `events/<UUID>` links route to Friends and the relevant event, including after a cold launch. The server’s current push payload requires no changes.
- Display content is resolved from the authenticated snapshot, not from notification text or URL parameters. Invalid, unavailable and revoked events do not expose stale friend information.
- Current treatment requires both shared city updates and the event (when opening an event) to be less than 24 hours old. Historical records explicitly do not confirm current colocation. Existing backend matching/session rules are unchanged.
- Per-friend alert/sharing preferences, global city sharing, blocked users and notification-preview privacy are respected.
- Foreground notification IDs are deduplicated in an account/repository-scoped bounded history; bootstrap does not replay the event history. Signing out clears transient presentation state.
- Motion respects Reduce Motion. Automatic banner dismissal is disabled when VoiceOver is running.

## Deliberately not represented as finished

**Follow-up:** personal plans, cloud matching and upcoming reminders were subsequently implemented. See [Personal travel plans](PERSONAL_TRAVEL_PLANS_20260911.md) for deployment and verification; the paragraph below describes the earlier current-city-only change.

The prior personal Travel plans and upcoming-overlap screens are conversation mockups, not an implemented cloud feature. This change does not invent future overlaps from shared Trip membership, schedule future-date pushes, or upload a build to TestFlight/App Store.

Upcoming overlap work still requires personal plan CRUD, explicit per-plan audience, country/city identity and destination-local date intersection, reciprocal visibility checks, revocation, backend event deduplication and notification scheduling. Trip dates can prefill a personal plan, but are not evidence that every participant is present throughout that interval.

## Verification

- Debug simulator build succeeded.
- Added policy coverage for freshness, historical events, unknown IDs, country identity, privacy, blocking and strict URL parsing.
- Added delivery tests for bootstrap suppression, deduplication, routing and sign-out cleanup.
- Added UI tests for the expandable card and unknown-event links opened from another tab and after termination.
- All 12 new targeted tests passed in `/private/tmp/wif-same-city-tests-2.xcresult` (10 policy/delivery tests and 2 UI tests).
- Final regression: 14/14 passed in `/private/tmp/wif-same-city-regression.xcresult`, including existing friend/trip invitation relaunch tests and the final solid-green CTA styling. Screenshot: `same-city-alerts-preview/E415115B-AB1F-4A59-8773-056D908F1A70.png`.
- Live APNs delivery on a signed physical-device build still needs end-to-end verification. Simulator notification routing does not certify APNs provisioning or delivery.

Apple notification integration follows the existing `UNUserNotificationCenterDelegate` callbacks: https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate
