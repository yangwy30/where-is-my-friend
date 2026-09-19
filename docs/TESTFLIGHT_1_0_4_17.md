# Across Us 1.0.4 (17) — compact Trip form and concise copy

## Included

- Replaces the sparse New/Edit trip form with destination, date range, and optional name cards. The destination shows existing city artwork after selection; the create/save action sits immediately beneath the fields with a soft disabled treatment.
- Uses a compact initial sheet with expansion and scrolling; accessibility text sizes use a full-height sheet and stacked date fields. Date selection still uses one shared range calendar.
- Keeps saving, cancellation, validation, automatic default naming, and revision checks. Overlong names receive a brief inline explanation.
- Includes the full [copy audit](UX_COPY_AUDIT_20260918.md) from `b276666`: fewer repeated privacy disclaimers and implementation details, with English/Chinese updates.
- Removes the complete flight-lookup explanatory footer from flight entry, as clarified by the user. The Privacy Policy webpage is not changed.

Source commit: `162c2d3`.

## Verification

- iOS 27: creation/persistence/completion and unverified flight entry passed in `/private/tmp/across-trip-form-20260918.xcresult`. Initial failures identified an extra accessibility wrapper on Dates and a test helper placing the text caret in the middle of the wider name field. The wrapper was removed, and the helper now places the caret at the end before replacing text.
- iOS 27 final run: light/dark form and calendar cancellation, maximum accessibility text size, and edit/persistence passed in `/private/tmp/across-trip-form-v2-20260918.xcresult` (3 tests). Together, five distinct Trip workflows passed across the two runs.
- iOS 26.4.1: creation/persistence/completion passed in `/private/tmp/across-trip-form-ios26-20260918.xcresult`.
- Reviewed final empty/selected, light/dark and accessibility screenshots. New labels have Simplified Chinese translations. Prior copy-audit coverage also passed six UI workflows, including Chinese sharing consent.
- No backend changes or deployment.

## Package and Apple delivery

- Production App and Widget: **1.0.4 (17)**; minimum deployment remains iOS 18.
- Xcode 27.0 (27A266a).
- Frozen tracked source: `/private/tmp/across-testflight17-20260918.o6f95f17/source` (1,269 files).
- Archive: `/private/tmp/across-testflight17-20260918.o6f95f17/AcrossUs-1.0.4-17.xcarchive`.
- Signed archive and export succeeded. Production App/Widget signatures and entitlements were verified; local demo is disabled. Frozen source remained unchanged and matched the working production source.
- Exported IPA SHA-256: `99fb3b66bff7cb5d3026f3238b891cd152b1236a744d63bc1e1c8988d2d780c0`.
- Xcode confirmed **Upload succeeded** at **19:06:57 PDT, September 18, 2026**. App Store Connect confirmed upload status **Complete**, **1.0.4 (17)** assigned to **Testers / Internal / 1 tester**, and the bilingual testing notes **Saved**.

Apple build ID: `0379ec59-db83-4d90-b6c2-18a775af0833`.

[TestFlight build page](https://appstoreconnect.apple.com/teams/9b0eb9fa-54ee-4f56-83ae-1e79e3cf4125/apps/6807634842/testflight/ios/0379ec59-db83-4d90-b6c2-18a775af0833)

No new testing group or external beta review submission was created. “Ready to Submit” in the version list is the external beta review state; the existing internal group is assigned.

This is a TestFlight update. The existing App Store submission is not changed.
