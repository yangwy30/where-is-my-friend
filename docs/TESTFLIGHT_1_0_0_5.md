# Across Us 1.0.0 (5) — TestFlight handoff

## Build scope

- Production App: `com.yangwy30.whereismyfriend`, App Store Connect ID `6807634842`, team `93RUQ2A6KX`.
- Release configuration, version `1.0.0`, build `5` for both app and widget (`CURRENT_PROJECT_VERSION = 5`). Local demo disabled. Existing App Supabase project.
- Domain-free TestFlight entitlement file (`WhereIsMyFriendTestFlight.entitlements`): Apple sign-in, App Group (`group.com.yangwy30.whereismyfriend`), and APNs (`aps-environment=production`).
- **Trips Feature & UI Decluttering**:
  1. **Removed Meeting Points**: Completely removed `TripMeetingPointRow` and modal editor sheet from Trips board and empty state.
  2. **Removed Check-in & Personal Status Updating**: Removed `tripMyCheckInButton` dropdown menu, "Your arrival status" block, and horizontal check-in status pills (`activeCheckIns`).
  3. **Eliminated Route & Airport Code Redundancy**: Collapsed summary row displays traveler name, flight number (`DL 365`), status, and arrival time. Airport route endpoints (`JFK 16:40 → SFO 19:13`) appear only once in the expanded flight details card.
  4. **Eliminated Alarmist Warnings on Upcoming Flights**: Fixed `isStatusStale` so future flights (>24h away) are never flagged as stale (`Last known status · updates delayed` removed).
  5. **Eliminated Backend Polling / Cron Essays**: Replaced the 24-hour cron polling disclaimer and defensive "periodic updates, not live tracking" text with a clean, standard timestamp (`Updated [Time]`).
  6. **Purged `People` Sheet Boilerplate**: Removed legalistic permission warning card (*"Everyone manages their own flights..."*) and link expiration / app requirement essays. Pending invitations section is only shown when active outgoing invites exist.
  7. **Cleaned Read-Only Banner**: Replaced bureaucratic account link warning with a concise `Read-only trip` badge.

## Verification & Test Suite

- **Unit tests (`WhereIsMyFriendTests`)**: 35/35 passed (0 failures).
- **UI tests (`WhereIsMyFriendUITests/PrototypeUITests`)**: 13/13 passed (0 failures).
  - Validated flight card expansion and detail toggling (`testTripFlightCardDetailsExpansion`).
  - Validated trip creation, persistence, People sheet without disclaimers, and trip completion (`testTripCreationPersistencePeopleAndCompletion`).
  - Validated unverified flight entry, missing traveler alerts, verified flight lookup, and theme appearance.

## Current status

- Uploaded successfully on **September 11, 2026 at 00:28:44 EDT** (`2026-09-11T04:28:44Z`); Xcode returned `EXPORT SUCCEEDED`.
- Apple Delivery UUID: `51be1794-40e3-4e6f-857c-9867c31c64ee`.
- Apple upload state: `PROCESSING` with no errors (transferred 105,951,242 bytes in 41.318s).
- Final archive: `/private/tmp/AcrossUs-1.0.0-5.xcarchive`.
- Re-signed for App Store distribution with automatic signing, team `93RUQ2A6KX`.
- Distribution logs: `/var/folders/z5/mwjh39j95h1dsxqs1m0c8f3r0000gn/T/WhereIsMyFriend_2026-09-11_00-26-27.621.xcdistributionlogs/ContentDelivery.log`.
