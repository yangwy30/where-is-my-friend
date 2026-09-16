# Profile investigation and Trip invitation push — 2026-09-11

## Profile findings and changes

The earlier UI deadline is a safety net, not proof of the reported incident's root cause. The affected user's build, timing and network trace are still unavailable.

- Reproduced a deeper client race: a bootstrap refresh begun during a profile PATCH can return the old profile first, advance the applied-operation sequence, and cause the successful PATCH snapshot to be discarded. The new regression test failed with both old name and old username before the fix. `AppStore.refresh()` now skips refreshes while a profile save is in flight; older operations remain protected by the existing sequence check.
- Authentication previously classified all session-fetch failures as missing authentication. The retry path also signed users out for any error after token refresh, including username conflicts and temporary network errors. These now retain their actual error and preserve the session; only confirmed invalid sessions trigger that sign-out path.
- Existing save-specific activity/error state and bounded request deadline remain. They prevent indefinite UI activity but do not establish why the original user's request stalled.
- Hosted read-only inspection found no lock waiters. An isolated temporary account successfully saved name and username, including concurrent bootstrap/travel reads and a refreshed access token. Observed PATCH durations were approximately 463–496 ms. Persisted values were confirmed and the temporary account was removed. This is a sampled check, not proof that every production request is healthy.

## Trip invitation delivery

- New invitations create a transactional outbox event. No historical invitations are backfilled.
- Each eligible registered device gets a leased, retry-bounded delivery. Repeated active invitations deduplicate; re-inviting after revocation/expiry rotates the invitation ID.
- Recipient, device ownership, trip status, blocks, expiry and pending invitation state are rechecked immediately before sending. Revocation prevents subsequent sends; an APNs notification already accepted cannot be recalled.
- APNs payload honors notification-preview preference and opens the existing account-bound `://trips/join/<invitation UUID>` route. Opening does not automatically join: the intended recipient still accepts in the App.
- Invitations remain visible inside Trips without notification permission. A new client hint offers Enable/Settings; it does not silently change OS permissions.
- The existing one-minute push schedule sends these invitations alongside existing queues. This is asynchronous delivery, not a guarantee of instant notification. Users must have allowed notifications and have a valid registered device.

## Deployed scope and verification

Applied migration `20260912010000_trip_invitation_notifications` and deployed only `push-worker` to project `cdhpaujazbuppbxyhjxq`. Deployment backup: `.migration-backups/invite-push-EuCpeU`. No APNs credentials were changed.

The push cron request relied on pg_net's default 5-second timeout; recent responses included timeouts. Updated only that existing job's HTTP timeout to 120 seconds, preserving its one-minute schedule and Vault credential references. Backup: `.migration-backups/push-schedule-5pFlZy/previous-command.sql`. The SQL scheduling snippet was updated to match. The flight worker's separate schedule was unchanged.

- Profile race regression failed before the fix: `/private/tmp/wif-profile-race-before.xcresult`.
- Client verification: 20 unit tests and 2 UI tests passed, including profile editing, retry/session preservation and invitation deep-link relaunch/dismissal. Result: `/private/tmp/wif-profile-race-after.xcresult`.
- Backend verification: all 56 tests passed; includes real local SQL invitation rules and mocked-APNs worker routing. Log: `/private/tmp/wif-invitation-final-tests.log`.
- Hosted invitation smoke: 6 checks passed with two temporary accounts. Covers deduplication, inbox without device registration, rollback-only per-device payload/revocation validation, link rotation and intended-recipient acceptance. Report: `.migration-backups/invite-smoke-hnqIkC/report.json`. All temporary accounts and the exact test trip were removed. The fake device transaction was rolled back so the scheduled worker could never send to it.
- An earlier smoke attempt returned an unexpected HTTP 400 at the wrong-account acceptance check; its cleanup succeeded. No speculative server change was made; the subsequent complete run passed. Earlier report: `.migration-backups/invite-smoke-DqUW3k/report.json`.
- Protected signing-only probe returned HTTP 200 with `signingReady: true` (request 26441), without claiming or sending notifications.
- Scheduled deployed push responses at 02:03–02:07 UTC on September 12 returned HTTP 200, no timeout, and `invitationError: false`. These verify worker execution, not physical receipt of a Trip invitation.
- Separate flight-worker responses included earlier HTTP 500s; its 02:05 UTC response was HTTP 200. No claim of historical/reliable flight-worker health is made by this change.

## Release and acceptance boundaries

No TestFlight upload or App Store submission was performed. Profile fixes and the new permission hint require a new client build. Existing clients with the compatible invitation route and working production notification registration can use the server-side invitation delivery.

Physical-device acceptance remains: invite a real consenting test recipient, verify lock-screen notification and correct trip after tapping, test signed-out/account-switch handling, then revoke before a scheduled send and verify suppression. Do not equate APNs acceptance or a successful queue response with a notification seen on a phone. The previously observed sandbox APNs environment mismatch was not changed by this work; use the production APNs environment of TestFlight for release acceptance.
