# App bug and UX audit — September 23, 2026

## Fixed: Trip state after account switching (P1)

`TripLibrary.load` changed the account generation but left `isRefreshing` and `isSaving` set while an old account request was pending. The new account's first Trip refresh or save could be skipped. When the old request finally returned, its unconditional cleanup could also clear a newer request's loading state. A delayed invitation-decline error could appear on the new account.

Loading another account now resets those flags and assigns each refresh/save an operation ID, so only that operation can clear its flag. Late invitation results are ignored after an account change. Three race regressions cover delayed old reads, old saves, and invitation failures. The iOS 27 simulator passed all 154 unit tests. This change is in source only; it is not part of App Store review build 1.0.4 (18).

## Next: city picker first screen (P1 UX)

`TravelCityPicker` still uses default SwiftUI search placement, which appears at the bottom in the reported iOS 27 screen. On first open it shows only an instruction row, leaving the main area largely empty. The previously reviewed mock with search near the title and conditional rows from the user's own places/Trips has not been implemented. A focused next change should use an explicit navigation-bar search placement, remove the nested navigation stack in push navigation, and show real account-derived rows only when available. Do not add generic “Suggested” cities. [Apple's search placement API](https://developer.apple.com/documentation/swiftui/searchfieldplacement/navigationbardrawer) provides the top navigation-bar placement and an always-visible mode.

## Next: explicit Trip refresh failure (P2 UX)

`TripLibrary.refresh` keeps cached trips when a request fails and sets `syncFailed`, but `TripsView` never reads that state. This protects the cached data, but after a user pulls to refresh the screen can look unchanged with no indication that the request failed. Keep automatic refresh quiet as requested; show a small, retryable message only after an explicit pull fails. Do not add persistent sync banners or expose implementation details.
