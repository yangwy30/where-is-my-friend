# Across Us 1.0.6 (28) — TestFlight available; App Store submitted

The user authorized TestFlight upload and App Store submission, with an audit of listing text and previous review messages.

## Verified outcome — October 11, 2026

- Apple received build 28; Xcode reported Upload succeeded at 13:01 PDT. Processing completed. Build ID: cc636798-ff66-403c-a940-288c7e99fa10.
- The existing internal Testers group (1 tester) lists 1.0.6 (28) as **Testing**. No external tester group was added. The tester's latest installed version was still build 27 when checked; build 28 is available to update.
- App Store submission completed at **14:09 PDT**. Status: **Waiting for Review**. Submission ID: 91789c76-1cd5-4758-bd65-3feb088e10d2.
- Existing automatic release after approval, immediate availability to all users after release, and existing ratings are preserved. Waiting for Review does not mean approved or publicly released.
- English and Simplified Chinese descriptions, promotional text, What's New and reviewer notes have been saved. Eight current screenshot designs per locale are assigned at both 1206×2622 and 1284×2778. The latter replace the explicitly assigned legacy large Face ID screenshots. Other device sizes use inherited/scaled assets.
- TestFlight descriptions are updated in English and Simplified Chinese. Beta reviewer notes match the current App Store review paths; build 28 What to Test includes both languages.
- The nine published App Privacy data types were reviewed against current behavior; the public privacy URL is unchanged.

[App Store submission](https://appstoreconnect.apple.com/apps/6807634842/distribution/reviewsubmissions/details/91789c76-1cd5-4758-bd65-3feb088e10d2) · [Apple receipt](distribution-receipt.json) · [Submission screenshot](evidence/app-store-waiting-for-review.jpg) · [TestFlight screenshot](evidence/testflight-testing.jpg)

## Verified package

The initial export without archive entitlements was rejected by local validation and never uploaded. The archive was prepared with the exact Release entitlement settings, then Xcode applied Apple Distribution signing. No developer certificate was revoked.

Final validation confirms matching App/Widget 1.0.6 (28), team 93RUQ2A6KX, production APNs, Apple sign-in, the shared App Group, debugging disabled, matching privacy manifests, production backend configuration and Demo disabled. Source hashes match the frozen manifest.

See [package verification](package-verification.json) and [source manifest](source-manifest.json).

## Store content and public policy

[Metadata audit](metadata-audit.md) records the live 1.0.5 listing and the historical beta 2.1(a) access request. [metadata.json](metadata.json) contains the new bilingual descriptions and review/test notes. The listing does not promise in-app chat, live device/aircraft tracking, instantaneous updates, or automatic sharing to future friends.

New screenshots: [October 11 set](../../app_store_screenshots/2026-10-11/README.md). English main screenshots were uploaded through the native picker. After the user's explicit file-access permission confirmation and browser coordination, the Chrome extension uploaded the Chinese set and both legacy-size replacements successfully. Prior upload/session interruptions are resolved.

The privacy-only update was published through the user's signed-in GitHub session as commit b56ec1c11a821354a07d9317e1f5a77689fc64fb. [Privacy Site run 13](https://github.com/yangwy30/where-is-my-friend/actions/runs/38174979989) completed successfully. The public HTTPS response matches local site/privacy/index.html byte-for-byte (SHA-256 in the receipt). It clarifies same-city history, the new-plan default audience with opt-outs, Apple location/geocoding services, and Chinese notification details. The earlier isolated local commit ec99904 was not pushed. No app source or backend deployment was made by this policy publication.

## Existing validation and limits

The preceding app audit passed 256 unit tests, 65 distinct native UI methods on their last executions, and 146 local backend tests. Five keyboard-layout warnings remain documented in [the full audit](../../ui-deep-review-20261010/README.md). Release preparation changed the production build number and corrected the location-permission purpose text; it did not add app functionality. Fresh marketing captures passed for English and Chinese (the Chinese accessibility-harness failure passed on retry). Real-device Apple sign-in, background APNs delivery, and weak-network behavior were not freshly certified by this release submission.
