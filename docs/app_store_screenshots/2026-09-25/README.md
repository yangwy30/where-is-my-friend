# Across Us — cities, plans and time together

Completed September 26, 2026. **Prepared locally; not uploaded to App Store Connect.**

## Deliverables

- `gallery.html`: all seven posters in English and Simplified Chinese.
- `contact-sheet-en.png` and `contact-sheet-zh-Hans.png`: complete sequence previews.
- `en/1284x2778/` and `zh-Hans/1284x2778/`: primary upload sets, seven opaque PNGs each.
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
6. Flights and arrival times.
7. Actual installed City Stage Home Screen widget.

Cream and pale mint backgrounds, dark green typography and short benefit-led copy replace the older bright green treatment. The screenshots show the build 22 interface. All friends and plans are demo data. The widget poster crops a real Home Screen screenshot; it is not the developer's Widget Studio mock. The widget's English system-rendered contents are shared across both locales. Chinese app captures preserve untranslated labels still present in the app.

## Capture and validation

Source: committed build 22 UI plus a DEBUG-only `-marketingOverlap` personal-plan fixture. No release behavior changes.

Use `PrototypeUITests/testCaptureUpdatedMarketingEnglish` and `testCaptureUpdatedMarketingChinese` for the first six screens. Use `testCaptureMarketingOverlapDetails` for just the overlap details. These navigate through Friend plans before opening the overlap to ensure the shared plan data has loaded.

For the seventh screen, install the City Stage large widget on the simulator Home Screen, then run `testCaptureActualMarketingWidgets`. It captures three Home Screen pages after the app seeds its actual shared widget data. The selected capture is page 2; crop coordinates are in `copy.json`.

Run on iPhone 18 Pro Max with local simulator signing (`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`), parallel testing disabled. Export XCTest attachments with `xcresulttool export attachments`. The final September 26 overlap test passed (both locales); the actual-widget capture test passed. The first overlap attempt failed to load data before the UI wait and supplied no final assets.

Render with `node scripts/render_marketing_20260925.mjs`, with `sharp` available in the Node module path. Running without `--partial` requires every capture. This renders 28 opaque PNGs (two sizes × seven screens × two languages), two contact sheets and the gallery. Both contact sheets and the overlap/widget details were visually reviewed.

## Store handoff

Last verified September 25: version 1.0.4 build 20 was Pending Developer Release; build 22 was in internal TestFlight. On September 26 the browser required sign-in. These materials must accompany build 22 or newer; do not publish them as evidence of features in the older approved build. Recheck the version status before changing the submission. No approved submission has been withdrawn and no public release has been performed as part of this asset refresh.
