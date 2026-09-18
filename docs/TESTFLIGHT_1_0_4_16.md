# Across Us 1.0.4 (16) — iOS 27 UI adaptation

## Included

- iOS 27 native Trip toolbar placement and prominent form buttons, with Trip actions kept reachable after scrolling.
- Stable content surfaces for Friends, friend details, same-city moments, and settings; existing city artwork and Solar Jade / Night Jade branding remain integrated.
- Adaptive Friends columns, stacked city/section headers at accessibility text sizes, bounded icon scaling, stronger outlines under Increased Contrast, and opaque custom surfaces under Reduce Transparency.
- Corrected contrast for prominent buttons in Night Jade.

Implementation: `d9fa2e7096ea4026d0c9a948d45c3c8fc0e4d221`. Detailed test results and limits: [iOS 27 adaptation record](IOS27_UI_ADAPTATION_20260918.md).

## Validation and package

- 144 unit tests and six distinct UI workflows passed on iOS 27; four compatibility UI workflows passed on iOS 26.4.1. No production code changed after that verification except Release version/build numbers.
- Xcode 27.0 (27A266a); minimum deployment remains iOS 18.
- Production App `com.yangwy30.whereismyfriend` and Widget `com.yangwy30.whereismyfriend.widget`: **1.0.4 (16)**, team `93RUQ2A6KX`.
- Local demo disabled; distribution signatures and production push entitlement verified.
- Frozen tracked source: `/private/tmp/across-testflight16-20260918.qnsl377u/source` (1,267 files). Manifest unchanged during archive/export.
- Archive: `/private/tmp/across-testflight16-20260918.qnsl377u/AcrossUs-1.0.4-16.xcarchive`.
- Exported IPA SHA-256: `e7011676322575370ffe83765f96374051e4380555ef594c579a09d0c5cb6d47`.
- No backend change or deployment.

## Apple delivery

Xcode confirmed **Upload succeeded** at **15:27:55 PDT, September 18, 2026**. App Store Connect subsequently showed upload status **Complete** and version **1.0.4 (16)** assigned to **Testers / Internal / 1 tester**. Bilingual What to Test notes were saved; the page confirmed **Saved**.

Apple build ID: `c07ccb3a-050c-456f-8419-058b80b8eb6e`.

[TestFlight build page](https://appstoreconnect.apple.com/teams/9b0eb9fa-54ee-4f56-83ae-1e79e3cf4125/apps/6807634842/testflight/ios/c07ccb3a-050c-456f-8419-058b80b8eb6e)

The version list says **Ready to Submit** for external beta review; this build is assigned to the existing internal group. No new tester group, external review submission, or App Store submission was created. This release does not replace the existing App Store 1.0.3 submission.
