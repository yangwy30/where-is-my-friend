# Across Us 1.0.5 (25) — background city follow-up

## Scope and authorization

The owner approved replacing the queued 1.0.5 (24) submission with a build containing the [background city and Always reminder fixes](SAME_CITY_BACKGROUND_20260927.md). Apple still showed build 24 as Waiting for Review when preparation started. The replacement is prepared before withdrawing the old submission.

Build 25 retains all build 24 changes and adds:

- Scene-independent startup and upload handling for opted-in background city updates, with bounded execution time and stale-fix recovery.
- A gentle Friends reminder for While Using location access, sharing the existing seven-day cooldown and three-presentation lifetime limit. The user chooses Always in system settings; permission is never changed automatically.
- Clearer location settings that distinguish foreground-only permission from background availability.
- Compatibility with the already deployed immediate same-city worker wake (API 28, push-worker 22).

## Validation

The functional source is based on `d26a06b`: 143 backend tests, 193 iOS unit tests, four UI flows and Release simulator compilation passed. This release preparation changes only the production app/widget build number from 24 to 25 and release documentation. Real-device arrival-to-banner timing remains a separate acceptance check; no instantaneous push-delivery guarantee is made.

## Release copy

English What's New:

> • Improved background city updates and same-city notification handling.
> • Clearer location settings, with gentle reminders to enable background updates.
> • Smoother Friend plans browsing and a compact Together soon preview.
> • More reliable refreshes and links to shared plans.

Chinese What's New:

> • 改善后台城市更新与同城提醒。
> • 更清楚的位置设置，并适时提醒开启后台更新。
> • 好友计划浏览更顺畅，首页相聚摘要更精简。
> • 改善刷新体验，以及从通知打开计划的可靠性。

Keep the existing bilingual descriptions, screenshots, keywords, diagnostics declarations, automatic release after approval and existing ratings.

## Distribution state

- Source frozen at `14b5771`. Archive and distribution export succeeded at `/tmp/across-release105-build25/AcrossUs-1.0.5-25.xcarchive` and `/tmp/across-release105-build25/export/Where Is My Friend.ipa`.
- App and widget passed strict Apple Distribution signature verification. Both are 1.0.5 (25), with production identifiers/backend/APNs, local demo disabled and diagnostics enabled. The packaged privacy manifest matches source.
- Exported IPA SHA-256: `90754a8bc421cfbf519da2667cbbb4d11548d4998b14d0370b269a1b5d0e77be`.
- Xcode confirmed **Upload succeeded** on September 27, 2026 at **10:19 PM PDT**. Apple subsequently showed **Complete** for build ID `35d3f102-c63c-46dd-901c-c23c3687d16e`.
- [TestFlight build 25](https://appstoreconnect.apple.com/teams/9b0eb9fa-54ee-4f56-83ae-1e79e3cf4125/apps/6807634842/testflight/ios/35d3f102-c63c-46dd-901c-c23c3687d16e) is assigned to **Testers / Internal / 1 tester**. Bilingual test notes were saved, including the real-journey timing check. No new testers or external groups were added.
- After build25 was ready, cancelled submission `34e033cb-be03-4691-b1c4-206891eff236` containing build24 (`fb1a626c-f4c3-45dc-9f49-66ea8e8c8bb2`). Apple made 1.0.5 editable as Developer Rejected; this was an owner-requested withdrawal, not an Apple rejection.
- Replaced the selected build with **25**, saved updated English/Chinese What's New and reviewer notes, and retained automatic release after approval with existing ratings.
- Submitted exactly one item, **1.0.5 (25)**, on **September 27, 2026 at 10:29 PM PDT**. Apple displayed **1 Item Submitted**; its review record confirms **Waiting for Review**.
- New submission ID: `1e70df43-404b-42f5-b502-fbef60c474f3`. [Review record](https://appstoreconnect.apple.com/apps/6807634842/distribution/reviewsubmissions/details/1e70df43-404b-42f5-b502-fbef60c474f3).
- Local confirmation screenshots: `/tmp/across-release105-build25/apple-submitted.png` and `apple-review-status.png`. Public 1.0.4 remains available while review is pending; approval and release timing are not guaranteed.
