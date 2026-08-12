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
| POST | `/v1/friends/requests` | `{ username }` | `AppSnapshot` |
| PATCH | `/v1/friends/requests/{id}` | `{ response: accept|decline }` | `AppSnapshot` |
| DELETE | `/v1/friends/{id}` | `{}` | `AppSnapshot` |
| PATCH | `/v1/friends/{id}/favorite` | `{ isFavorite }` | `AppSnapshot` |
| PATCH | `/v1/friends/{id}/preferences` | `FriendAccessPreference` | `AppSnapshot` |
| PATCH | `/v1/sharing` | `SharingPreferences` | `AppSnapshot` |
| PUT | `/v1/presence/current` | `{ city, countryCode, source, clientUpdatedAt }` | `AppSnapshot` |
| PUT | `/v1/devices/push-token` | `{ token, platform: ios }` | empty 2xx |

## Authorization invariant

A friend may appear in `snapshot.friends` only when an accepted, non-blocked relationship exists and the other party has enabled sharing for that relationship. Removing, blocking, globally pausing, signing out or deleting an account must invalidate future reads immediately.

## Same-city event invariant

Create an event only if both presences are active and fresh, both sides still authorize the relevant visibility, and the recipient enabled alerts. Use a unique server-side deduplication key such as `(recipient_user_id, pair_id, normalized_city_id, event_window)` and deliver through an outbox worker so retries cannot create duplicate visible notifications.
