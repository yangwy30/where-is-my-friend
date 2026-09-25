# Across Us 1.0.4 (22) — shared-plan refresh hotfix

- Fixes the [navigation cancellation race](FRIEND_PLAN_REFRESH_FIX_20260924.md) that could clear a successful shared-plan response and show “Couldn’t load shared plans. Try again.” The library now owns and coalesces the read across screens; account changes and plan writes invalidate old reads.
- Places the animated calendar badge at the top-right corner of each friend card, with a 12-point inset. The badge does not intercept taps; the entire friend card still opens that friend's plans/details.
- The reproduction failed before the fix. On the fixed source, 162 unit tests and two Friend plans UI flows passed on iOS 27.
- After the position change, the friend badge → profile plans → plan detail UI test passed again and the new corner position was checked in a simulator screenshot.
- Final source commit: `801f9c0`. Frozen source SHA-256: `e1cb0ec06f1c31715f9258f3507de0d0260b46b13cd3578d622c56c43ac6aac8`.
- App and Widget Release build number: **1.0.4 (22)**. Final archive succeeded at `/private/tmp/across-testflight22-final-20260924/AcrossUs-1.0.4-22.xcarchive`.
- After the user restored Xcode's Apple login, distribution export succeeded. The final IPA passed strict Apple Distribution signature verification; production backend/APNs and disabled Demo were checked for the app, and both app/widget version numbers are 1.0.4 (22).
- IPA SHA-256: `0d771c03b46073c699d79a39a39e5e40967bb5f117080cde4971959c5d9d90c1`.
- Xcode confirmed **Upload succeeded** on **September 25, 2026 at 12:10 AM PDT**. App Store Connect subsequently showed upload status **Complete**, assignment to the existing **Testers / Internal / 1 tester** group, and one recorded install. Bilingual What to Test notes were saved with the **Saved** confirmation.
- Apple build ID: `cb08a217-b7f5-4637-999d-50638616e2fc`. [TestFlight build page](https://appstoreconnect.apple.com/teams/9b0eb9fa-54ee-4f56-83ae-1e79e3cf4125/apps/6807634842/testflight/ios/cb08a217-b7f5-4637-999d-50638616e2fc).

This is a TestFlight hotfix. The existing App Store review submission is not being replaced by this task.
