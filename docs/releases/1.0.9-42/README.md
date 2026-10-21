# Across Us 1.0.9 (42) — submitted for App Review

First tried on internal TestFlight, then submitted for App Review on October 20, 2026, at 20:30 PDT. Release type: automatically after approval.

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

## App Store submission

- Version 1.0.9 with build 42 attached, now Waiting for Review.
- The listing text (promotional text, description, What's New in en-US and zh-Hans) and screenshots come from `docs/app_store_screenshots/2026-10-20/`. Six screenshots per language at 6.3" (1206×2622) and 6.5" (1284×2778).
- Two en-US 6.3" screenshots stuck at "upload complete" and never processed. Re-uploading `05-moments.png` with the same bytes stuck again; a lossless re-encode (same pixels) went through.
- Review notes: `review-notes.txt`. Changed from 1.0.8 to mention Google and email sign-in, the trip globe and boarding pass, and a "New in 1.0.9" summary. Kept under the 4,000-character limit (3,967).
