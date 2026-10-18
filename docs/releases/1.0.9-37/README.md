# Across Us 1.0.9 (37) — internal TestFlight

For the user to see the new setup checklist on a real phone. Not submitted for review.

## What's in it

- **Finish setting up**, at the top of You. One card lists what Across Us needs from iOS: location set to Always, and notifications.
  - Each item has a "Turn on" button. It shows the system prompt if iOS hasn't asked yet, and otherwise opens the matching Settings page. For location it first turns on background updates, so iOS will offer Always.
  - The header shows progress ("1 of 2 on"), and finished items show a check mark. The card disappears once everything is on.
  - The × hides it for the rest of that calendar day, per account. It comes back the next day until everything is on.
  - It shows for real accounts only, not demo data, like the home reminders. Chinese copy is included.
- **Friends header spacing.** The gap under the same-city capsule shrank from about 48 pt to about 30 pt. The capsule's 44 pt tap area is unchanged; it now overlaps the gap instead of adding to it.
- The home location reminder is unchanged. A version written for the moment a friend is in town was mocked up and dropped.

Mock captures are in [docs/mocks/1.0.9-permissions](../../mocks/1.0.9-permissions/).

## Tests

All 267 unit tests passed, including a new test for the daily close rule. 18 UI tests covering Friends, the same-city capsule, location reminders, notifications and You also passed, including a new Chinese test that closes the checklist and checks it stays closed after a relaunch.

## Build

Built from tag `v1.0.9-37` on `ui/1.0.9-permissions` (branched from `main` at 33758e3, after the 1.0.8 release). Signed the same way as 1.0.8 (36): Apple Distribution, `aps-environment` production, `applinks:acrossus.app`, `get-task-allow` false. Uploaded October 17, 2026.
