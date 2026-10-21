# Across Us 1.0.9 (42) — internal TestFlight

For the user to try the boarding pass on their iPhone Air. Not submitted for review.

## What's new since 1.0.9 (41)

- **Opening a traveler shows a boarding pass** instead of the vertical timeline.
  - **Out and Back** are two tabs above the pass that show each leg's date; switching flips the pass.
  - The pass reads left to right: the flight name and status on top, then each airport code with its local time, time zone and a "+1" for next-day landings, and the duration on the route between them.
  - The **stub names the terminal and its airport**, for example "Lands at Kauai · Terminal 1" or "Leaves from New York · Terminal 7". Flights now keep the departure and arrival terminal separately. Flights cached on the phone before this build keep the old unlabeled terminal until they sync again.
  - Every pass uses the app's jade; a traveler's own color stays on their avatar.
  - **Edit and Delete** for your own flight moved into the ··· menu on your row.
- No baggage-belt field: the provider usually publishes it only on the day of travel, often after landing.

Screenshots: `docs/trip-globe-20261019/pass-v2/`.

## Production changes

None for this build.

## Tests

All 277 unit tests pass. Trip UI tests pass on iPhone 17 Pro, iOS 27.0, including the globe walkthrough at standard and XXL text sizes and the edit/delete flow through the new menu. The full UI suite was not rerun.

## Build

Built from tag `v1.0.9-42` (70b7a17) on `feature/email-google-sign-in`. Signed the same way as 1.0.9 (41): Apple Distribution, `aps-environment` production, `applinks:acrossus.app`, `get-task-allow` false. Uploaded October 20, 2026, 19:22 PDT.
