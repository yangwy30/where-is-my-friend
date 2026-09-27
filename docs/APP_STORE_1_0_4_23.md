# Across Us 1.0.4 (23) — September 26, 2026

## Build and validation

- Source commit: `4a7d69a` (release build-number and notes commit).
- Includes the new Home Screen widgets, Chinese localization improvements, shared-plan refresh fix, friend calendar badges and previous notification fixes.
- Xcode 27.0 (27A266a); all **164 unit tests passed** on the iOS 27 iPhone 18 Pro Max simulator. Prior widget UI/appearance verification is documented in `WIDGET_REDESIGN_20260926.md`.
- App and widget both identify as **1.0.4 (23)**. Production bundle IDs, API endpoint, disabled local Demo and production APNs were verified in the exported IPA.
- Apple Distribution signature passed strict verification.
- Archive: `/tmp/across-appstore23-20260926/AcrossUs-1.0.4-23.xcarchive`.
- Export: `/tmp/across-appstore23-20260926/export/Where Is My Friend.ipa`.
- Export IPA SHA-256: `f29c5d48e917c198073aae5412d1d5d4749d1024b6d156bb98af09754f22dfe7`.
- Xcode reported **Upload succeeded** at **9:39 PM PDT on September 26, 2026**. App Store Connect confirms build 23 is **Processing**, build ID `ccfc7335-544d-40d9-b7cb-63f185d37c75`. Apple processing and review submission are separate steps.

## Store material prepared

- Eight screenshots per language from `app_store_screenshots/2026-09-26/`, with the widget in position 2 and flight map/details in positions 7/8. Both primary sets validated as 1284×2778 PNGs.
- English name/subtitle/keyword experiment: `aso/2026-09-26/next-release-fields.json`.
- Bilingual listing: `app_store_screenshots/2026-09-26/listing.json`.
- Bilingual What's New and reviewer notes: `aso/2026-09-26/release-notes.json`.

## Review state

At the start of this release attempt, **1.0.4 (20)** was Pending Developer Release and **1.0.3** was Ready for Distribution. The user asked to resume App Store publishing, but automatic approval review blocked cancelling build 20's pending release because of the user's earlier explicit instruction to preserve it. A specific replacement-or-old-release choice was requested. The cancellation did **not** execute. No screenshots, listing fields or review submission have been changed yet; build 23 is uploaded independently while awaiting that choice.
