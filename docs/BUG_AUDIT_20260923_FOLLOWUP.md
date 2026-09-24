# App bug and UX audit — September 23, 2026

## Fixed: Trip state after account switching (P1)

`TripLibrary.load` changed the account generation but left `isRefreshing` and `isSaving` set while an old account request was pending. The new account's first Trip refresh or save could be skipped. When the old request finally returned, its unconditional cleanup could also clear a newer request's loading state. A delayed invitation-decline error could appear on the new account.

Loading another account now resets those flags and assigns each refresh/save an operation ID, so only that operation can clear its flag. Late invitation results are ignored after an account change. Three race regressions cover delayed old reads, old saves, and invitation failures.

## Fixed: ended Trips offered for a personal plan (P2)

The “Use dates from a Trip” picker previously listed every Trip, including completed, cancelled, and past ones. A user could choose an expired date range, then encounter a server rejection only after filling the city and saving the personal plan. The picker now lists only ongoing and upcoming Trips, distinguishes loading from an empty result, and ignores a response if the account changes while it is open. The Debug iOS Simulator build passed after this view change.

## Implemented: city picker first screen (P1 UX)

The picker now uses [Apple's always-visible navigation-bar search placement](https://developer.apple.com/documentation/swiftui/searchfieldplacement/navigationbardrawer), so the field sits below the title rather than at the bottom on iOS 27. Push navigation has one Back button; sheet callers retain Cancel. The first screen shows up to three account-scoped recent/saved cities and up to two distinct destinations from the user's ongoing/upcoming Trips. A Trip shortcut starts a city search so the person confirms the region before saving; airport data alone cannot identify the administrative area. There are no generic “Suggested” cities. Demo cities appear only when no personal content is available. Recent selections are stored per account on-device and removed with account-local data.

## Implemented: explicit Trip refresh failure (P2 UX)

`TripLibrary.refresh` still keeps cached trips on request failure, but now reports whether an attempted refresh succeeded. Only an explicit pull that fails shows a small inline retry action in `TripsView`; automatic refresh remains quiet. A later successful refresh clears that message.

## Validation and release boundary

The iOS 27 simulator passed 155/155 unit tests. Six distinct city/plan UI workflows passed, including top search placement, manual city choice, Chinese plan opt-out, MapKit search from Profile, and plan-overlap creation and revocation. The final picker workflows passed again after visual refinement. The city picker screenshot was inspected for search placement, duplicate rows and navigation chrome. Debug simulator build passed. These changes are in source only and are not in App Store review build 1.0.4 (18).
