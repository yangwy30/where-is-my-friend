# Across Us 1.0.9 (40) — internal TestFlight

For the user to try the redesigned trip screen on a real phone. Not submitted for review.

## What's new since 1.0.9 (39)

- **Trip screen on a dotted globe.** A trip opens on a globe drawn as dots, with the destination's city emblem where everyone meets. Each route draws in, a plane flies it and lands, and that traveler joins the others on the emblem. After that, only a faint glint moves along the routes.
  - **Arrive / Depart** at the top switches between flights in and flights home; Depart plays the scene outward.
  - A **landing-day strip** shows when each person gets in (or leaves), in the destination's time.
  - The **arrivals board** has one aligned line per person: who, from, flight, landing time, and the date of their other leg. Tapping a row or a plane opens both legs, with edit and delete for your own flight; people without a flight get Add or Remind.
  - Replaces the Outbound/Return picker, the per-flight cards and the Apple Maps route map.
- **Hawaii emblems.** Kauai, Līhuʻe, Maui, Kona, Hilo and Oahu now show the Hawaii island emblem instead of the generic city.
- **Same-city moments.** Stays in the same city less than 7 days apart now read as one period, and its day count only includes days you were actually together.

Screenshots: `docs/trip-globe-20261019/`.

## Production changes

None for this build. The same-city migration `20261018010000_same_city_trips` was applied before 1.0.9 (39).

## Tests

All 277 unit tests pass. Trip UI tests (15) and same-city UI tests pass on iPhone 17 Pro, iOS 27.0. The full UI suite was not rerun for this build.

## Build

Built from tag `v1.0.9-40` (d3bd0ff) on `feature/email-google-sign-in`. Signed the same way as 1.0.9 (39): Apple Distribution, `aps-environment` production, `applinks:acrossus.app`, `get-task-allow` false. Uploaded October 19, 2026, 21:56 PDT.
