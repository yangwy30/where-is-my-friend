# Across Us 1.0.9 (39) — internal TestFlight

For the user to try the new same-city moments screen on a real phone. Not submitted for review.

## What's in it

- **Same-city moments, per friend.** The You tab's Same-city moments screen used to list every alert. It now shows a total ("18 days together, with 4 friends in 6 cities") and one card per friend: days together, the cities you shared, and whether they're with you now. Tapping a friend lists your trips together.
  - Stays less than 6 hours apart are one trip, even across cities, so a road trip reads "Los Angeles to San Francisco, via Santa Barbara".
  - A city names a trip only after 2 hours there together. Trips shorter than 1 hour are left out.
  - The You tab row shows total days together instead of an alert count.
- **One alert per trip.** Arriving together in the next city of a trip no longer sends another same-city alert (on the device and on the server).
- **Test fix:** the same-city chip UI test now follows the card-first flow from 5bef04e.
- Everything in 1.0.9 (38): email-code and Google sign-in, 84 more US city emblems, You tab redesign, setup checklist.

Screenshots: `docs/same-city-moments-20261018/`.

## Production changes made for this build (Supabase cdhpaujazbuppbxyhjxq, with the user's approval)

Migration `20261018010000_same_city_trips` (applied October 18, 2026, before this build):

- `wif_evaluate_direction`: a new stay that starts within 6 hours of leaving another city with the same friend records the stay but creates no alert.
- `wif_snapshot`: each stay now includes `cityName`, and the snapshot carries the latest 300 stays (was 100). Older app versions ignore the new field.

## Tests

All 276 unit tests pass. Same-city UI tests (9) pass on iPhone 17 Pro, iOS 27.0, including the new by-friend and road-trip tests in English, Chinese, light and dark. The full UI suite was not rerun for this build.

## Build

Built from tag `v1.0.9-39` (dc5eea8) on `feature/email-google-sign-in`. Signed the same way as 1.0.9 (38): Apple Distribution, `aps-environment` production, `applinks:acrossus.app`, `get-task-allow` false. Uploaded October 19, 2026, 19:45 PDT.
