# Home Screen widget redesign — September 26, 2026

## Result

Implemented the approved **Friends directory** and **Here together** concepts. Default widgets put people and their shared cities first; the dedicated same-city widget uses a serif city title and overlapping avatar circles. Both use quiet cream/sage surfaces and an adaptive dark palette. Landmark models and orbit decoration are removed from Home Screen widgets.

- Small directory: one featured friend, a two-line city label, and same-city or update context.
- Medium directory: up to four friends in a compact two-column layout.
- Large directory: four rows (three at accessibility text sizes), update age or a same-city badge, and total friend count.
- Same-city widgets: only eligible recent matches appear. Empty, name-hidden and fully hidden modes have explicit layouts.
- Lock Screen accessory layouts and existing widget kind identifiers are retained.
- Featured-friend selection, ordering, sharing filters and the existing timeline schedule remain in place.

`HomeWidgetViews.swift` is compiled into both the app and the extension. The App's Widget Studio now previews those production views, replacing the separate diorama mockup. Simulator previews and actual installed-widget captures are stored under `widget_redesign/2026-09-26/`.

## Correctness fixes found during implementation

- The old small-widget same-city path could display a first name while Hide Names was enabled. All new Home Screen name and initial rendering now passes through the same privacy-aware model; spoken labels use it too.
- Long city names get two lines in the small directory widget instead of being compressed into one truncated line.
- Added Chinese widget strings, including friend counts; the brand remains “ACROSS US”.
- Added the extension's English development-region declaration, aligning it with the app and catalog source language. Apple's [bundle language documentation](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundledevelopmentregion) describes this fallback.

## Validation

Capture workflows cover both designs at all three Home Screen sizes, light/dark palettes, Chinese, hidden names, hidden content, no friends and a long city/name. A positive full-name accessibility check precedes the hidden-name assertions. Unit checks exercise name/initial redaction, different-state same-city rejection, stale/paused presence rejection and conservative update timestamps.

All imagery uses actual SwiftUI views with local demo data. The installed Home Screen widget is captured separately; the preview screenshots do not claim to be SpringBoard captures.

Verification result: **6 focused tests passed** (2 presentation-policy unit tests and 4 UI capture/edge-state workflows). A final installed-widget capture also passed after the language declaration fix. Long city text was visually verified to wrap completely, and the dark screenshots were verified to actually render dark.

## Release state

Source and screenshots are prepared for the next build. No TestFlight upload or App Store submission is part of this implementation turn. Existing build 22 does not contain the new widgets or the preceding Chinese localization changes.
