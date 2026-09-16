# Trips lifecycle: leave, cancel, delete, remove member

## Behavior

- A member can **Leave trip** from Trip options. Their participant, shared flights and membership are removed together. Other members and flights remain. The former member loses API access and flight alerts; rejoining requires a newly issued invitation.
- The creator cannot leave an ownerless trip. They can **Cancel trip** or **Delete trip**.
- **Cancel trip** keeps the itinerary in Past, with a Cancelled/read-only label. It stops editing, new invitations, pending invitation delivery and flight alerts/tracking. It cannot be undone through the existing Undo completion endpoint. Ordinary completion remains reversible.
- **Delete trip** permanently deletes the shared itinerary, memberships, participants, flights, notes and invitations for everyone. It does not cancel airline reservations.
- The creator can **Remove member** from People. Their own row has no remove action. Removing someone also removes that participant's shared flights and invalidates their old invitation. Other trips remain unchanged. Existing unclaimed itinerary rows can also be removed by the creator; this does not grant ownership of legacy identities.
- Destructive actions use explicit two-button alerts, naming what will be lost. Dismissing the alert changes nothing. English and Simplified Chinese copy is included.

## API and database

`POST /v1/trips/:id/lifecycle`

Payload: `action` (`leave`, `cancel`, `delete`, `removeMember`), UUID `requestID`, current trip `revision` for creator actions, and UUID `participantID` only for `removeMember`. Leave accepts neither revision nor target identity. Extra fields, spoofed actor identities, malformed UUIDs and invalid revisions are rejected. The actor comes only from verified Auth.

Result: `{ success: true, trip: <current snapshot or null> }`. Cancel/remove return the current creator-visible snapshot; leave/delete return null. Replayed requests return current accessible state, never a historical snapshot.

Migration: `20260916020000_trip_lifecycle.sql`.

- Adds `cancelled_at`; cancellation also sets `completed_at`, preserving old clients' archival behavior and existing worker eligibility checks. A constraint prevents a cancelled trip from becoming active accidentally.
- Serializes existing itinerary writes and lifecycle actions on the trip row. Membership is rechecked after acquiring the write lock. Invitation acceptance/dismissal use the same trip-before-invitation lock order. Acceptance/removal bumps the trip revision so stale creator confirmations fail with a conflict.
- Cleans up affected pending/claimed delivery rows. Worker prepare functions continue to recheck eligibility before APNs. Already sent/in-flight external notifications cannot be recalled.
- A private receipt keyed by actor/request UUID makes retries safe after a lost response, including deletion. Receipts retain only identifiers, action, revision and timestamp; no itinerary or names. They cascade on account deletion. Direct anonymous/authenticated access is denied; only the service-role RPC is exposed to the API.
- Existing legacy flight, completion and check-in RPCs honor cancellation/access restrictions; hiding a UI action is not the permission boundary.

## Client reliability

Remote changes are acknowledged before updating the list. Failed writes remain visible as errors and are not queued offline. Retrying an unconfirmed action in the same library session reuses its request UUID. Account/scope generation checks prevent late responses from modifying a different session. Successful leave/delete removes the local cached trip; successful remove/cancel replaces it with the server snapshot. Other members reconcile on the existing refresh cycle (foreground, pull-to-refresh, periodic active refresh). Offline devices may retain their previously downloaded cache until reconnection; server revocation does not remotely erase an offline device.

## Verification

- Full backend suite: 95 tests passed after the migration fixture compatibility fix. Two additional populated outbox scenarios passed in the six-test lifecycle suite: cancellation invalidates pending invitations, and leave/remove/cancel invalidate already-claimed flight deliveries.
- iOS: 10 TripLibrary tests and one remote lifecycle retry test passed. Cover cancellation persistence, prohibited owner departure/member management, own-account isolation, removal of only the selected participant's flights, and lost-response retry/cache reconciliation.
- Two UI workflows passed on iPhone 17 Pro Max / iOS 26.4.1 after switching from a system popover (which hid the cancel action) to explicit two-button alerts: creator remove/cancel/delete and member permission/leave. Cancelled-trip read-only behavior and backing out of destructive actions are covered. Final screenshots were visually inspected.
- Unit result: `/private/tmp/across-trip-lifecycle-ui.xcresult` (11 unit tests passed; the initial popover UI failures were corrected). Final UI result: `/private/tmp/across-trip-lifecycle-ui-final.xcresult` (2 passed). Backend logs: `/private/tmp/trip-lifecycle-all-backend-final.log` and `/private/tmp/trip-lifecycle-push-cleanup-final.log`. Total distinct backend tests passed: 97.

## Release boundary

Implementation and local verification only. No production data was removed, no invitation/APNs was sent, and no backend migration, Edge Function deployment or TestFlight upload was performed for this change.

For release, back up and compare the live schema/ledger, apply only the reviewed lifecycle migration, deploy the API, then ship the App. Do not blindly apply the unrelated local transition migration. Verify the hosted flow with isolated consenting test accounts before testing real trips. The existing trip-worker can remain deployed because cancellation uses its established completed-trip exclusion and member removal removes its source/access records.
