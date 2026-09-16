# City refresh and identity repair — September 13, 2026

## Scope

Implements the requested automatic-refresh and unsafe-alias fixes only. No Silicon Valley / metropolitan grouping, database migration, deployment, build-number change, or TestFlight upload.

## Client behavior

- A signed-in live account with city sharing on and no manual-city override refreshes location on foreground entry. Cloud snapshot refresh does not gate the location request.
- Foreground uses city-level Core Location updates (3 km desired accuracy, 5 km distance filter), plus a throttled one-shot freshness check every 5 minutes. The timer runs only while active; it is not a background polling loop.
- Background visit/significant-change monitoring requires the user's existing background preference and Always authorization. Restoring the preference does not itself ask for Always permission. iOS controls background delivery; immediate detection after a move is not guaranteed.
- A manual selected city disables automatic replacement. Explicitly requesting current location resumes GPS-based presence after success. Paused sharing prevents automatic uploads; deferred updates recheck policy and account identity before upload.
- Samples older than 2 minutes, over 30 seconds in the future, invalid coordinates, negative accuracy, accuracy worse than 10 km, and duplicate/out-of-order observations are rejected. Approximate location is still supported; results may remain unavailable if the system can only supply a much broader region.
- Visit events request a fresh fix instead of publishing historical visit arrival coordinates. Reverse geocoding never falls back to a street/building name.
- Geocode generations reject late/cancelled completions. Account switches and revoked automatic eligibility invalidate outstanding work. Location resolution has a 20-second deadline.
- A same-city observation still carries a new observation timestamp. The timestamp survives AppStore deferral, repository upload, and offline queueing via the existing `clientUpdatedAt` API field; upload time does not make an old fix look fresh.

## Geographic identity and artwork

- Artwork aliases match complete normalized names, not substrings. Santa Clara no longer matches `la` / Los Angeles. Known country codes must agree with the curated artwork's country.
- Artwork aliases cannot establish geographic co-location. Shinjuku may use Tokyo artwork but is not automatically treated as Tokyo by `CityIdentity.matches`.
- City identity continues to normalize case, whitespace, accents and comma suffixes. No new region equivalences or municipality merges are introduced. Unknown cities retain their own name and use a generic emblem.

## Verification

- Debug build and **94 unit tests passed**, zero failures: `/private/tmp/wif-location-final-20260913.xcresult`.
- **3 UI tests passed**, zero failures: first-use location allow, first-use location decline/skip, and hiding match cards when sharing stops. Results: `/private/tmp/wif-location-ui-20260913.xcresult`.
- Device: iPhone 17 Pro Max simulator, iOS 26.4.1. `git diff --check` passed.

Automated coverage includes sample freshness/accuracy, repeat-city timestamps, manual override, deferred manual precedence, wrong-account rejection, exact/country-aware artwork aliases, foreground refresh throttling, background consent, resolution timeout, and deliberately out-of-order geocoder completions.

Real-device follow-up remains necessary: cross a city boundary with the App active; reopen after travel; test approximate location, manual override and paused sharing; separately test opted-in Always background delivery. Simulator tests cannot establish iOS background-delivery timing or geocoder accuracy for a real journey.
