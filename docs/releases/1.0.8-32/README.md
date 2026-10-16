# Across Us 1.0.8 (32) — internal TestFlight

1.0.8 is meant to replace 1.0.7 (31), which is still Waiting for Review. Plan agreed on October 16, 2026: get 1.0.8 onto TestFlight first and keep 1.0.7 in review until 1.0.8 has been tested on a device. Then remove 1.0.7 from review, switch the version to 1.0.8 with build 32, upload the new screenshots and submit.

## Build

- Source: tag `v1.0.8-32` (1123606) on `ui/1.0.8-combined`, pushed. It contains 1.0.7 (31), the same-city redesign, the rebuilt city emblems, the acrossus.app invite links, and the 1.0.8 polish fixes.
- Archived unsigned from a clean worktree, then re-signed with cloud Apple Distribution signing and uploaded on October 16 at 11:25 PDT. Artifacts are in `build/release-1.0.8-32/` (git-ignored).
- Signing check: Apple Distribution (93RUQ2A6KX), `aps-environment` production, App Group `group.com.yangwy30.whereismyfriend`, `applinks:acrossus.app`, `get-task-allow` false. App and widget are both 1.0.8 (32). `WIFInviteBaseURL` is `https://acrossus.app`, and the privacy policy is `https://acrossus.app/privacy/`.
- Release entitlements name `applinks:acrossus.app` directly, because `prepare_archive_entitlements.py` only fills in the app group and push environment.

## Tests

- Unit tests: all 263 passed on an iPhone 18 Pro Max simulator (iOS 27).
- UI tests: 16 targeted at same city, overlaps and invite links. 15 passed on the first run. `testCityRegionArtworkKeepsRealCityAndDoesNotCreateSameCityMatch` failed because one pull didn't refresh under the taller 1.0.8 header. The app shows Milpitas after a pull, so this was a test gesture problem. The test now retries the pull (1c196a9) and passes. The full UI suite wasn't run locally.

## Device checks before submitting

1. Share an invite link from Friends > Add friends. It should read `https://acrossus.app/i/<username>`, and Messages should show "@username invited you to Across Us".
2. Tap that link on a phone with 1.0.8 installed. It should open the app, not Safari.
3. Check the same-city chip and Here with you panel, and the Together soon timeline.

## Store content for the 1.0.8 submission

- Screenshots: the [October 16 set](../../app_store_screenshots/2026-10-16/README.md).
- What's New: [English](en-US-whatsNew.txt) and [Chinese](zh-Hans-whatsNew.txt). These carry the 1.0.7 notes too, because 1.0.7 was never released.
- [Review notes](review-notes.txt): the 1.0.7 notes plus the invite link in path 2 and a rewritten version summary.
- Already changed on October 16: the privacy policy URL (app level), and the support and marketing URLs on 1.0.7, now point to acrossus.app.
