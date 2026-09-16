# Flight entry date anchor — September 15, 2026

- New flight entry uses the selected Trip's `startDay`, not the day the form is opened. For an October 12–16 trip, the default departure date is October 12.
- The rule applies to new flight forms in either direction; no unrequested automatic return-date rule was added.
- Users can still choose another departure day, including outside the trip range. Editing an existing flight preserves its saved date, even if trip dates have changed.
- The existing date-picker binding supplies the lookup request and save action, so both use the selected trip-based default. `TripDay.pickerDate` retains calendar-day semantics.
- Verification: 109 unit tests and the add/edit/delete unverified-flight UI flow passed, zero failures. Results: `/private/tmp/wif-trip-date-anchor-20260915.xcresult`.
- Client-only change; no database/API changes. Not included in the already uploaded production TestFlight **1.0.2 (10)**. No new build was uploaded in this task.
