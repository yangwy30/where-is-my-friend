# Across Us 1.0.4 (22) — shared-plan refresh hotfix

- Fixes the [navigation cancellation race](FRIEND_PLAN_REFRESH_FIX_20260924.md) that could clear a successful shared-plan response and show “Couldn’t load shared plans. Try again.” The library now owns and coalesces the read across screens; account changes and plan writes invalidate old reads.
- Places the animated calendar badge at the top-right corner of each friend card, with a 12-point inset. The badge does not intercept taps; the entire friend card still opens that friend's plans/details.
- The reproduction failed before the fix. On the fixed source, 162 unit tests and two Friend plans UI flows passed on iOS 27.
- After the position change, the friend badge → profile plans → plan detail UI test passed again and the new corner position was checked in a simulator screenshot.
- Final source commit: `801f9c0`. Frozen source SHA-256: `e1cb0ec06f1c31715f9258f3507de0d0260b46b13cd3578d622c56c43ac6aac8`.
- App and Widget Release build number: **1.0.4 (22)**. Final archive succeeded at `/private/tmp/across-testflight22-final-20260924/AcrossUs-1.0.4-22.xcarchive`.
- Delivery pending: export failed with `No Accounts`. After the Mac was unlocked, Xcode Settings → Apple Accounts still showed the Sign In screen. The final archive is ready for distribution export/upload after the user signs into Xcode; build 22 has not yet been uploaded. The earlier archive omitted the final badge-position adjustment and is superseded.

This is a TestFlight hotfix. The existing App Store review submission is not being replaced by this task.
