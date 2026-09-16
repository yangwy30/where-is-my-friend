# Across Us 1.0.2 (9) — September 15, 2026

## Delivery

- User requested the current work from the task **评估集成 TripFlights 功能** to be uploaded to the production App's TestFlight, and the refreshed introduction/screenshots to be uploaded to App Store Connect.
- Bundle ID: `com.yangwy30.whereismyfriend`; Widget: `com.yangwy30.whereismyfriend.widget`; App Store ID: `6807634842`.
- Release App and Widget build numbers increased from 8 to **9**; version remains **1.0.2**. Debug/Staging settings are unchanged.
- Built from an isolated source snapshot at `/private/tmp/across-release-20260915/source`. Archive: `AcrossUs-1.0.2-9.xcarchive` in its parent directory.
- **Upload succeeded at 12:00:56 PDT on September 15**. Apple reports the upload **Complete**; build ID `d89d2cc8-c912-4b11-9f58-b30f9cab12f6`.
- Build is associated with the existing **Testers / Internal / 1 tester** group. Build-specific What to Test was saved. No new tester invitations or external Beta App Review submission were made.
- Updated the English TestFlight beta description, marketing URL and privacy URL.

## Included work and validation

- Automatic foreground city refresh, fresh-sample ordering, manual-city and paused-sharing protections.
- Corrected artwork aliases and presentation-only regional artwork from catalog `2026-09-15.1`.
- Optional administrative-area metadata through App, Widget, repositories and storage. Real city names and exact-city matching remain intact; `regionMatchingEnabled` remains false.
- Current profile, invitation, Trips, personal-plan and same-city improvements.
- Prior final feature validation: **98 unit tests + 3 UI tests**, zero failures, `/private/tmp/wif-city-regions-isolated-20260915.xcresult`; final disclosure-only build passed.
- Marketing capture validation: **2 UI workflows**, zero failures, `/private/tmp/across-us-marketing-signed-20260915.xcresult`.
- Release archive/export succeeded. Exported App and Widget both verified as 1.0.2 (9); production bundle IDs/backend; `WIFAllowsLocalDemo=NO`; catalog present in both products; region matching disabled.
- Distribution signature validates. App has production APNs, Sign in with Apple, App Group, beta reporting, and `get-task-allow=false`.
- Physical-device location/background behavior remains a TestFlight acceptance task; simulator tests do not establish real-world location or push timing.

## App Store assets

- Created **1.0.2 / Prepare for Submission** draft and selected build **9**.
- Saved refreshed English (U.S.) and added Simplified Chinese descriptions, promotional text, keywords and current-build release notes.
- Saved subtitles: **More chances to meet** / **分享城市，发现下一次相聚**.
- Replaced the draft's inherited old screenshots with seven **1284 × 2778** PNGs. Verified order: Friends, Here together, Together soon, Trips, arrivals, Widgets, sharing.
- Simplified Chinese inherits the same English screenshots, matching the approved asset set. Media Manager uses the 6.5-inch set for selected iPhone sizes/localizations.
- Updated draft review notes for build 9. **Submitted for public App Store review on September 15, 2026.** Apple confirmed `1 Item Submitted`; version status is **Waiting for Review**. Submission ID: `40fc5acd-fcab-4407-aa4d-1c2b796fc919`. The existing **Automatically release this version** setting remains selected. Public version remains 1.0.1 until approval/release.
- TestFlight's invitation screenshots are sourced from the latest version marked Ready for Distribution, so they continue to show the approved 1.0.1 assets until a newer version is released.

## Approved backend and privacy dependencies

The automatic approval review initially declined the production migration because upload authorization did not explicitly cover backend changes. The user then expressly approved the compatible migration, API update and privacy publication.

- Pre-deployment private backup: `.migration-backups/app-predeploy-y6yWp7`; public data/schema and ledger only, not a full Auth/Storage disaster-recovery backup.
- Applied only migration **20260915010000_city_region_metadata** with baseline checks, transaction and lock/statement timeouts. No blanket migration push, city rewrites or region-level matching activation.
- Deployed production **api v19 / ACTIVE / verify_jwt=true** after the migration.
- Confirmed nullable metadata column and service-only v2 execution; anon/authenticated direct execution denied. Unauthenticated API bootstrap still returns HTTP 401.
- Published the bilingual privacy update, covering optional administrative-area metadata and private future plans, via isolated commit **65aa5f45eeaca758d553009416cf2cbcec571980**. Only `site/privacy/index.html` was pushed.
- GitHub Pages workflow **35012474293** succeeded. Public policy URL: https://yangwy30.github.io/where-is-my-friend/privacy/.

Logs, exported IPA, live-verification results and frozen source are under `/private/tmp/across-release-20260915/`. No credentials are included in this document.
