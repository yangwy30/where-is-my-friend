# Production API contract

The iOS app includes a complete `RemoteAppRepository`. Set `WIFAPIBaseURL` to an HTTPS origin and launch with `-useRemoteAPI` after these endpoints exist.

## Transport rules

- JSON over HTTPS only.
- Dates use ISO 8601.
- Authenticated requests use `Authorization: Bearer <access-token>`.
- Mutating endpoints return the caller-authorized `AppSnapshot` after the mutation.
- Never return precise coordinates to any friendship endpoint.
- Every friendship and presence read must derive the current user from the verified token, never from a user ID supplied by the client.
- Apply rate limits to authentication, lookup, invitations and presence uploads.

## Endpoints

| Method | Path | Request | Response |
|---|---|---|---|
| POST | `/v1/auth/apple` | `AppleSignInPayload` | `{ accessToken, snapshot }` |
| POST | `/v1/auth/logout` | `{}` | `AppSnapshot` |
| DELETE | `/v1/account` | `{}` | signed-out `AppSnapshot` |
| GET | `/v1/bootstrap` | — | `AppSnapshot` |
| PATCH | `/v1/profile` | `ProfileUpdate` | `AppSnapshot` |
| POST | `/v1/friends/requests` | `{ username }` | `AppSnapshot` |
| PATCH | `/v1/friends/requests/{id}` | `{ response: accept|decline }` | `AppSnapshot` |
| DELETE | `/v1/friends/{id}` | `{}` | `AppSnapshot` |
| PUT | `/v1/users/{id}/block` | `{}` | `AppSnapshot` |
| DELETE | `/v1/users/{id}/block` | `{}` | `AppSnapshot` |
| PATCH | `/v1/friends/{id}/favorite` | `{ isFavorite }` | `AppSnapshot` |
| PATCH | `/v1/friends/{id}/preferences` | `FriendAccessPreference` | `AppSnapshot` |
| PATCH | `/v1/sharing` | `SharingPreferences` | `AppSnapshot` |
| PUT | `/v1/presence/current` | `{ city, countryCode, source, clientUpdatedAt }` | `AppSnapshot` |
| PUT | `/v1/devices/push-token` | `{ token, platform: ios }` | empty 2xx |

`AppleSignInPayload` contains the raw nonce used to create the hashed nonce in the Apple authorization request. The server must require the value and verify the hash against the identity token before creating a session.

`ProfileUpdate` contains `displayName`, `username`, and `avatarPalette`. The server must repeat the client validation, enforce username uniqueness, and return a stable conflict error when a handle is unavailable.

The client persistently coalesces offline presence, sharing-preference and push-token writes per signed-in account. A later write of the same kind replaces the earlier queued value, and retries use exponential backoff. Therefore these write endpoints must be idempotent and accept a repeated payload safely.

Return `401` or `403` for an invalid or revoked session. The client clears the local token, cached friend data and Widget snapshot, then requires authentication again.

## Authorization invariant

A friend may appear in `snapshot.friends` only when an accepted, non-blocked relationship exists and the other party has enabled sharing for that relationship. Removing, blocking, globally pausing, signing out or deleting an account must invalidate future reads immediately.

Blocking must atomically remove the friendship, pending requests, per-friend preferences, active same-city sessions and future presence visibility. `snapshot.blockedPeople` contains only the minimum identity needed to show and reverse the block; it never contains presence.

## Same-city event invariant

Create an event only on entry into a same-city session if both presences are active and fresh, both sides still authorize the relevant visibility, and the recipient enabled alerts. Close the session when either person leaves, becomes stale, pauses sharing, removes the friendship, or blocks the other person. Apply the same six-hour re-entry cooldown as `ColocationEvaluator`. Use a unique server-side deduplication key such as `(recipient_user_id, pair_id, normalized_city_id, session_id)` and deliver through an outbox worker so retries cannot create duplicate visible notifications.
