# Trips — account-bound self-service

September 7 update: cloud persistence and invitation UI are now implemented and the matching API is deployed. See [current cloud delivery record](TRIPS_CLOUD_20260907.md) for verified behavior and remaining release boundaries. The implementation notes below describe the September 6 local-only milestone.

Implemented September 6, 2026. Local code and verification only; no deployment, online data migration, or App Store submission.

Later the same day, the user explicitly authorized deployment. The backend schema, self-service API and AeroDataBox lookup are now deployed and hosted-tested; see [deployment record](TRIPS_DEPLOYMENT_20260906.md). The original implementation results below remain valid, while the iOS UI is still local and no legacy data migration or App Store submission has occurred.

## Permission contract

- Trips uses the App's existing signed-in session. Release/Staging local-demo access remains disabled.
- A member can read their trip's flights and create/update/delete only their own flights.
- The creator can edit shared trip name, destination, dates and completion state. Creator status never grants personal-flight editing rights over another member.
- Flight APIs do not accept a traveler/participant/account identity from the request body. The API resolves its actor from a verified Supabase Auth token; the database resolves that actor's participant within the target trip.
- The old guest RPC and caller-selected-participant flight RPC are removed by the self-service upgrade migration. Direct anonymous/authenticated table and RPC access remains denied.
- New membership uses an invitation to a registered account. Only the intended recipient can accept; pending/expired invitations cannot expose flight data. Acceptance creates a new linked participant and never claims a legacy namesake.
- Legacy data remains unclaimed. Old local itineraries without explicit account bindings are read-only. No one is assigned ownership from their display name, an old PIN, or the fact they requested the migration.

## iOS interaction

- Add flight: fixed signed-in traveler with a lock icon; no traveler picker.
- Waiting state: other travelers' names remain visible, with no action to fill in for them. “Add mine” appears only when the current account has no flight for that direction.
- Own expanded flight: Edit my flight and Delete, with confirmation before deletion. Other travelers' rows expose details only.
- Editing number/date resets the entry to unverified instead of retaining a previous flight's schedule.
- People: read-only member list and an explicit cloud-invitation availability notice. No guest name input or local friend-as-member shortcut.
- The local library has guarded, specific mutation methods instead of a public arbitrary-trip mutation closure. Signing out clears its in-memory itinerary list and disables writes.

Actual simulator captures:

- [Fixed traveler form](trips-self-service-preview/add-my-flight.png)
- [Own flight actions](trips-self-service-preview/my-flight-actions.png)
- [People](trips-self-service-preview/people.png)

## Verification

- `npm run backend:test`: 22 passed, including existing App regressions, bidirectional owner/member write denial, cross-trip writes, spoofed identity fields, deleted/revoked accounts, invitation acceptance/expiry, legacy namesakes, removed RPC signatures and direct-client permission checks.
- First simulator run: 52 passed (48 unit tests and four Trips UI tests), zero failures. Bundle: `/private/tmp/wif-self-service-tests-v1.xcresult`.
- Final simulator run: 50 passed (48 unit tests, self-service add/edit/delete, and Night Jade), zero failures. Bundle: `/private/tmp/wif-self-service-tests-v2.xcresult`. Across both runs, 53 distinct iOS tests passed; the repeated unit/self-service tests are not counted twice.
- The UI workflow creates its own flight, edits it, deletes it with confirmation, and verifies another traveler's flights remain unchanged. Multi-trip creation/persistence, completion/undo, trip editing and map interactions also pass.
- September 6 local PGlite migration rehearsal: 7 trips, 26 participants, 31 flights, 2 notes; 746 field comparisons passed, zero memberships granted and zero PINs copied. Four legacy flight directions remain unclassified and preserved.
- Screenshots were exported from XCTest and visually inspected. These use opt-in example identities, not private imported records.

## Still required before release

The App Trips library is still on-device, not connected to the new API. Account invitation RPCs/routes are now deployed but not wired to iOS invitation UI. Web still uses its old integration: this work does not make the live Web secure retroactively.

Remaining work includes Web account-auth/API adaptation, iOS cloud persistence and invitation UI, invitation revocation/rate limits, authenticated calendar behavior, local draft reconciliation, account-deletion/retention handling, hosted integration testing, and the coordinated legacy-data cutover. See [migration status](TRIPS_MIGRATION_STATUS.md) for backup, identity-verification and source access-containment gates. Do not deploy the foundation migration alone or blindly change client URLs.
