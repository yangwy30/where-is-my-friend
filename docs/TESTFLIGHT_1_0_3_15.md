# Across Us 1.0.3 (15) — audited city archetype artwork

User requested an audit of the other implementation, fixes as needed, then TestFlight release.

## Reviewed and included

Incoming commits `3cef555` and `f31d183` add city archetype art and fallback rules. See [audit findings and mitigations](CITY_ARCHETYPE_AUDIT_20260917.md).

- Retains five new illustration families: valley/plains, modern suburb, surf coast, desert/adobe and historic brick.
- Fixes state-name/code inconsistency, missing-metadata assumptions, unscoped curated names and substring keyword matches.
- Removes the defective alpine chalet imageset (transparent holes in the roof) and uses the intact generic neighborhood for that fallback. Imagegen repair attempts yielded opaque checkerboard backgrounds and were rejected; none of that generated output is shipped.
- Keeps unknown/private-location artwork separate and adds recovery to the generic bitmap if a specialized fallback asset cannot load.
- Existing curated landmarks, actual city labels, same-city matching, Trip lifecycle and flight planning reminders remain unchanged.

## Verification

- Xcode 27.0 (27A266a), iPhone 17 Pro Max / iOS 26.4.1: **144 unit tests and 2 distinct UI workflows passed** (`/private/tmp/across-archetype-audit.xcresult`).
- The comparison test initially inherited a previously saved dark theme. A test-only correction explicitly selects Solar Jade before its first screenshot; the corrected light/dark workflow passed in `/private/tmp/across-archetype-light-dark.xcresult`. Screenshots were visually inspected.
- Asset loading/transparency, state aliases, cross-country/state namesakes, incomplete metadata, whole-word matching, shared artwork with different geographic identity, and hidden cached geography are covered. Repository secret scan passed.
- Frozen build source: `/private/tmp/across-testflight15-20260917.d3hm2wli/source`; 1,263 files. Its manifest stayed unchanged during archive/export, and current production App/Widget source matches it. The subsequent test-only theme setup change does not alter packaged code.
- Production App `com.yangwy30.whereismyfriend`, Widget `com.yangwy30.whereismyfriend.widget`, team `93RUQ2A6KX`. Both Release targets report **1.0.3 (15)**; local demo is disabled. Other configurations retain their versions.
- Signed archive/export and signature verification succeeded.
- Exported IPA SHA-256: `6d6e7255156bc9727a64f3c99db736f987b4cf783a2a9f36ce8882626ea4ed44`.

## Backend

No backend changes or deployment in this task. Read-only inspection confirmed api v23 / push-worker v18 / trip-worker v4, as released with build 14. No business data or notification enrollment was changed.

## Apple upload

Xcode confirmed **Upload succeeded** at **18:17:42 PDT, September 17, 2026**. App Store Connect confirmed upload status **Complete**, version **1.0.3 (15)**, and **Testers / Internal / 1 tester**. Chinese/English What to Test notes were saved; the UI confirmed **Saved**. No new group, external Beta App Review or public App Store submission was created.

Apple build ID: `79be34de-6d5e-4412-936a-c8ce07badcdb`.

Build page: https://appstoreconnect.apple.com/teams/9b0eb9fa-54ee-4f56-83ae-1e79e3cf4125/apps/6807634842/testflight/ios/79be34de-6d5e-4412-936a-c8ce07badcdb
