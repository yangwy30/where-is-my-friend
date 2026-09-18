# iOS 27 UI adaptation — September 18, 2026

## Scope

Adapt Across Us to the iOS 27 design direction while retaining Solar Jade / Night Jade, city illustrations, and the existing product flows. This is a UI update; it does not change trip permissions, location matching, notifications, or backend contracts.

## Changes

- On iOS 27, Trip details pin Add flight to the trailing toolbar position. Trip options get high visibility priority. The navigation bar uses system background behavior and stays expanded so actions remain reachable throughout a long arrivals board.
- Trip creation and flight forms use the native prominent glass button style on iOS 27, with existing validation and accessibility identifiers preserved.
- Friends, friend detail, same-city moments, and settings use stable content surfaces on iOS 27. Glass remains on floating controls. Increased Contrast strengthens card outlines; Reduce Transparency gives custom glass surfaces an opaque fallback.
- Friends grids adapt to available width and use one column for accessibility text sizes. The own-city card and section heading stack at large text sizes, and friend name/location/update labels use scaled text styles. Symbols in fixed-size controls have bounded scaling so they do not outgrow their backgrounds.
- Friends and Trip content have maximum readable widths. These layout safeguards are not a claim that iPhone Mirroring window resizing has been tested.
- New iOS 27 APIs are availability-gated. Earlier systems retain their toolbar placement and button/surface treatment; minimum deployment remains iOS 18.

## Design references

- [Apple: What's new in SwiftUI, WWDC26](https://developer.apple.com/videos/play/wwdc2026/269/) — toolbar placement, visibility priority, navigation minimization, and adaptable layouts.
- [Apple: Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/liquid-glass) — visual separation between content and floating controls.

API spellings and availability were checked against the installed Xcode 27 SDK. In particular, the shipping declaration is `toolbarMinimizationBehavior(_:for:)`.

## Validation

- Xcode 27.0 (27A266a), iOS 27.0 (24A434), iPhone 18 Pro simulator: 144 unit tests passed. UI flows passed for light/dark Friends, trip creation/persistence/completion, member removal/deletion, flight reminders, and toolbar actions after scrolling.
- Maximum accessibility text size with Increased Contrast passed navigation from the city overview to a friend. Screenshots prompted fixes to bounded icon scaling and the city/section header layouts; the final build passed this test and its screenshots were reviewed. Together with the five flows above, this covers six distinct iOS 27 UI scenarios.
- iOS 26.4.1 (23E254a), fresh iPhone 17 Pro simulator: Friends light/dark, trip creation/persistence/completion, toolbar actions after scrolling, and the final maximum-text-size layout all passed (4 UI tests).
- Visual review caught low contrast on the native prominent button in Night Jade. An explicit adaptive label color restored dark text on the light green fill.
- The initial scroll-minimizing toolbar made Add flight unreachable. Its regression test failed, the Trip navigation was changed to remain expanded, and the same scroll/add-flight/options test passed on both iOS 27 and iOS 26.
- The older iOS 26 QA simulator stalled during launch; compatibility validation used a fresh isolated simulator. Optional diagnostic collection after the initial toolbar failure also stalled and was stopped after the tests had finished; subsequent test runs disabled automatic diagnostic collection.
- Physical devices, iPhone Mirroring/resizable windows, and an iOS 18 runtime were not tested in this pass. This is focused UI adaptation, not certification of every iOS 27 capability.

Local result bundles (not checked into the repository):

- `/private/tmp/across-ios27-adaptation-v2.xcresult` — 144 unit tests and the four original UI flows.
- `/private/tmp/across-ios27-toolbar-v2.xcresult` — corrected persistent Trip toolbar regression test.
- `/private/tmp/across-ios27-final-accessibility.xcresult` — final large-text / Increased Contrast layout.
- `/private/tmp/across-ios26-clean-compatibility.xcresult` — three core compatibility flows.
- `/private/tmp/across-ios26-final-accessibility.xcresult` — final large-text layout on iOS 26.

## Release boundary

This change does not alter the existing App Store 1.0.3 (15) submission. It requires a new build before users receive it through TestFlight or the App Store.
