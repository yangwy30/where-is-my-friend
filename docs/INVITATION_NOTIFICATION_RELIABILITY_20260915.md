# Invitation notification reliability — September 15, 2026

## Scope and status

Implements the agreed first phase: friend-request pushes, a clearer/retryable device-registration flow, and friend/Trip invitation delivery and navigation verification. No new Tab or unified notification inbox was added. No production migration, function deployment, TestFlight upload, historical push replay, or real-user test invitation was performed by this task.

The preceding read-only diagnostic found no friend-request push trigger; the Trip invitation pipeline existed. The two recent Trip alert records had no delivery records, their recipients currently had no active device registrations, and both invitations were already accepted. Only staging app devices were registered at that diagnostic snapshot. These observations do not establish the recipients' historical iOS permission state or prove that a production phone can now receive APNs.

## Backend

- Migration `20260915030000_friend_invitation_notifications.sql` adds a transactional friend-request outbox and per-device delivery records. New requests only: existing pending requests are not backfilled.
- Pending requests are deduplicated. Decline/re-invite loops have a 10-minute per-pair cooldown while the relationship record remains. Notification eligibility expires after seven days; the existing in-app friend-request lifecycle is unchanged.
- Before each send, validate the recipient, sender, request generation/status, blocks, expiry, account deletion and current device owner. Accepted/declined/replaced requests cannot revive an old delivery. Retries are leased, capped at five attempts and cannot disable a device transferred to another account.
- Private notification previews omit sender names. Friend invitations do not depend on city sharing or same-city/flight alert switches.
- `push-worker` now handles friend requests with `friend-invitations` grouping and a `friend-requests/<request UUID>` deep link. Trip invitation processing keeps its own queue and eligibility checks.
- After successful friend/Trip invite creation, and after successful device registration, the API performs a best-effort authenticated background wake-up of the invitation worker. It does not wait for APNs before acknowledging the user's mutation. Failed wake-ups leave durable records for the existing cron fallback; there is no faster cron or changed flight-query quota.
- Background work uses [Supabase's documented EdgeRuntime.waitUntil mechanism](https://supabase.com/docs/guides/functions/background-tasks). The wake-up has an eight-second timeout, catches failures, and transmits no user identifiers or worker secrets to the client.

## Client

- The previous “Same-city notifications” switch actually changed `notificationPreviewEnabled`. It is now labeled “Show notification previews”; system authorization and device registration remain visible when previews are off. Changing preview privacy no longer requests system authorization implicitly.
- New users/pending-request contexts, Add friends and Trips expose contextual setup status. The user explicitly chooses Enable, Settings or Retry; permissions are not forced.
- Settings distinguishes iOS authorization from account/device registration, including waiting, registered and retryable failure states. Demo mode explicitly says it has no remote delivery.
- Native-token/backend registration waits have a 20-second UI deadline; device-token HTTP writes have a 15-second timeout. Registration is refreshed when returning after five minutes. Late results cannot restore registration state after sign-out/account changes.
- Foreground invitation notifications refresh pending data and are eligible for Notification Center as well as a banner. They do not automatically open a modal without the user's tap.
- A strict friend-request deep link opens the authenticated user's matching incoming request, with Accept / Decline actions. The route survives relaunch and sign-in; an unrelated account sees no private invitation details. Invite review does not require location permission; location setup can follow later.
- Existing pending requests and Trip invitation lists remain the in-app fallback even if system notification delivery is unavailable.

## Verified locally

- **119 unit tests + 3 UI tests passed**, zero failures: `/private/tmp/wif-invitations-verified-20260915.xcresult`.
- UI cases: friend notification route survives relaunch and can be accepted; disabling previews preserves permission/registration controls; Trip invitation route survives relaunch and dismissal.
- **79 backend tests passed**, zero failures: `/private/tmp/wif-invitation-backend-final-20260915.log`.
- Tests include no-device-then-registration delivery, two-user invitation ownership, private previews, duplicate requests, accepted/declined/replaced/expired/blocked requests, lease/retry limits, device transfer, no historical backfill, best-effort wake-up failure and a mocked APNs friend-request delivery using the correct queue/topic/deep link.
- Screenshots were inspected. The final primary-button colors were strengthened for readability; the final UI run includes that change. `git diff --check` passed.

## Release and physical-device acceptance still required

1. Confirm the production migration ledger and back up the current API/worker/schema before applying only the new friend-invitation migration.
2. Deploy the matching API and push-worker, keeping existing authorization and the cron fallback. The new worker requires the new friend RPCs; deploying code without the migration is incomplete.
3. Publish a new client build to the intended App. Older clients do not understand the new friend-request notification route. The app variant and APNs environment must match; a staging app is not inherently a sandbox APNs app.
4. With two explicitly approved test accounts on physical devices, enable notifications on the receiver and confirm device registration. Send a new friend request and a new Trip invitation; test foreground, background and cold launch. Tap, accept/decline, and verify no obsolete invitation is sent again.
5. Repeat after permission denial/re-enable and with a temporary network interruption. Do not use everyday accounts for destructive tests, and do not replay all historical invitations.

APNs success means Apple accepted the request, not proof the person saw it. Physical-device results must be recorded separately from the mocked delivery and simulator tests above.
