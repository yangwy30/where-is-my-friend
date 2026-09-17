# Trip planning reminders and quieter UI

Released later on September 17 in TestFlight **1.0.3 (14)** with the matching production backend. See [release verification](TESTFLIGHT_1_0_3_14.md). The implementation-stage notes below record the work before deployment.

## User-facing changes

- Creator Trip options exposes **Delete trip**; **Cancel trip** is removed from the new UI. Members retain **Leave trip**. Old cancelled records remain readable, and the legacy cancellation API remains compatible with already-installed clients.
- Removed normal updating/synced/cached-account footers from Trips, personal plans and trip/flight forms. Initial loading uses a small spinner. Sync completion no longer shows a success toast. Notifications setup is quiet while registering or already connected; the notification settings page shows a retry card only for a real failure/waiting-for-network state. Actionable save/connection errors and user-initiated action feedback remain.
- Eligible missing outbound-flight rows and People include **Remind** for every member, not just creators. A confirmed queue/cooldown result changes the button to **Reminded** and disables repeated taps until eligible again. Sending failure does not mark success or queue the client action offline.
- Trip Notifications includes **Flight planning reminders**, controlling morning reminders and member nudges for that recipient/trip. Existing live flight-status alerts are separate.

## Reminder policy

The app knows whether a participant has added a flight, not whether they purchased a ticket. Copy asks them to book and add the outbound flight; it does not assert that they have not bought one.

- On opening Trips, the authenticated account reports its device time zone and app language. The first report enrolls daily scheduling; later zone/language changes update it quietly. No time zone is guessed for accounts that have never supplied one. The latest reported time zone is used if a device travels without opening Trips again.
- Eligible: active registered membership, linked participant, an upcoming non-completed/non-cancelled trip, planning reminders enabled, and no outbound (or legacy unclassified) flight. Return-only flights do not satisfy outbound planning.
- Automatic reminders run near **09:00 recipient local time**, using the existing minute push-worker schedule. IANA time zones handle daylight saving changes. The catch-up window ends at 10:00; missed morning reminders do not arrive later in the day. Deduplication is per trip/recipient/local date with a 20-hour spacing guard, including recent manual nudges.
- Manual reminders: another active member can send one per recipient/trip per 24 hours, shared across all senders. Self-reminders, outsiders, unlinked guests and cross-trip targets are rejected. Blocked recipients, recipients who opted out or have no active registered device are unavailable.
- Adding a flight, completing/deleting/leaving a trip, removing the member, opting out or transferring/disabling a device prevents pending delivery. Existing cancellation also stops delivery. The worker checks again immediately before APNs.
- Private notification previews omit names and trip details. Chinese/English copy follows the recipient's language. Tapping opens the existing Trip deep link.
- Delivery remains subject to connectivity, iOS notification permission/Focus and APNs; it is not an exact-time alarm. Already delivered notifications cannot be recalled.

## Implementation

Migration `20260917010000_trip_booking_reminders.sql` adds private reminder context, durable reminder/outbox tables, and a per-member preference. Composite foreign keys to membership cascade cleanup when members leave or trips are deleted. Scheduler insertion and device delivery have unique keys; claim tokens, two-minute leases, a five-attempt cap and send-time checks prevent stale/duplicate sends. Invalidating a recipient does not disable a device that has since changed accounts.

API:

- `POST /v1/trip-reminders/context` — `timeZone`, `locale`; authenticated actor only.
- `POST /v1/trips/:id/reminders` — `participantID`; any active member may nudge another eligible member.
- `POST /v1/trips/:id/planning-reminders` — `enabled`; controls only the authenticated member.

`push-worker` handles the new queue during its existing scheduled run. A manual reminder also uses an authenticated best-effort wake-up; durable scheduling remains the fallback. There is no new cron job. RPCs/tables remain inaccessible to anonymous/authenticated database clients; Edge Auth supplies actor identity.

## Verification and release

Validation completed on Xcode 27 / iOS 26.4.1:

- Full backend suite: 106 passed (`/private/tmp/across-reminders-backend-final.log`). An additional opt-out/re-enable deduplication case is included in the final 9-case reminder suite (`/private/tmp/across-reminders-final-policy.log`), making 107 distinct backend tests.
- Existing 139 iOS unit tests passed (`/private/tmp/across-reminders-unit.xcresult`); two added reminder tests also passed in the targeted 12-test run (`/private/tmp/across-reminders-ui-v2.xcresult`).
- Three distinct UI workflows passed: creator removal/delete without Cancel trip, quiet notification settings, and ordinary-member nudge/24-hour feedback/turning reminders off/People entry. Final reminder UI result: `/private/tmp/across-reminder-toggle-v2.xcresult`. A first test fixture attempted to assign an immutable flight direction; corrected to select an outbound fixture. The toggle UI test initially tapped the labeled row instead of the trailing switch; corrected using the observed control location.
- Final screenshots were visually inspected. All tests use synthetic local records and mocked APNs; no real reminders were sent.

Deployment order for a future release: back up/compare the live ledger, apply only this migration, deploy API and push-worker, then ship the new client. No production database/worker change or new TestFlight upload has been performed in this implementation task. The privacy-policy source describes the time-zone/language scheduling data; GitHub Pages publication can precede rollout.
