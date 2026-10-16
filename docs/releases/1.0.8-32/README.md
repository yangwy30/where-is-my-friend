# Across Us 1.0.8 (32–35) — internal TestFlight

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

The user's test of build 32 found three problems. The page transition glitch and the loading animation had one cause, so they're listed together:

1. Opening a friend, or a plan from Friends' travel plans, played a loading animation and the page jumped. Each screen started an empty plan feed. The friend page also showed a spinner-only "Travel plans" section that then collapsed or filled in. Fix (73c3763): the feed keeps the last page per account, access revision and filter for this launch, and refreshes in the background. The plan screen starts from the row you tapped. The friend page no longer shows a spinner-only section.
2. Opening your own invite link offered to send a friend request to yourself. Fix (04dbf74): it now says "This is your invite link", with a Done button.

Tests: all 264 unit tests passed, including a new feed test. 24 UI tests passed, including new tests for opening your own link and for Lin's shared plan appearing right away on each visit (5 of 5 runs). In one manual check before the UI test, Lin's plan didn't appear until a pull to refresh. It didn't happen again in the repeat check or in the 5 test runs.

Build 33 comes from tag `v1.0.8-33` (ba30568). It was signed the same way as build 32, with `applinks:acrossus.app`, and uploaded at 12:20 PDT.

## Build 34 — October 16, 2026

Testing build 33 found one more problem. For a Kauai trip (LIH), "Use these dates for my travel plan" searched "Kauai, United States" and showed "No city found". Apple returns Kauai as an island record with no city. Fix (6c75034): when no search result has a city, the picker looks up the city at those places and offers it. Kauai gives Lihue, HI. This also covers the "From your shared trips" shortcuts and typing an island or county name. The fix was checked on the simulator with live Apple search. The city picker and shared trip date UI tests pass.

Build 34 comes from tag `v1.0.8-34` and was uploaded at 12:58 PDT.

## Build 35 — October 16, 2026

The user called the "New travel plan" editor a bit ugly. It's redesigned to the [design rules](../../WEBSITE_DESIGN_DIRECTION_20261015.md):

- City, dates and who can see the plan are one card with three matching rows.
- The two switches share a second card, with each explanation under its label.
- The copied-from note is one line.
- Everything fits on one screen, including the overlap reminder, which used to be below the fold.

The privacy notes are unchanged: friends are selected by default, and the plan is saved separately from the shared trip. 15 editor UI tests pass. The share sheet test helper was updated for the share preview header added in build 32.

Also checked: TestFlight never shows App Store screenshots. They're uploaded to the 1.0.8 version page at submission.

Build 35 comes from tag `v1.0.8-35` and was uploaded at 13:25 PDT. Submit build 35.

## Submitted — October 16, 2026, 14:07 PDT

The user confirmed build 35 and asked to submit it.

- 1.0.7 (31) was removed from App Review while it was In Review. The submission shows as Removed, and the version became Developer Rejected.
- The same version record was renamed to 1.0.8. Build 31 was replaced with build 35.
- Screenshots: the [October 16 set](../../app_store_screenshots/2026-10-16/README.md), five per locale, in English and Chinese. They were uploaded to the 6.3" (1206×2622) and 6.5" (1284×2778) slots, replacing the seven 1.0.7 images. The old images remain in the Asset Library.
- What's New ([English](en-US-whatsNew.txt), [Chinese](zh-Hans-whatsNew.txt)) and the [review notes](review-notes.txt) (3,965 characters) were entered and saved.
- The submission also carries the app-level privacy policy URLs changed earlier, which are now acrossus.app.
- Release settings are unchanged: automatic release after approval, all users at once, existing rating kept.

Status: **Waiting for Review**. [Submission 9aa4ff6b-fa4d-484b-aafd-eec2abb1cc55](https://appstoreconnect.apple.com/apps/6807634842/distribution/reviewsubmissions/details/9aa4ff6b-fa4d-484b-aafd-eec2abb1cc55).

After approval, merge `ui/1.0.8-combined` into `main`. Pushing `main` redeploys the website, which already matches.
