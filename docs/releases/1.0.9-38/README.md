# Across Us 1.0.9 (38) — internal TestFlight

For the user to try the new sign-in options on a real phone. Not submitted for review.

## What's in it

- **Email code and Google sign-in**, under Sign in with Apple.
  - Email: enter an address, get a 6-digit code (valid 10 minutes), type it in. Codes come from `Across Us <noreply@acrossus.app>` via Resend.
  - Google: system web sign-in with PKCE and a hashed nonce, then Supabase `signInWithIdToken`. No Google SDK. iOS client in Google Cloud project `across-us-511906`.
- **84 more US city emblems** and metro coverage for about 560 nearby cities (from `fix/city-emblem-plinths`, 9eca6b6).
- **You tab redesign** into grouped cards (from `ui/you-tab-redesign`), with the 1.0.9 "Finish setting up" card between the header and the first group.
- **Fix:** the You tab Edit button now has a full 44 pt tap area (was 29 pt).
- Everything in 1.0.9 (37): setup checklist, tighter same-city header spacing.

## Production changes made for this build (Supabase cdhpaujazbuppbxyhjxq, with the user's approval)

- Google provider on, client ID `891897795730-7v247tvol6u60hi1bfaarr85cf91gg74.apps.googleusercontent.com`, nonce check kept.
- Custom SMTP through Resend (domain acrossus.app verified; DKIM, send CNAMEs and DMARC added in Cloudflare).
- Email OTP 6 digits / 600 s; magic-link and confirmation templates show the code (English and Chinese); 30 emails per hour.
- Apple sign-in unchanged.

## Tests

All 272 unit tests pass. Full UI suite (111 tests) on iPhone 17 Pro, iOS 26.4: three failures were test timing on iOS 26 or an outdated assertion and are fixed. Still failing: `testAuditIntegratedHeaderShowsPeopleAndOpensFriend` (tapping a friend in the same-city sheet doesn't open the detail page under XCUITest). It also fails on 1.0.9 (37). It is not yet known whether real taps are affected; the user is checking on a phone.

## Build

Built from tag `v1.0.9-38` (fbac82b) on `feature/email-google-sign-in`. Signed the same way as 1.0.9 (37): Apple Distribution, `aps-environment` production, `applinks:acrossus.app`, `get-task-allow` false. Uploaded October 18, 2026.
