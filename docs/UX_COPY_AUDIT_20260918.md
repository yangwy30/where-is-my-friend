# UX copy audit — September 18, 2026

## Goal

The user asked for less repetitive privacy messaging and fewer explanations of implementation details. Everyday screens should help people find friends and make plans without repeatedly defending how the app works.

## Findings and changes

| Area | Before | Result |
| --- | --- | --- |
| Same-city details | “Based on shared city updates · not live location” | Removed the disclaimer; kept the city, people, update age, and Say hello action. |
| Upcoming overlap | A second “not live location” explanation | Removed; the plan dates and overlap duration provide context. |
| Friend details / profile / city sharing | Repeated “no precise location,” “never uploaded,” and tracking disclaimers | Removed recurring footers; retained the sharing controls and permission guidance. |
| Friend plans | “Private until you choose to share,” repeated “Shared with you,” long empty/copy explanations | Short action-oriented copy: “Add a city and your dates,” “Review your plan before saving.” |
| Plan editor | Long descriptions of mutual sharing and automatic announcements | Shortened to what each switch controls. The off state still explains mutual sharing and matching dates; the reminder timing remains visible. |
| Onboarding | “Your city. Your privacy.” | “Your city. Your choice.” with one line about choosing friends and pausing. |
| Sign-in | Supabase, session refresh, local repository verification | Removed the production implementation footnote; a simple sample-data label remains in demo mode. |
| Trip maps / flight entry | “not live aircraft positions,” provider name, signed-in-account explanation | “Airport routes,” “Your flight,” and a short schedule lookup instruction; example and unverified labels remain. |
| Widget settings | Private placeholder and system redaction terminology | Describe visible results: hide names/cities, choose widget content, Home Screen and Lock Screen scope. |
| Privacy & data | App Group cache and server/session terms | Plain descriptions of the data and deletion result, in the dedicated information screen. |

## Information retained

- Who can see a city or plan, “Only me,” selected-friend controls, and mutual-plan matching behavior.
- Location permission purpose, optional background access, and one contextual city-versus-precise-location explanation at permission setup.
- Remove/block/delete consequences, disabled sharing and unavailable/stale data states.
- Notification choices and timing, demo itinerary labels, and unverified-flight status.
- Privacy Policy access and data categories on the dedicated Privacy & data screen.

This is presentation-only: sharing defaults, audiences, location handling, storage, reminders, and backend APIs have not changed. No notifications or announcements are sent by these copy edits.

## Localization and verification

- Added/updated Simplified Chinese translations for the new copy and removed replaced catalog entries.
- Onboarding title/subtitle use localizable keys so the revised text is translated instead of rendered as a literal English string.
- App and Widget compiled successfully with Xcode 27. Six existing iOS 27 UI tests passed: same-city details, English friend-plan copying, Chinese sharing-consent persistence, onboarding, profile/widget settings, and unverified flight entry. Result: `/private/tmp/across-copy-audit-20260918.xcresult`.
- Reviewed real simulator screenshots of the expanded same-city card and Chinese plan editor. The repeated disclaimer is gone; names, city, update age, sharing controls, and reminder timing remain legible.
- Catalog validation found no duplicate keys, missing Chinese translations in changed entries, or mismatched format placeholders. `git diff --check` passed.

## Copy guidance

Lead with the user's action or result. Avoid repeated negative claims (never stored, not live, no tracking) on everyday cards. Explain sharing scope at the setting that changes it. Keep technical infrastructure names out of normal product flows. Keep freshness, example/unverified status, and destructive-action consequences clear.

## Release status

Subsequently released to the existing internal TestFlight group in [1.0.4 (17)](TESTFLIGHT_1_0_4_17.md), alongside the compact Trip form and full removal of the flight-lookup footer. Build 16 predates these copy edits.
