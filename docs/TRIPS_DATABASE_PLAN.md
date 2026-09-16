# Trips: reuse the existing database

Updated September 6, 2026 (America/New_York). The user approved consolidation into the App project and clarified that accounts are mandatory and each person manages only their own information. This supersedes the earlier shared-editor/guest proposal. Following explicit deployment authorization, the three Trips migrations, authenticated API and AeroDataBox lookup are now deployed; old Web data/client migration and iOS cloud integration remain pending. See [deployment record](TRIPS_DEPLOYMENT_20260906.md).

Current evidence, implementation boundaries, and cutover gates are in [TRIPS_MIGRATION_STATUS.md](TRIPS_MIGRATION_STATUS.md).

## Recommendation

Do not create a third database just for the iOS Trips tab. Reuse an existing Supabase Postgres database as the canonical trip store for Web and iOS. Sharing data is compatible with separate frontends; the required migration concerns identity and authorization, not the number of clients.

The user and live CLI inventory confirm that these are separate projects. The chosen destination is the App project `cdhpaujazbuppbxyhjxq`; the source is `zgqjctiuycrhwrstorxw`. The App's checked-in Release configuration points to the destination even though its dashboard name includes `staging`; treat it as serving the release app, not as a disposable test database.

The original alternatives were:

- If they already use the same project: add compatible membership fields/tables and APIs to that project.
- If they use separate projects: choose a canonical backend. Prefer evaluating consolidation into the existing App project, which already owns Apple/Supabase authentication, and migrate the Web trip data and Web integration together. Alternatively, keep the Web database behind a server-to-server integration that validates App identity and enforces membership. Do not send one project's JWT to another and assume equivalent identity.
- Avoid two independently writable copies of the same trip. Back up and rehearse migration before any cutover; preserve the currently deployed App and Web behavior until their replacements are verified.

## Evidence from the repositories

The Web [schema](https://github.com/yangwy30/ppc-tripflights/blob/main/supabase_schema.sql) already defines `trips`, `participants`, `flights`, and `notes`. Child tables have `trip_id` foreign keys. Existing trip IDs are text, not necessarily UUIDs; preserve them during import.

Web authorization is trip-scoped: [verify-pin](https://github.com/yangwy30/ppc-tripflights/blob/main/supabase/functions/verify-pin/index.ts) issues a seven-day custom JWT with a `trip_id` claim. The checked-in RLS policies match that claim. This grants access to a trip; it is not a durable account membership record.

The Web [data adapter](https://github.com/yangwy30/ppc-tripflights/blob/main/src/data/dataAdapter.js) remembers trip tokens locally and loads those trips. Participants and flight authors are represented by names; `flights.added_by` is text. This cannot reliably identify which Apple account owns a participant across devices. Never claim a participant automatically just because display names match.

The App's `supabase/migrations/20260812220000_supabase_auth_identity.sql` binds `app_users.auth_user_id` to Supabase `auth.users`. The App already uses a server API and Apple/Supabase authentication. Keep this session intact; do not replace it with the Web's single-trip PIN token when opening a trip.

The live audit subsequently found important drift: all five Web tables have anonymous CRUD privileges and broad `Allow all` RLS policies in addition to trip-scoped policies. The original PIN boundary is therefore not reliable. Do not import those policies or assume the old PINs/calendar tokens are still secret. The live schema also includes `push_subscriptions`, which the original schema file omitted.

## Additive migration design and remaining integration

1. Introduce a membership relation such as `trip_members(trip_id, app_user_id, role, joined_at)`, with a unique `(trip_id, app_user_id)` pair and explicit owner/member permissions. Trip creation plus owner membership must be atomic.
2. All new participants require an account. The owner invites a registered account by username; only that account can accept, which atomically creates membership and a new account-linked participant. Nullable account associations exist only to preserve legacy data without claiming it. No guest creation, name-based identity matching, or PIN-only joining is allowed.
3. Add `flights.participant_id` referencing a participant in the same trip. Keep legacy `added_by` during compatibility rollout. Backfill only unambiguous matches within each trip; report unresolved rows. Author identity and traveler identity are separate concepts.
4. Add a nullable completion timestamp and define destination-local date semantics. Preserve old text date fields until validated and migrated. An end date is inclusive; the trip becomes Past the following local day. Multiple overlapping trips are allowed.
5. Members read their trip's flights and add/edit/delete only their own. Flight creation resolves the participant from the verified account on the server; clients cannot submit a participant ID. The creator manages shared trip metadata/completion, not other travelers' flights. Test owner-to-member and member-to-owner denial as well as cross-trip access.
6. Replace Web PIN sessions with App-project account authentication and accepted invitations. Never copy old policies or JWT signing secrets. Retire old PIN access and invalidate old calendar credentials at a coordinated cutover. Calendar sharing must not bypass account-only access; do not port a public feed unchanged. Add invitation revocation and rate limiting before production use.
7. Add iOS cloud sync only after those APIs exist: import local drafts with stable IDs/idempotency, reconcile server errors without losing drafts, and explicitly exclude example trips. Test sign-out/account switching, account deletion, offline recovery, expired credentials, and Web/iOS coexistence.

Server secret/service-role keys must never be embedded in either client. If a privileged server connection bypasses RLS, membership checks are mandatory in the server API itself. See [Supabase API key guidance](https://supabase.com/docs/guides/getting-started/api-keys).

## What the current iOS iteration implements

- Trips library with Ongoing, Upcoming, and collapsed Past sections.
- Empty state and New trip flow: name, supported destination airport, start/end dates.
- Multiple simultaneous trips, trip-specific participants/flights/routes, editing, completion and undo.
- Read-only member list; no guest field, friend-as-guest action, or traveler selector. Own flights have edit/delete controls; other travelers' missing flights show waiting status.
- Account-linked local participant and creator fields. Legacy local rows without explicit bindings remain read-only; names never confer ownership.
- Atomic on-device persistence separated by App account and environment. A corrupt archive is preserved, not overwritten.
- Example trips are opt-in, explicitly labeled, and separate from the initial empty state.

The iOS cloud/lookup/invitation UI is not connected. The People sheet explains this instead of pretending to invite people locally. Backend account invitation/acceptance and AeroDataBox lookup operations are deployed and passed hosted tests, but the App still records local unverified entries. The destination picker currently uses the small local airport directory, not a global airport search. Local drafts are not a backup and do not survive app deletion. Local file cleanup on account deletion and production data-retention behavior must be connected before release.

The foundation, self-service upgrade and lookup migrations were applied together after backup and rehearsal. No shared-editor RPC remains deployed. Legacy records were not imported online; the earlier local rehearsal granted zero memberships and copied no PINs. A verified legacy identity/consent plan (or archival-only import), account-based Web adaptation, iOS cloud integration, and a fresh cutover snapshot/write-freeze remain required. Do not assign all legacy travelers to the requester or run a blanket database push as a substitute for this cutover procedure.
