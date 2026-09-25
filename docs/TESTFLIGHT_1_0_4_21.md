# Across Us 1.0.4 (21) — friend plans and same-city banners

## Included

- Friends with visible active/upcoming travel plans have a small calendar badge with two brief pulses. Reduce Motion is respected; tapping the friend opens their shared cities and dates above current-city details.
- Active Friends refreshes can show a new same-city moment in-app even when APNs is unavailable. Recent events only, first-response history suppression, account isolation and shared APNs/snapshot deduplication prevent historical or duplicate banners.
- Friend details offer notification setup when same-city alerts are enabled but notification access or device registration needs attention.
- Uses the previously completed production APNs topic authorization repair. That server-side repair was already live before this build; APNs accepted one authorized test retry. Physical-device display was not independently confirmed.

## Verification and provenance

- 158 iOS unit tests passed, including new snapshot banner delivery, deduplication, consent/account filtering and inactive-app behavior. The friend badge → profile plans → plan detail UI test passed on iOS 27; home/profile screenshots were reviewed.
- Source commit: `7a9f29b`. Frozen tracked source SHA-256: `dda04a0bd727c36170b3e198892e2923adf481ce918a442032f6b4bc7241c843`.
- Production App and Widget are **1.0.4 (21)**, production backend and APNs, local Demo disabled. Archive/export succeeded and the IPA passed strict signature verification with Apple Distribution team `93RUQ2A6KX`.
- IPA SHA-256: `d22da2fdc962d52bfb4214afdb9fab40ff88014164948539bb88e8a1192cd463`.
- Xcode confirmed **Upload succeeded** on September 24, 2026 at **9:37 PM PDT**. App Store Connect showed upload status **Complete** and the existing **Testers / Internal / 1 tester** group assigned. Bilingual What to Test notes were saved with the **Saved** confirmation.
- Apple build ID: `d1c96264-f8af-4f6c-8c97-42a34f3a2d27`. [TestFlight build page](https://appstoreconnect.apple.com/teams/9b0eb9fa-54ee-4f56-83ae-1e79e3cf4125/apps/6807634842/testflight/ios/d1c96264-f8af-4f6c-8c97-42a34f3a2d27).

This upload is for TestFlight. It does not replace build 20 in the existing App Store review submission.
