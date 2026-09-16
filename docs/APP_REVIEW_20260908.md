# App Review 2.1(a) — Apple sign-in investigation

## Report

Submission `34eb7c80-6ccc-49cc-bebb-5856ed283802`, version 1.0 (2), reviewed September 8, 2026 on iPad Air 11-inch (M3), iPadOS 26.6.1. Reviewer reported an error during Sign in with Apple and could not enter the App. No exact error text or screenshot was supplied in this conversation. The iOS 27 beta notice is not the reported rejection issue.

## Verified, not inferred

### Confirmed after user dashboard login

- Apple provider Client IDs contains only `com.yangwy30.whereismyfriend.staging`; the production ID is missing. Apple is enabled and "Allow users without an email" is disabled.
- Hosted Auth log `ad9aa38f-5e1f-4c1e-a0c4-4234f835f795`, September 8 at **10:50:51 UTC / 06:50:51 America/New_York**, reports HTTP 400 for POST `/token`, grant type `id_token`:
  `invalid request: Unacceptable audience in id_token: [com.yangwy30.whereismyfriend]`.
- This confirms a real production Apple token was rejected because its audience was not allowed. It is consistent with the review report on the same date; the log alone does not identify the person making the request. No need to speculate about iPad-specific rendering or a missing OAuth secret to explain this recorded failure.
- Applied after explicit user approval on September 8: retained the staging ID and added `com.yangwy30.whereismyfriend` to the Apple Client IDs list in the Supabase dashboard. Saved successfully and reopened the provider dialog to verify the persisted value `com.yangwy30.whereismyfriend.staging,com.yangwy30.whereismyfriend` with Save disabled. Apple remains enabled; "Allow users without an email" remains disabled. No other fields were edited. Test the existing production build afterward; this server-side mismatch alone does not require a new binary.
- Missing email scope remains a separate first-time-signup risk, not the cause named by this log. Validate after fixing audience configuration; do not declare the whole login flow repaired from the settings change alone.

### Earlier source and API checks

- Release-tag source (`9c666e4`) and current `AuthenticationView.swift:41` request only `.fullName`, not `.email`.
- The native flow hashes a fresh nonce for Apple, then passes the original nonce and identity token to Supabase `signInWithIdToken`. This is followed by the App API bootstrap. Any of these stages can fail; the review message does not identify which one.
- Release bundle ID is `com.yangwy30.whereismyfriend`; staging uses `.staging`. Both configurations point at App Supabase project `cdhpaujazbuppbxyhjxq`.
- Public Auth settings currently report Apple enabled, anonymous login disabled, and signup enabled. This does not expose accepted Apple client IDs or establish their values on the reviewer's attempt.
- Source entitlements include Sign in with Apple. Archive metadata confirms production build 2 was uploaded September 4. The archive's App binary has since been removed, so its shipped entitlements could not be independently inspected.
- Hosted password-auth smoke tests prove the current ordinary session/bootstrap/Trips API chain works, not that native Apple login works.
- The database Auth audit-table aggregate for September 7 onward returned no rows. This is not evidence of no login failures; hosted Auth service logs remain to be inspected.

## Leading checks, not confirmed causes

1. First-time Apple authorization without email scope: request email alongside name and test both Share My Email and Hide My Email after user authorization to implement the fix. Do not assume that an existing developer account reproduces first-time account creation.
2. Supabase Apple accepted client IDs must include the production bundle ID, not just the staging bundle or Web Services ID. Native ID-token audience validation uses this list.
3. Obtain the exact error and timestamp to distinguish Apple framework authorization, Supabase token exchange, and App bootstrap failures. Preserve nonce validation; do not switch to guest access or bypass authentication.

References: [Supabase Apple guide](https://supabase.com/docs/guides/auth/social-login/auth-apple), [ID-token validation source](https://github.com/supabase/auth/blob/master/internal/api/token_oidc.go), [Apple release testing](https://developer.apple.com/documentation/xcode/testing-a-release-build).

## Access / next step

Read-only Management API inspection could not complete without a Keychain authorization; the waiting credential-reader process was stopped. The user subsequently signed into the dashboard and the provider configuration and hosted error above were inspected successfully. No credentials were requested in chat or revealed.

Only the approved Apple client-ID allowlist was changed. No authentication code, App Store reply, upload or submission was changed. Native Apple login has not yet been re-tested after the configuration change. Test the actual Release/TestFlight build on iPhone and iPad, including a previously unused Apple account, returning login, sign-out/relogin and app reinstallation. A saved configuration, simulator build or password-auth smoke test is insufficient to close this rejection.
