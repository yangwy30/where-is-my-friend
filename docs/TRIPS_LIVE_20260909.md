# Trips flight updates and meeting coordination — September 9, 2026 (New York)

Subsequent release update: [build 1.0.0 (3) was uploaded and made available for internal TestFlight testing on September 10](TESTFLIGHT_1_0_0_3.md). The original delivery boundaries below describe September 9; physical-device acceptance remains pending.

## Delivered

- Compact expandable meeting card using the existing Jade theme. Only the owner edits/removes the shared meeting point, with revision checks. Each signed-in traveler can update/clear only their own check-in: landed, bags collected, or at the meeting point. Check-ins are explicitly self-reported; airline updates never change them.
- Per-trip, per-member flight alert preference, **off by default**, persisted only after server acknowledgement. Enabling requests iOS notification permission. Recipients must remain active members with an active device and no block relationship with the traveler. Existing notification-preview privacy is respected.
- Background refresh of verified, selected flight routes near departure. A separate worker queues significant arrival delay (30+ minutes), cancellation, and landing events; delivers only opted-in friends' alerts, not the traveler's own flight. Tapping an alert routes to the account's accessible trip.
- Arrival summary with unique traveler counts and the next fresh expected arrival in destination-airport time. Stale/quota/provider errors show last-known information rather than invented live status. AeroDataBox UTC timestamps, empty time objects, predictions and midnight crossings are handled.

## Limits and semantics

- Cron dispatches every five minutes and claims at most one eligible unique flight number/date per run. The same flight is eligible again after 30 minutes. This is **limited periodic checking, not continuous live tracking**.
- Hard background cap: **20 lookups per UTC day**, within the existing combined **50/day** cap. Manual searches still use their existing per-user quota/cache. Reservations count conservatively even if provider requests fail. Capacity can be exhausted before all flights are refreshed; scale or upgrade the provider plan before promising faster coverage.
- Tracking starts within 24 hours of scheduled departure; bounded by departure age (48 hours) and arrival window (6 hours). Completed trips, unverified selections and already terminal flights are excluded. Long disruptions outside these bounds may need manual verification.
- Selected candidate IDs must match exactly; disappearing legs keep prior data and show an error. Provider refreshes do not invalidate the resource revision for personal flight edits.
- One event per flight/selected candidate/kind; the first selected lookup is a baseline, not a notification. Opt-in is not retroactive. Pending events expire after two hours; each delivery has bounded retries and access is rechecked immediately before APNs. Already delivered notifications cannot be recalled. APNs acceptance/transport cannot guarantee device presentation or exactly-once delivery.
- Coordination refreshes on opening/foreground/pull-to-refresh and every minute while active, not Supabase Realtime. Personal check-in is trip-level, not per flight leg, and can be manually cleared.

## Hosted deployment

App project: `cdhpaujazbuppbxyhjxq`. Release and Staging currently share it.

- Applied only `20260909010000_trip_live_updates.sql` atomically with its ledger entry after a private backup. Did not deploy unrelated `20260901220000_transition_based_colocation.sql`.
- API **v15**, ACTIVE, JWT verification enabled; source hash `700f44576ca1f6a14d6ac0c7c548cc871d491922dfd0df0afdab163309ffbe01`.
- New `trip-worker` **v1**, ACTIVE; source hash `05bc37e9fc4830aa5d274f46cdd65f3e3a0e85e3a73653502159d3281d8613f3`. Uses the existing server-only flight and APNs credentials. Public keys receive HTTP 401; a private worker bearer is required.
- After explicit user approval, enabled `wif-trip-worker-every-five-minutes` (job ID 2) using existing encrypted Vault credentials. Worker probe request 22883 returned HTTP 200: refresh idle, zero claimed/delivered pushes. No provider request or real-device notification was sent by this probe.
- Original `push-worker` remains **v5**, hash `f4c127513506f333473e0543323e1ac761c6bac0a1493db541e56f046dcf8518`. The original 21 non-Trips database functions and ACLs are unchanged. Apple login configuration was not changed.
- Pause only the new job if needed: `select cron.unschedule('wif-trip-worker-every-five-minutes');`. Do not remove the separate existing friend-notification cron.

Private pre-deploy snapshot: `.migration-backups/app-predeploy-G66dcS/`, exported `2026-09-10T00:29:52.607278+00:00`, SHA-256 `45ad34fede27a5d93b18bad625ca6810ff8330e5be97f151bc99a1ba499d9fc5`. Contains private public-schema data, excludes Auth/Storage/secrets, and is not a full disaster-recovery backup. Do not publish it.

## Verification

- Full backend suite: **42 passed, zero failures**. Includes quotas/leases, route selection, failure preservation, threshold/dedup, opt-out, blocks, member removal, device account reassignment, expired delivery and public-worker denial.
- iOS: **59 unit tests and 3 UI workflows passed** on iPhone 17 Pro Max simulator (iOS 26.4.1): meeting/edit/self-check-in/clear, existing own-flight add/edit/delete with ownership enforcement, and overview/map/direction/details interactions. Initial new UI test used TextView instead of the actual TextField accessibility type; corrected selector and passing rerun. Screenshot visually inspected.
- Hosted test: **8 grouped checks passed** using two temporary password-auth accounts (no password login added to the App), no real devices or provider requests. Verified authenticated invitation acceptance, default-off isolated preferences, owner-only meeting revision conflicts, own-only check-in with identity-injection rejection, cross-account reads and clearing.
- Exact temporary trip and both temporary accounts were deleted; read-only verification found zero remaining smoke accounts/trips. Existing user data was preserved.
- Evidence: `/private/tmp/wif-trip-live-tests-v1.xcresult` (unit results), `/private/tmp/wif-trip-live-tests-v2.xcresult` (new UI passing rerun), `/private/tmp/wif-trip-live-regression.xcresult` (two existing-flow UI tests passed).

## Not shipped / remaining validation

- No TestFlight upload, App Store resubmission or update to the installed 1.0 (2) binary. These screens require a **new iOS build**. Real Apple sign-in and real APNs end-to-end delivery still need testing on physical devices; an idle worker probe is not that test.
- User has no domain yet. No domain purchase or binding was done. Existing account-bound App invitations and installed-App custom links remain; HTTPS Universal Links, install landing page and rich iMessage/web previews are **not live**.
- No old-Web database import/cutover, automatic self-check-in, invitation push, or calendar sharing was added.
