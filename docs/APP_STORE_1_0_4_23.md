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
- Xcode reported **Upload succeeded** at **9:39 PM PDT on September 26, 2026**. App Store Connect confirms build 23 is **Complete**, build ID `ccfc7335-544d-40d9-b7cb-63f185d37c75`. Apple processing and review submission are separate steps.

## Store material submitted

- Eight screenshots per language from `app_store_screenshots/2026-09-26/`, with the widget in position 2 and flight map/details in positions 7/8. Both primary sets validated as 1284×2778 PNGs.
- English name/subtitle/keyword experiment: `aso/2026-09-26/next-release-fields.json`.
- Bilingual listing: `app_store_screenshots/2026-09-26/listing.json`.
- Bilingual What's New and reviewer notes: `aso/2026-09-26/release-notes.json`.

## Review state

- After the user explicitly approved replacing the old candidate, cancelled the pending release of **1.0.4 (20)**. The version became Developer Rejected and editable.
- Saved build **23** as the sole selected build, with updated bilingual descriptions, promotional text, keywords, What's New and reviewer notes.
- Uploaded eight independent screenshots for each of English (U.S.) and Simplified Chinese. Verified the final order and actual preview images in both languages. Uploads used the native file chooser after the browser extension upload path was unavailable.
- Saved English name **Across Us: Friends & Trips** and subtitle **Share cities & travel plans**. Chinese name remains **Across Us**, subtitle **分享城市，发现下一次相聚**. Categories and existing ratings retained.
- Selected **Automatically release this version**, with release to all users after approval. No scheduled release date or rating reset is selected.
- Submitted exactly one item, **iOS App 1.0.4 (23)**, on **September 26, 2026 at 10:08 PM PDT**.
- Apple confirmed **1 Item Submitted**, and the review record shows **Waiting for Review**.
- Submission ID: `3c1cf179-f5bf-45e7-8cac-50cbadead850`.
- [Review submission](https://appstoreconnect.apple.com/apps/6807634842/distribution/reviewsubmissions/details/3c1cf179-f5bf-45e7-8cac-50cbadead850).

The public version remains **1.0.3** while Apple reviews this update. The new metadata and screenshots are submitted, not yet public. No approval or release date is guaranteed.
