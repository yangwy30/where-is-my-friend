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

Archive/export preparation is in progress. Do not describe build 25 as uploaded or submitted until confirmed by Apple. The original review submission is `34e033cb-be03-4691-b1c4-206891eff236`; the original build ID is `fb1a626c-f4c3-45dc-9f49-66ea8e8c8bb2`.
