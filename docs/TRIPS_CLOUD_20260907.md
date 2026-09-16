# Trips cloud collaboration — September 7, 2026 (New York)

Historical delivery record. See [September 9 flight updates and meeting coordination](TRIPS_LIVE_20260909.md) for the newer API, worker, opt-in alerts and deployment status.

## Delivered

- iOS `TripLibrary` now uses `RemoteAppRepository` for signed-in cloud trips: list, create, shared details, completion/undo, own-flight add/edit/delete. JSON is a read cache scoped by API origin and App account, not the canonical database.
- Writes wait for server acknowledgement. Offline reads use the cache with an explicit status. Failed saves keep the form open and do **not** claim success or automatic background retry. This first version does not include a durable offline-write outbox.
- Refresh on Trips opening, pull-to-refresh, foregrounding, and each minute while active. This is refresh-based cross-device synchronization, not Supabase Realtime or push-driven instant updates.
- Per-resource revisions protect edits from stale-device overwrites. Flight changes do not replace the entire trip or another member's flight. New-trip/flight IDs remain stable while retrying the same open form.
- Signed-in trip owners select existing friends from People. Recipients see a Trips invitation card and explicitly Join or Decline. Pending invitations grant no flight access. Owners can revoke pending invitations; accepted memberships aren't silently removed by revocation.
- Invitations expire after seven days, are account-bound, and rotate IDs when reissued. Forwarding doesn't authorize a different account; expired/revoked links cannot become valid after reissuing. Blocking prevents invitation creation/acceptance.
- Native share sheet with trip context and an account-bound deep link. App link handling preserves the invitation across sign-in and opens a confirmation preview, never automatic membership.
- Old local device drafts require an explicit "Move … to my account" action. Only explicitly owned drafts and own flights are imported; old provider snapshots become unverified flight numbers/dates. Examples, namesakes and other travelers are never uploaded as account-owned data. Original local files are preserved, completed imports marked locally, partial imports can retry with stable IDs.
- Flight search is authenticated, trip-scoped, cached, and quota-limited. Demo lookup is deterministic and makes no live calls. A selected route is persisted from the server's provider cache in the same database transaction as the flight; clients cannot upload status/route/identity JSON. Expired selections require another search.
- Correct labels for in-flight, cancelled, diverted, unknown and unverified flights. Details show the provider-check timestamp and state that this isn't continuous live tracking.

## Deployed

Destination: App Supabase project `cdhpaujazbuppbxyhjxq` (Release and Staging currently share this project).

1. Removed the pre-auth `/v1/flights/lookup` bypass and deployed API version 13. Verified a public publishable key receives HTTP 401 with invalid test input; no provider quota spent by that probe.
2. Applied only `20260907010000_trip_cloud_collaboration.sql`, atomically with a migration-ledger entry, baseline checks, lock timeout and advisory lock. Did not deploy unrelated `20260901220000_transition_based_colocation.sql`.
3. Deployed API version **14**, ACTIVE, `verify_jwt=true`, source hash `860d6fed6201eb49108412b4242caf58a6a297ef3c9faf163e4e8f252f1ffc9b`.
4. `push-worker` code hash remains `f4c127513506f333473e0543323e1ac761c6bac0a1493db541e56f046dcf8518`. The 21 original non-Trips database functions and ACLs are unchanged.

The previous API source was downloaded into `/private/tmp/wif-api-security-m9LfMG/`. A private pre-migration public data/schema snapshot is in `.migration-backups/app-predeploy-6qjfEk/`, exported `2026-09-08T03:26:41.27488+00:00`, SHA-256 `c33cf26595b8a73ae7dc53b55e1f0f856b1b32a767ff53883c214eff90cfb5fa`. It excludes Auth, Storage and secrets; it is not a full disaster recovery backup. Do not publish its raw contents.

## Verification

- `npm run backend:test`: **31 passed**, including existing App flows, identity spoofing, direct-table/RPC restrictions, provider cache/limits, invitation rotation/revocation/blocks, revision conflicts and atomic candidate persistence.
- Hosted smoke: **12 grouped checks passed** with two temporary Auth accounts, a temporary friendship/trip and one bounded authenticated provider lookup. Verified concurrent independent writes, recipient-only acceptance, cross-account reads of the selected real route, completion/undo and stale-write denial.
- Cleanup verified: zero temporary Auth accounts and zero smoke trips remain. Only the test-created records were deleted; no existing user data was deleted. Normal flight-provider cache and global quota accounting remain intact.
- Final simulator suite: **61 passed, zero failed** (57 unit tests and four UI workflows). An initial self-service UI assertion expected text removed by the earlier design change; the ownership caption/test was corrected before the passing follow-up run. These tests do not exercise real Apple account authorization.
- Simulator bundles: `/private/tmp/wif-trip-cloud-tests-v1.xcresult`, `/private/tmp/wif-trip-cloud-tests-v2.xcresult`.
- The final save-in-progress UI guards and installed-App link hint also passed a subsequent Debug simulator build. The exported self-service flight form screenshot was visually inspected.

## Explicit release boundaries

- **No App Store submission or installed production-binary update.** The iOS code needs a new build/TestFlight run, including two real devices signing in with Apple. Hosted smoke uses temporary password-auth accounts solely for API verification; no password login was added to the App.
- **HTTPS Universal Links and rich web/iMessage preview cards are not live.** `WIF_INVITE_BASE_URL` is empty and the current AASA file is a template with `TEAMID`. A user-owned invitation domain, matching Associated Domains configuration and a served AASA/landing page are required. Until configured, links use the existing App URL scheme and require installation. Apple requires this two-way website/App association: https://developer.apple.com/documentation/xcode/supporting-associated-domains.
- No general bearer-link joining or unregistered-user auto-membership was added. A future generic invitation link needs a separately designed owner-approval flow.
- No invitation push notification, durable offline mutation queue, continuous flight-status cron, calendar sharing, Web cutover, old-Web security-policy change, secret rotation, legacy database import or old-project deletion was performed.
- Existing compatibility CRUD endpoints remain available; the new iOS client uses revision-protected `/mutations`. The old Web remains independent and needs its own coordinated authentication/cutover work.
