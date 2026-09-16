# Personal travel plans and upcoming overlaps — 2026-09-11

## Delivered

- `You → Sharing & City → Travel plans` is the always-available plan entry. Friends shows `Together soon` only when there are eligible date overlaps; `Here together` only when there are eligible current-city matches. Hidden cards do not retain padding. Explicitly opened historical/unavailable alerts remain dismissible with `Back to Friends`, which restores match-only visibility.
- Create/edit/delete multiple personal plans, upcoming/past lists, city search, destination-local calendar dates, explicit friend audience and optional reminders. No trip name or flight required. Audience and reminders default to private/off.
- Friend selection has a separate screen, keeping the editor short. City rows are fully tappable. Dates expand to a native calendar rather than persistent pills or shortcut chips.
- `Use dates from a Trip` prefills dates only after confirming the destination; audience and reminder consent are never inherited. Trip membership does not assert personal presence.
- Cloud-backed, account-scoped own-plan cache; no cached friend overlaps. Failed mutations are not presented as successful or queued. Revision checks protect concurrent edits; generation and mutation tokens reject stale reads after save/account switch.
- Same city/country/region/time zone + inclusive local-day intersection + reciprocal explicit plan audiences + accepted friendship + no blocking. Different country/region namesakes do not match. The relationship-bound audience FK prevents removing/re-adding a friendship from restoring old grants.
- Expand `Together soon` to choose a friend/date overlap. Details explicitly describe planned dates, not live location. Say hello opens a share draft, never sends automatically.
- Upcoming pushes use `upcoming/<32-hex-id>` links. Warm/cold links route to Friends and re-fetch current authorized overlap data; missing/revoked matches show an unavailable state. Foreground banners honor notification-preview privacy, deduplicate per account, and remain until dismissed with VoiceOver.

## Backend and privacy

App project: `cdhpaujazbuppbxyhjxq` (existing shared Staging/Prod project).

- Applied only migration `20260911010000_personal_travel_plans`; no bulk db push or unrelated pending migrations.
- Tables: own plans, explicit audiences, per-device delivery queue. Direct anon/authenticated table and RPC access denied. API supplies the actor only from verified Supabase Auth.
- API v17; push-worker includes lazy, single-flight provider-token signing so concurrent deliveries reuse one token, plus a 15-second APNs request timeout. Existing current-city and trip worker schedules retained. New plan reminders reuse the existing every-minute push worker and APNs transport; no flight API quota consumed.
- Push requires personal-plan opt-in, per-friend same-city alerts enabled, an eligible registered device and overlap start within the next 14 local days. The sender revalidates visibility, account/device ownership and dates immediately before delivery. Dedup is per recipient/device/semantic interval; retries are leased and bounded. Already delivered notifications cannot be recalled.
- During verification, APNs signing failed because the configured private key had an unrecognized envelope. The local Apple key was validated as P-256 and its Key ID hash matched the configured Key ID. Repaired **only** `APNS_PRIVATE_KEY`; team ID, key ID and token-encryption key unchanged. Temporary secret file removed. Protected signing-only probe returned HTTP 200, `signingReady: true` (request 26116). No test notification was sent to real users.

## Verification

- Match-only visibility follow-up: **13/13 passed** (eight current-city policy tests and five UI tests). Covers empty upcoming visibility, plan creation from You, match appearance, share revocation, closing unavailable details, current-city sharing-off hiding, and both alert cold-launch paths. Results: `/private/tmp/wif-match-visibility.xcresult` and `/private/tmp/wif-no-match-cards.xcresult`. No release upload in this follow-up.
- Backend: **50/50 tests passed**, including HTTP auth/identity injection, reciprocal visibility/revocation, date intersections, optimistic revisions, device reassignment, delivery dedup and lease checks, idle worker, signing-only diagnostics and concurrent signing coalescing, plus existing trip/auth regressions. Final push-worker deployment succeeded after this signing fix.
- Hosted smoke: **8/8 checks passed** with two isolated temporary Auth accounts; private defaults, own-only access, two-way intersection, stale edit rejection, revocation and deletion. Both accounts and cascading data removed; actual account count returned to four and personal-plan count to zero.
- New Swift model/library tests: private defaults, malformed calendar dates, time zones/DST, strict links, CRUD/revocation, account isolation and out-of-order reads. Five passed.
- Full plan UI workflow passed in `/private/tmp/wif-travel-ui-v5.xcresult`: select city, explicitly select Lin, save, view overlap, revoke audience, verify overlap disappears.
- Final client regression: **85/85 passed** in `/private/tmp/wif-travel-final-regression.xcresult` (all client unit tests and seven UI regressions, including both invitation cold-launch cases and current/upcoming alerts).
- Real MapKit search for `Palm Springs California` passed from the Profile entry. It selected Palm Springs with structured country/region/time-zone data, not a demo-list fallback. Screenshot: `personal-travel-preview/palm-springs.png`.
- iPad Air 11-inch (M4): the create/share/display/revoke UI test also passed, `/private/tmp/wif-travel-ipad.xcresult`.
- Final scheduled responses at 21:40 UTC: current/upcoming push worker HTTP 200 (`upcomingError: false`), flight worker HTTP 200 (idle). Existing production-environment delivery records for the Staging bundle include ten accepted APNs sends after the signing repair; these were existing authorized queued notifications, not synthetic test pushes.

Private backup: `.migration-backups/app-predeploy-mH0zz7` (public data/schema metadata and ledger, not a full Auth/Storage disaster-recovery backup). Hosted smoke report: `.migration-backups/travel-smoke-KDpdr6/report.json`. No credentials belong in this document or source control.

## Release boundaries / known limits

- No TestFlight upload or App Store submission in this change. Existing installed binaries do not acquire the new UI until a new client build is installed.
- Physical-device lock-screen receipt with two signed-in people still requires acceptance testing; simulator routing and a successful signing probe do not prove device permissions, provisioning, or APNs delivery.
- Existing **sandbox** development-device records report `BadEnvironmentKeyInToken`; production-environment Staging-bundle deliveries succeed with the current key. Do not switch a sandbox device to production to bypass this. Supporting direct Xcode development-device push additionally needs a sandbox-capable Apple key and environment-specific credential selection. App Store main-bundle delivery has not been certified by the Staging-bundle receipts.
- City search uses MapKit structured city/region/country/time-zone results, not the airport shortlist. Localized city/region aliases can still yield missed matches; this is not a universal geographic-ID database. There is no fallback that silently invents a destination.
- Match refresh is foreground/pull-to-refresh and every minute while Friends is visible; it is not a realtime subscription. Server delivery always checks current consent regardless of client refresh timing.
- Keep release privacy disclosures current for personal future dates and per-plan audiences before publishing the new binary.

MapKit time zone reference: https://developer.apple.com/documentation/mapkit/mkmapitem/timezone
