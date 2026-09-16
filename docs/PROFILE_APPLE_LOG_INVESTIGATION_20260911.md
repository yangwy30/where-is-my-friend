# Profile save / Apple sign-in log investigation

Investigated September 11, 2026, approximately 22:28–22:35 America/New_York. Read-only production investigation; no user data, authentication settings, deployed functions or client behavior changed in this turn.

## Scope

Queried Management API logs for project `cdhpaujazbuppbxyhjxq`, including Auth outcomes, Edge Function requests, API gateway requests, and grouped database/function errors. Relevant requests/errors were checked across September 8 02:28 UTC through September 12 approximately 02:33 UTC in daily windows. Recent successful Node smoke requests were separated from native App User-Agents. No credentials, tokens, request bodies or users' names/emails were needed in the report.

Downloaded the currently deployed API for inspection to `/private/tmp/wif-incident-api.F0nHmE`; its `databaseStatus` and `authorize` implementations confirm the problematic mappings described below.

## Confirmed: real profile save failed through the gateway

Native App Build 7 (`CFNetwork/3860.700.1`, Darwin 25.6.0):

- Outer PATCH `/functions/v1/api/v1/profile`, request `01a0934a-1f1e-7115-9ea1-bafe476f5537`, returned **400** at **2026-09-12 01:45:10.454 UTC** (September 11 **21:45:10 EDT**), execution time **6,936 ms**.
- In that interval, `/auth/v1/user` returned 200, followed by `/rpc/wif_resolve_app_user` returning 200.
- `/rest/v1/rpc/wif_update_profile`, request `01a0934a-2658-7b01-a837-956fd2d3e650`, began at **01:45:05.297 UTC**, returned **504**, origin time **5,145 ms**.
- The deployed API's database error mapping falls through to HTTP 400 for an upstream gateway timeout. It discards the upstream HTTP status.
- This was the only native profile PATCH in the latest 24-hour query. The two subsequent profile PATCH successes at 01:46:05 UTC were our Node smoke tests, not evidence that this user's save succeeded.

This establishes a real server-side failure, beyond the earlier client concurrency defects. It does **not** prove the write was rolled back or never committed, nor does it prove why the user's spinner remained indefinitely. Gateway timeout and database statement duration measure different stages; the earlier approximately 15 ms database-function maximum could not rule this out.

## Confirmed: upstream Auth timeouts misreported as expired sessions

Two native Build 7 bootstrap failures correlate with gateway Auth timeouts:

| UTC / EDT time | Upstream request | Outer App API result |
| --- | --- | --- |
| Sep 12 00:03 / Sep 11 20:03 | `/auth/v1/user` 504, 5,215 ms; request `01a092ec-b264-7088-92cf-857edcedc474` | Bootstrap 401, 5,617 ms; request `01a092ec-b075-7ea2-936f-19844ba2ceac` |
| Sep 12 00:53 / Sep 11 20:53 | `/auth/v1/user` 504, 5,043 ms; request `01a0931a-7e13-738d-b9c3-4ddd92758d70` | Bootstrap 401, 5,325 ms; request `01a0931a-7ce1-7369-89c6-0731fdf4b3f9` |

Deployed `authorize()` maps **any** `getUser` error to 401 `The session expired.`, including upstream 504. The client interprets 401 as an expired session and refreshes the token. Following refreshes and bootstrap requests in both windows returned 200. These logs show the false expiry problem, not two conclusively permanent login failures.

The newly reported Apple-login user has not yet been matched to either event. A screenshot/time/build was requested. Errors inside Apple's native authorization sheet can occur before any Supabase request and are not recoverable from server logs alone.

## Apple configuration and token exchange

- Current provider enabled; signups not disabled.
- Allowed client IDs contain both `com.yangwy30.whereismyfriend.staging` and `com.yangwy30.whereismyfriend`.
- Six recent ID-token exchanges returned 200, with six corresponding Apple login events. No recent Apple ID-token rejection was found in the inspected windows after the known September 8 incident.
- The September 8 10:50:51 UTC `Unacceptable audience` error is still present in historical logs, consistent with the already-documented earlier allowlist fix. It is not evidence that the current configuration has regressed.
- Native source still requests `.fullName` without `.email`; this remains a separate first-time-login risk to address and test, not a cause demonstrated by these recent logs. See [Supabase native Apple guidance](https://supabase.com/docs/guides/auth/social-login/auth-apple).

## Infrastructure boundary

Recent gateway 504s also affect notification and flight worker RPCs, not only profile saving. They commonly last about five seconds. The previously increased **pg_net scheduler HTTP timeout** is a different layer and does not remove these upstream API gateway failures. The logs do not establish whether the underlying cause is database resource pressure, upstream routing, or another platform condition. Do not claim a plan upgrade, wider timeout or larger database alone will fix it without further evidence.

## Recommended next implementation, not performed in this diagnostic turn

1. Preserve upstream failure classification: temporary Auth/service errors must be 503/504, not invalid-session 401; database transport/timeouts must not become user-input 400.
2. Retry only bounded, safe validation/read operations for transient failures. Do not blindly replay profile writes after a timeout; outcome may be unknown. Reconcile saved state or use a deliberate idempotency policy.
3. Add sanitized structured error logs with stage, request correlation ID, upstream status/code and duration; no JWTs, emails or profile values.
4. Keep the previously implemented client save-specific state/deadline and session-error fixes, then verify the exact 504 scenarios and successful recovery. New client changes still need a release.
5. For sustained gateway failures, collect request IDs/time windows and platform health/metrics before deciding on infrastructure changes or contacting Supabase support.
