# Across Us — cities, plans and time together

Completed September 26, 2026. **Prepared locally; not uploaded to App Store Connect.**

## Deliverables

- `gallery.html`: all eight posters in English and Simplified Chinese.
- `contact-sheet-en.png` and `contact-sheet-zh-Hans.png`: complete sequence previews.
- `en/1284x2778/` and `zh-Hans/1284x2778/`: primary upload sets, eight opaque PNGs each.
- `en/1320x2868/` and `zh-Hans/1320x2868/`: alternate size sets.
- `listing.json`: subtitle, promotional text, description and keywords for both localizations, checked against field length limits.
- [Bilingual introduction](../../APP_INTRO_20260925.md).
- `copy.json`: poster text, source crop and layout settings.
- `raw/`: unchanged simulator captures; `manifest.json` records provenance and checksums.
- `svg/`: reproducible poster compositions with embedded actual screenshots.

## Sequence

1. Friends and shared current cities.
2. Friend plans and upcoming cities.
3. Together soon and overlapping dates.
4. Here together, in the same city.
5. Shared Trips.
6. Expanded geographic map: friends' routes converge on one destination.
7. Ongoing Trip with an expanded flight: route, status, departure/arrival times, airline and terminal.
8. Actual installed Friends directory Home Screen widget.

Cream and pale mint backgrounds, dark green typography and short benefit-led copy replace the older bright green treatment. The screenshots show the build 22 interface with the new, not-yet-released Chinese UI localization fixes and redesigned Home Screen widgets. All friends and plans are demo data. The widget poster retains wallpaper, its app label and the Dock from a real Home Screen screenshot; it is not the developer's Widget Studio mock. The widget's English system-rendered contents are shared across both locales. Core interface labels in the Chinese captures are now localized in the actual app. User-created trip names, friend names, airport identifiers and geographic proper names are preserved.

## Capture and validation

Source: build 22 UI plus Chinese localization corrections and a DEBUG-only `-marketingOverlap` personal-plan fixture. Localization affects the next app build; no backend or travel logic change is intended.

Use `PrototypeUITests/testCaptureUpdatedMarketingEnglish` and `testCaptureUpdatedMarketingChinese` for the first seven screens. Use `testCaptureMarketingFlightDetails` for the new seventh poster, opening the ongoing West Coast Trip and expanding Alex’s flight. Use `testCaptureMarketingOverlapDetails` for just the overlap details. These navigate through Friend plans before opening the overlap to ensure the shared plan data has loaded.

The sixth poster was revised following user feedback to feature the expanded MapKit route map instead of the arrivals list. `testCaptureMarketingFlightMaps` captures both locales through the real Expand map button. The poster preserves the actual airport markers and route lines; it does not add simulated live aircraft positions. Static posters cannot reproduce the map's route-reveal animation.

For the eighth screen, install the Friends, near and far large widget on the simulator Home Screen, then run `testCaptureActualMarketingWidgets`. It captures three Home Screen pages after the app seeds its actual shared widget data. The selected capture is page 2; crop coordinates are in `copy.json`.

Run on iPhone 18 Pro Max with local simulator signing (`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`), parallel testing disabled. Export XCTest attachments with `xcresulttool export attachments`. The final September 26 overlap test passed (both locales); the actual-widget capture test passed. The new bilingual flight-details capture test also passed on September 26. The first overlap attempt failed to load data before the UI wait and supplied no final assets.

Render with `node scripts/render_marketing_20260925.mjs`, with `sharp` available in the Node module path. Running without `--partial` requires every capture. This renders 32 opaque PNGs (two sizes × eight screens × two languages), two contact sheets and the gallery. Both contact sheets and the overlap/widget details were visually reviewed.

## Store handoff

Last verified September 25: version 1.0.4 build 20 was Pending Developer Release; build 22 was in internal TestFlight. On September 26 the browser required sign-in. These materials must accompany a new build containing the Chinese localization fixes and redesigned widgets; do not publish them as evidence of features in the older approved build. Recheck the version status before changing the submission. No approved submission has been withdrawn and no public release has been performed as part of this asset refresh.

## Independent review follow-up

The initial independent agent review identified mixed Chinese/English UI, small secondary text, and a widget crop lacking Home Screen context. The updated set uses actual localized app captures, short 48px subtitles (previously 37px), a focused flight-detail crop with a navigation caption, and a real Home Screen crop including wallpaper and Dock icons. The eight-image order is unchanged.

Validation: 18 TripFlightLookupTests and both full bilingual capture workflows passed (20 tests total). PNG dimension/opacity checks and visual review cover the final assets. Translation changes need a new release build before store publication; App Store Connect has not been modified.

## Widget implementation follow-up

Screen 08 now shows the actual installed Friends directory widget after the approved redesign. The same English-language system capture is used in both poster locales. The dedicated Here together widget, all sizes, dark mode, Chinese and edge states are verified separately in [the widget implementation report](../../WIDGET_REDESIGN_20260926.md).
