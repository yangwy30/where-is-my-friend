# Across Us 1.0.7 (31) — App Store submitted

The user tested build 31 on TestFlight and asked for it to be submitted for App Review on October 15, 2026.

## Verified outcome — October 15, 2026

- Build 31 was archived unsigned from a clean worktree at tag `v1.0.7-31` (7c85741), re-signed with cloud Apple Distribution signing, and uploaded at 13:34 PDT. Signing check: Apple Distribution (93RUQ2A6KX), production APNs, shared App Group, `get-task-allow` false. App and widget both report 1.0.7 (31). Artifacts are in `build/release-1.0.7-31/` (git-ignored).
- Processing completed. Build 31 showed **Ready to Submit** and was assigned to the internal Testers group.
- Version 1.0.7 was created in App Store Connect, and build 31 was attached to it.
- App Store submission completed at **17:58 PDT**. Status: **Waiting for Review**. Submission ID: 8177d260-97e2-4313-ab69-c713d60af685.
- Release settings are unchanged from 1.0.6: automatic release after approval, release to all users at once, and existing rating kept.

[App Store submission](https://appstoreconnect.apple.com/apps/6807634842/distribution/reviewsubmissions/details/8177d260-97e2-4313-ab69-c713d60af685)

## What changed since 1.0.6 (28)

- 9fe4f8b: a home refresh no longer cancels the city check while the app is open. This bug was live in 1.0.6.
- aacee9d: notification prompt during onboarding and on a one-time Friends card. A trip reminder that can't be delivered now offers a message through the share sheet.
- UI polish: city emblems across Trips and You, key actions kept within reach, readable return flights, unified person colours, and the automatic city check shown on screen.

## Store content

- Screenshots: the [October 14 set](../../app_store_screenshots/2026-10-14/README.md). Seven per locale replace the eight 1.0.6 images in both explicitly assigned slots: 6.3" (1206×2622) and 6.5" (1284×2778). Other sizes scale from these. The order was checked in Media Manager after upload.
- Description, promotional text and keywords come from [listing.json](listing.json), saved in English and Simplified Chinese. The name and subtitle are unchanged.
- What's New: [English](en-US-whatsNew.txt) and [Chinese](zh-Hans-whatsNew.txt). The Chinese text avoids promising that notifications arrive on time.
- [Review notes](review-notes.txt) are the 1.0.6 notes with the optional notification prompt added to path 6, and with the version summary rewritten for 1.0.7.

Every saved field was checked by reloading the page.
