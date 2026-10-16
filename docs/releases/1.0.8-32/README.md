# Across Us 1.0.8 (32, 33) — internal TestFlight

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

## Build 33 — October 16, 2026

The user's test of build 32 found three problems:

1. Opening a friend, or a plan from Friends' travel plans, played a loading animation and the page jumped. Each screen started an empty plan feed. The friend page also showed a spinner-only "Travel plans" section that then collapsed or filled in. Fix (73c3763): the feed keeps the last page per account, access revision and filter for this launch, and refreshes in the background. The plan screen starts from the row you tapped. The friend page no longer shows a spinner-only section.
2. Opening your own invite link offered to send a friend request to yourself. Fix (04dbf74): it now says "This is your invite link", with a Done button.

Tests: all 264 unit tests passed, including a new feed test. 24 UI tests passed, including new tests for opening your own link and for Lin's shared plan appearing right away on each visit (5 of 5 runs). In one manual check before the UI test, Lin's plan didn't appear until a pull to refresh. It didn't happen again in the repeat check or in the 5 test runs.

Build 33 comes from tag `v1.0.8-33` (ba30568). It was signed the same way as build 32, with `applinks:acrossus.app`, and uploaded at 12:20 PDT.
