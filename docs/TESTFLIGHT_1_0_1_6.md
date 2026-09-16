# Across Us 1.0.1 (6) — onboarding motion

## Scope

- User authorized TestFlight upload on September 11, 2026. No App Store production review submission or backend deployment.
- Existing production app: `com.yangwy30.whereismyfriend`, App Store Connect `6807634842`, team `93RUQ2A6KX`.
- App and widget Release build numbers incremented from 5 to 6; version incremented to 1.0.1 after Apple rejected another 1.0.0 upload because that approved version train is closed. Staging configurations unchanged.
- Existing Supabase project and remote repository retained; archived `WIFAllowsLocalDemo` is `NO`.
- Includes the four-chapter onboarding refresh, freestanding city artwork, recognizable example notification, trip-planning chapter, sequenced city/reunion/flight animations, layered drag parallax and Reduce Motion fallback. Details: [onboarding implementation](ONBOARDING_REDESIGN_2026_09_11.md).

## Verification

- Complete unit suite: **63 passed, 0 failed, 0 skipped** on iPhone 17 Pro Max simulator.
- Onboarding UI flows, completion/skip, interrupted motion and Reduced Motion examples passed during implementation.
- Release archive succeeded; archive app and embedded widget both report build 6. Archive code signature verified.
- Final archive: `/private/tmp/AcrossUs-1.0.1-6.xcarchive`; verified app and widget both report version 1.0.1.
- Unit result: `/private/tmp/wif-trips-jade-build/Logs/Test/Test-WhereIsMyFriend-2026.09.11_12-14-59--0400.xcresult`.
- Final distribution logs: `/var/folders/z5/mwjh39j95h1dsxqs1m0c8f3r0000gn/T/WhereIsMyFriend_2026-09-11_12-20-14.571.xcdistributionlogs`.

## What to Test

1. Review the refreshed four-page introduction: friends across cities, same-city notification example, shared trip planning, and city-level privacy.
2. Watch the staggered city entrance, reunion followed by notification, and two flights converging before arrival information appears.
3. Tap Back, Continue or Skip during animations; navigation should never wait for the sequence to finish.
4. Enable Reduce Motion in iOS Accessibility settings and confirm every example remains visible without animated movement.
5. Check light/dark appearance and larger text. Confirm Sign in with Apple and existing Friends/Trips flows still work.
6. Existing users can replay via You → Developer Lab & Tools → Preview onboarding, without deleting the app.

## Distribution status

- Initial 1.0.0 (6) upload failed with Apple errors 90062 and 90186 (approved version / closed pre-release train). No binary accepted from that attempt.
- **1.0.1 (6) uploaded successfully at 12:22:19 EDT, September 11, 2026**. Xcode returned `EXPORT SUCCEEDED`; Apple upload ID `89e2cdbc-4c34-4e24-9783-e304b403d068`.
- App Store Connect independently shows version 1.0.1, build 6, `Processing` at 12:22 PM. Upload accepted; processing is not yet confirmation of install availability.
- Existing internal Testers group uses Automatic for Xcode Builds. No testing-group settings or external review submissions changed.
