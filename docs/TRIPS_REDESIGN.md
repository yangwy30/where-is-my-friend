# Trips — multi-trip library and Jade routes

Implemented September 5, 2026. Local prototype only; no App Store upload or backend changes.

September 6 update: the shared traveler picker and guest-entry flows described in the historical test results below have been removed. The signed-in account can manage only its own flights; members' flights are read-only, and legacy unbound rows cannot be claimed by name. See [self-service implementation](TRIPS_SELF_SERVICE.md) for current behavior and verification. The older screenshots below are design history, not the current permission model.

## Experience

- Trips opens a library, not a preselected itinerary: Ongoing, Upcoming, and collapsed Past. Multiple overlapping trips are supported.
- Empty state, New trip, per-trip people/flights, editing, completion/undo, and account-isolated on-device persistence.
- Compact trip cards with destination/date lines and separate avatars. Opt-in examples never replace the initial empty state.
- Native geographic map, with airport-coordinate-based geodesic routes rather than an image and screen-space coordinates.
- A single, cancellable route reveal on entry. Selecting a traveler highlights their route, moves the camera, and expands their arrival details. No looping markers implying live aircraft tracking.
- An expanded map supports pan, zoom, rotation, traveler selection, and a Show all routes control.
- Nearby airports share a city annotation in the overall view; selecting a person reveals the actual route endpoints. Destination and origin labels use different placement to avoid SFO/LAX overlap.
- Arrival rows and flight details are one list. Return arrivals use destination time zones and next-day offsets.
- Adaptive Jade surfaces and the existing appearance preference; Reduce Motion skips route-reveal and camera animations.
- Simplified flight-entry sheet. Its presentation carries an immutable traveler/direction request so first presentation cannot lose the preselection.

## Prototype boundaries

The example itineraries, including Coachella, are sample data. They are not live flight boards.

Trips, people, and flight entries persist on the current device, separated by account/environment. Cloud sync, Web trip import, flight lookup, invitations, and notifications are not connected. Unknown routes remain unverified; the app never invents airport coordinates or flight times. The airport directory is intentionally limited to the preview's supported airports. See [database integration plan](TRIPS_DATABASE_PLAN.md) for the additive backend migration and release boundaries.

The map uses Apple's native base map and attribution. Tile loading depends on network availability and cached map data. Routes connect airport endpoints, not actual operational flight paths.

## Verification

Debug build succeeded for iPhone 17 Pro Max, iOS Simulator 26.4.1.

Current multi-trip iteration: 50 tests passed (46 unit tests and four Trips UI tests). Coverage includes empty state, two overlapping trips, creation and relaunch persistence, guests, completion/undo, account isolation, destination-local date boundaries, invalid input, corrupt-file preservation, per-trip flight isolation, map selection/expansion, return routes, and Night Jade.

An additional UI regression passed for editing an existing trip, relaunch persistence, and leaving other trips unchanged: 51 distinct passing tests in total. Edit regression bundle: /private/tmp/wif-multi-trips-edit-tests.xcresult.

Result bundle: /private/tmp/wif-multi-trips-tests-v2.xcresult

Source changes for this iteration:

- WhereIsMyFriend/Features/Trips/TripsView.swift
- WhereIsMyFriend/Features/Trips/TripLibrary.swift — trip model, classification and local archive
- WhereIsMyFriend/Features/Trips/TripPlanningSheets.swift — creation/editing and people
- WhereIsMyFriend/App/AppShellView.swift — plain airplane tab symbol
- WhereIsMyFriendTests/FriendPresenceTests.swift — TripMapTests
- WhereIsMyFriendUITests/PrototypeUITests.swift — Trips interaction and appearance coverage

Earlier migration changes and old image assets have been preserved.

## Previews

Actual simulator captures are in docs/trips-jade-preview:

- overview.png
- board.png
- add-flight.png
- expanded.png
- selected-route.png
- night.png
- map-motion.mp4

Updated multi-trip captures are in docs/multi-trips-preview: library.png, empty.png, new-trip.png, two-upcoming.png, past.png, and board.png. The older Jade preview captures above are retained as design history.

Map implementation reference: [Apple — Meet MapKit for SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10043/).
