# Production API contract

The iOS app includes a complete `RemoteAppRepository`. The first implementation lives in `supabase/functions/api/index.ts`, backed by the versioned migration in `supabase/migrations/`. Set `WIFAPIBaseURL` to an HTTPS origin and launch with `-useRemoteAPI` for a hosted environment. Debug additionally permits the explicit localhost URL documented in `LOCAL_BACKEND.md`.

## Transport rules

- JSON over HTTPS only.
- Dates use ISO 8601.
- Authenticated requests send the public `apikey` plus `Authorization: Bearer <Supabase-user-JWT>`.
- Mutating endpoints return the caller-authorized `AppSnapshot` after the mutation.
- Never return precise coordinates to any friendship endpoint.
- Every friendship and presence read must derive the current user from the verified token, never from a user ID supplied by the client.
- Apply rate limits to authentication, lookup, invitations and presence uploads.

## Endpoints

| Method | Path | Request | Response |
|---|---|---|---|
| POST | `/v1/auth/bootstrap` | `{ displayName? }` | `AppSnapshot` |
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
| PUT | `/v1/devices/push-token` | `{ token, platform: ios, environment, installationID }` | empty 2xx |
| DELETE | `/v1/devices/push-token` | `{ platform: ios, environment, installationID }` | empty 2xx |

Native Apple sign-in is handled by Supabase Auth before this API is called. The iOS client sends Apple's identity token and the original nonce to `signInWithIdToken`; only the resulting Supabase user JWT reaches this API. `/v1/auth/bootstrap` validates that JWT, derives `auth.users.id`, and idempotently creates or restores the app profile. The deployed API contains no Debug authentication endpoint.

`ProfileUpdate` contains `displayName`, `username`, and `avatarPalette`. The server must repeat the client validation, enforce username uniqueness, and return a stable conflict error when a handle is unavailable.

The client persistently coalesces offline presence, sharing-preference and push-token writes per signed-in account. A later write of the same kind replaces the earlier queued value, and retries use exponential backoff. Therefore these write endpoints must be idempotent and accept a repeated payload safely.

APNs device tokens are opaque, variable-length byte sequences represented as an even-length hexadecimal string; no fixed token length is assumed. The Edge API normalizes and hashes each token, encrypts it with AES-256-GCM using the `APNS_DEVICE_TOKEN_KEY` Edge secret, and only then calls the database registration RPC. Postgres stores the hash plus a versioned ciphertext envelope; it never receives plaintext. `installationID` is a random, non-secret UUID persisted per app installation so signing out disables only that installation, while another authenticated account registering the same installation atomically replaces its previous owner.

Return `401` or `403` for an invalid or revoked session. The client first asks Supabase Auth to refresh the Keychain-backed session; if refresh fails it clears cached friend data and the Widget snapshot, then requires authentication again.

## Authorization invariant

A friend may appear in `snapshot.friends` only when an accepted, non-blocked relationship exists and the other party has enabled sharing for that relationship. Removing, blocking, globally pausing, signing out or deleting an account must invalidate future reads immediately.

Blocking must atomically remove the friendship, pending requests, per-friend preferences, active same-city sessions and future presence visibility. `snapshot.blockedPeople` contains only the minimum identity needed to show and reverse the block; it never contains presence.

## Same-city event invariant

Create an event only on entry into a same-city session if both presences are active and fresh, both sides still authorize the relevant visibility, and the recipient enabled alerts. Close the session when either person leaves, becomes stale, pauses sharing, removes the friendship, or blocks the other person. Apply the same six-hour re-entry cooldown as `ColocationEvaluator`. Use a unique server-side deduplication key such as `(recipient_user_id, pair_id, normalized_city_id, session_id)` and deliver through an outbox worker so retries cannot create duplicate visible notifications.
