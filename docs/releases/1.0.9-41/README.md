# Across Us 1.0.9 (41) — internal TestFlight

For the user to check the reworked trip screen on their iPhone Air. Not submitted for review.

## What's new since 1.0.9 (40)

Fixes from the user's review of build 40 on device:

- **The whole globe shows on first open.** It is drawn complete below the navigation buttons, so the dotted continents and everyone's routes read without scrolling. Before, only a sliver of its edge showed, mostly empty Pacific.
- **Board rows use one type style.** Each traveler is two lines: name and landing time, then the far airport with the flight number and the date of their other leg. The column headers are gone, and nothing wraps or clips at larger text sizes (the landing time used to break as "15:4 / 6").
- **Opening a traveler shows their whole trip as one timeline.** A line grows out of their avatar: departure, the flight (airline, number, duration, terminal), arrival, a dotted stay such as "5 nights in Kauai", then the flight home. The leg for the direction on screen is jade and the other is grey; status is shown only when it needs attention. Edit and Delete sit under your own trip. This replaces the boxed ticket.

Screenshots: `docs/trip-globe-20261019/v3/`.

## Production changes

None for this build.

## Tests

Trip UI tests pass on iPhone 17 Pro, iOS 27.0, including the globe walkthrough at standard and XXL text sizes. Unit tests were last run on 1.0.9 (40) (277 passing); this build changed only trip UI code and tests. The full UI suite was not rerun.

## Build

Built from tag `v1.0.9-41` (4c32306) on `feature/email-google-sign-in`. Signed the same way as 1.0.9 (40): Apple Distribution, `aps-environment` production, `applinks:acrossus.app`, `get-task-allow` false. Uploaded October 20, 2026, 18:06 PDT.
