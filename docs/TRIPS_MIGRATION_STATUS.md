# TripFlights consolidation — preparation status

Updated September 7, 2026, America/New_York. **iOS cloud persistence, account-bound friend invitations and server-validated flight selection are implemented; the matching schema/API are deployed to the App project.** See [current cloud delivery record](TRIPS_CLOUD_20260907.md). HTTPS invitation hosting, production iOS release and legacy Web migration remain pending. The September 6 preparation audit below is historical; references to a local-only iOS client describe that earlier snapshot.

The user's clarified requirement supersedes the original shared-editor design: account required, each person manages only their own flights, trip creator manages shared trip details only. No new guests or PIN-only access. Existing records must not be assigned to the requester or claimed by matching names.

## Confirmed destination

- Source: Web project `zgqjctiuycrhwrstorxw`, confirmed against the existing Web checkout's URL and the authenticated CLI project list.
- Destination: App project `cdhpaujazbuppbxyhjxq`. Its name is `where-is-my-friend-staging`, but the checked-in App Release and Staging configurations both point here. Do not reset it or assume it is disposable. The submitted App Store binary itself was not inspected.
- Destination public tables currently contain App users, friends, presence, devices, and notification delivery data; no name collisions with the proposed Trips tables were found.
- Source functions: `verify-pin`, `search-flights`, `flight-monitor`, `calendar-feed`. Destination functions: `api`, `push-worker`. The original audit deployed nothing; following explicit authorization, App `api` now includes Trips and flight lookup. No old Web function or push-worker code was replaced.

## Security finding requiring a cutover decision

The live Web database differs from its checked-in schema. `trips`, `participants`, `flights`, `notes`, and `push_subscriptions` all have RLS enabled, but also have broad `Allow all` policies and anonymous SELECT/INSERT/UPDATE/DELETE grants. Restrictive-looking PIN policies coexist with those broad rules and do not restore isolation: permissive PostgreSQL policies combine with OR. See [PostgreSQL row security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html).

Consequently, do not rely on old PIN secrecy or reuse old calendar credentials. This is a configuration finding, not proof that anyone exploited it. No source records, PINs, or subscription payloads were printed to tool output or added to Git. No source permission changes were made, because tightening access may interrupt the current Web integration and must be coordinated.

Recommended: explicitly approve a source access-containment plan, retire PIN access and old calendar credentials at cutover, and retain only tested account-scoped access paths. Do not port a publicly accessible calendar feed unchanged. Never move the source JWT signing secret into the App project.

## Private source snapshot and rehearsal

- Exported at `2026-09-06T01:41:33.006425+00:00` (September 5 in New York).
- Counts: 7 trips, 26 participants, 31 flights, 2 notes, 0 push subscriptions.
- Snapshot SHA-256: `ed7130384a0112996979625d433ccf20f0eb29c46a8a8731544f0ceed3b5f38e`.
- Local directory: `.migration-backups/tripflights-ams0eX/`, ignored by Git, with directory mode 0700 and snapshot mode 0600. It contains sensitive data; do not upload it, include it in a PR, or paste its contents into chat.
- Snapshot is a single-statement consistent export of these public tables plus column/constraint/policy metadata. It is **not** a full disaster-recovery backup of Auth, Storage, function deployments, settings, or secrets, and it is not proof that no changes occurred afterward.
- The second local PGlite rehearsal verified all imported row counts and 746 field values, preserving IDs and source data except intentionally excluded access credentials.
- All 31 flights matched a participant by exact name within their own trip. This is itinerary association, NOT account ownership. Four flights remain unclassified as outbound/inbound; their original route information is preserved.
- Zero memberships were granted. No old PINs, JWT secrets, RLS policies, calendar tokens, or push subscriptions were activated in the destination schema.

## Implementation

- `supabase/migrations/20260906010000_unified_trips_foundation.sql`: protected trip tables, account memberships, same-trip participant foreign keys, completion, and service-role-only RPCs with internal membership checks.
- `supabase/migrations/20260906020000_trip_self_service.sql`: upgrades roles to owner/member; drops guest creation and the old caller-selected-traveler RPC; adds self-only flight create/update/delete and account-targeted invitations/acceptance. Both migrations must run in order.
- `supabase/migrations/20260906030000_trip_flight_lookup.sql`: account-gated lookup reservations, durable launch quotas and service-only provider cache. All three Trips migrations are now deployed.
- `supabase/functions/api/index.ts`: authenticated trip routes. Flight writes resolve the participant server-side and reject caller-supplied identity fields. Guests are explicitly rejected. Only an invitation's intended account may accept, and pending invitations do not grant access to flight data.
- iOS: fixed signed-in traveler, read-only People list, no guest/friend substitute, own-flight editing/deletion, other travelers' waiting state. Local ownership uses explicit account bindings; old unbound local data remains read-only. No cloud invitation UI is enabled yet.
- `scripts/trip-migration/export.mjs`: read-only source snapshot; restricted files and checksum; no raw records in logs.
- `scripts/trip-migration/transform.mjs`: strips legacy access credentials, preserves data IDs, rejects unknown source columns/orphan rows, and never infers App membership from a name.
- `scripts/trip-migration/rehearse.mjs`: offline-only PGlite import and field-by-field verification, with no remote write capability.

The earlier 22 backend tests were supplemented with provider/lookup coverage: 27 now pass. Eight Trips database tests also pass against the actual hosted baseline, and nine grouped hosted smoke checks passed with temporary accounts that were cleaned up afterward. See the deployment record for scope and limitations. The earlier source-data rehearsal verified 746 fields with zero memberships granted and zero PINs copied; that remains a local import rehearsal, not an online data migration. iOS's local library is still not connected to these APIs.

## Remaining gates — do not switch clients yet

1. Decide how legacy records should be retained: archival-only, or a separately reviewed identity-verification/consent process. Until then, import them unclaimed and inaccessible. Do not assign all trips/travelers to the requester or match names to App accounts. Trip-level management and personal-flight ownership are separate decisions.
2. Coordinate account-based rejoining and retirement of old PIN sessions/calendar links. Existing Web sessions must not silently continue with overbroad privileges. Invitation revocation/rate limits and account-only calendar behavior still need production implementation.
3. Implement the new Web API adapter and secure join/calendar flows. The existing `.from(...)` Web client will NOT work by merely changing its URL, because the destination intentionally denies direct-client table access. Port flight lookup/monitor integrations with appropriate authentication and server-side secret configuration; avoid duplicate notification workers during transition.
4. Connect iOS cloud storage with stable IDs and explicit handling of local drafts/examples. Resolve the four unclassified journeys without inventing route data. Test cross-device sharing, expired sessions, offline reconciliation, invitations, and account-deletion/retention behavior.
5. Completed for the schema/API deployment: private destination backup, deployed-source comparison and exact additive migration review. Repeat before any later data import or production changes. Existing Apple Auth configuration was not changed.
6. Rehearse hosted behavior in an isolated environment; local PGlite and stubbed HTTP tests are not a replacement. Do not create a paid project/branch without approval.
7. At a coordinated cutover, freeze source writes or reconcile a final delta; take a fresh verified export. The earlier private snapshot is preparation, not a live synchronization mechanism. Apply/import atomically, verify counts/fields, and test authorized and unauthorized access before switching clients.
8. Keep the old project for recovery without maintaining two writable canonical copies. After destination writes begin, rollback requires reconciling those writes; blindly switching back can lose data. No old project deletion is authorized or performed.

## Commands already used safely

```sh
npm run backend:test
node scripts/trip-migration/export.mjs zgqjctiuycrhwrstorxw
node scripts/trip-migration/rehearse.mjs .migration-backups/tripflights-ams0eX/snapshot.json
```

The original export is read-only against the source and its rehearsal is local. Subsequently, explicit authorization was obtained to apply the three Trips migrations and deploy the App API; scoped temporary smoke-test writes were made and cleaned up. No blanket `db push`, source Web changes, legacy import, Web redeployment, or App Store submission was performed.
