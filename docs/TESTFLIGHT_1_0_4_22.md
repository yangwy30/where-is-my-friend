# Across Us 1.0.4 (22) — shared-plan refresh hotfix

- Fixes the [navigation cancellation race](FRIEND_PLAN_REFRESH_FIX_20260924.md) that could clear a successful shared-plan response and show “Couldn’t load shared plans. Try again.” The library now owns and coalesces the read across screens; account changes and plan writes invalidate old reads.
- The reproduction failed before the fix. On the fixed source, 162 unit tests and two Friend plans UI flows passed on iOS 27.
- Source commit: `ef9c66d`. Frozen source SHA-256: `a10660752bf794893677baa4f51117b012ab307841ecd0185531a3730896c140`.
- App and Widget Release build number: **1.0.4 (22)**. Signed archive succeeded at `/private/tmp/across-testflight22-20260924/AcrossUs-1.0.4-22.xcarchive`.
- Delivery pending: distribution export could not access the Xcode account while the Mac was locked. The archive is ready for export/upload after the user unlocks the Mac; build 22 has not yet been uploaded.

This is a TestFlight hotfix. The existing App Store review submission is not being replaced by this task.
