# 1.0.6 (28) listing audit — 2026-10-11

The user authorized TestFlight upload and App Store submission, with current descriptions and prior message review.

## Confirmed online state

- Current App Store version: 1.0.5 (25), Ready for Distribution.
- Latest App Review submission 1e70df43-404b-42f5-b502-fbef60c474f3: Review Completed, app version Approved. Submitted 2026-09-27 22:29 PDT.
- Existing release policy: automatic release after approval. Preserve it.
- Existing English title: Across Us: Friends & Trips. Preserve title, subtitle, keywords, pricing and territories unless a concrete submission requirement changes.

## Prior Apple message inspected

The 2026-09-10 TestFlight submission for 1.0.0 (4), message dated 2026-09-11, was rejected under 2.1(a). Apple could not access the full feature set and requested usable test access or a demonstration mode. The current production app uses Sign in with Apple; do not invent shared credentials or disclose the owner's Apple credentials. Update review notes with the current own-account signup and two-account feature test paths. Later official app versions were approved; do not misreport the old beta rejection as the latest App Store decision. No reply to the old message was sent.

Thread: https://appstoreconnect.apple.com/apps/6807634842/distribution/reviewsubmissions/threads/b77303c9-aa84-3b67-ae61-0e1831df05a0

## Corrections prepared

- Remove same-city Say hello/message sending and the old large-card claim.
- Use My travel plans / Friends' travel plans / Shared trips, with exact Chinese UI names.
- Explain current accepted/unblocked friends selected by default, opt-outs, 100-person limit, unchanged saved audiences, and separate full-plan browsing versus overlap matching.
- Keep current-city sharing separate from personal-plan audience and shared-trip membership.
- Describe flight maps as airport routes from added flights, not device tracking or live aircraft positions.
- Avoid instantaneous background/widget/push or complete flight-data guarantees.
- Explain same-city events/stay periods and shared-trip names/flights that may remain after account deletion.
- Correct on-device-only geocoding claims: CLGeocoder may use Apple network services; precise device coordinates are not sent to Across Us servers. The actual location permission purpose string was corrected in the binary.
- Prepare bilingual policy parity for existing device timezone/language and 9 AM flight-planning reminders. Public policy edits are still local until deployment is verified.

Primary references: https://developer.apple.com/documentation/corelocation/clgeocoder and https://developer.apple.com/app-store/app-privacy-details/

Prepared fields are in metadata.json. Saving fields, screenshot uploads, build selection and submission must be verified in App Store Connect; preparation is not publication.
