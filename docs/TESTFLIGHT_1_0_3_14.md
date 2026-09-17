# Across Us 1.0.3 (14) — quiet sync and flight planning reminders

User-authorized TestFlight release, September 17, 2026.

## Included

- New Trip UI retains Delete trip for creators and Leave trip for members; removes Cancel trip. Existing cancelled records/legacy clients remain compatible.
- Routine sync/registration banners and saved-to-account footers removed; actionable errors remain.
- Recipient-local 9 AM flight-planning reminders after opening Trips, member nudges with shared 24-hour cooldown, per-trip opt-out and send-time eligibility checks. No assumption that a missing flight means a ticket was never purchased.
- All prior city artwork, privacy, date-range and Trip lifecycle work remains integrated.

## Build and verification

- Source commit before version bump: `716b185`. Frozen input: `/private/tmp/across-testflight14-20260917.leryzdyq/source`; manifest covers 1,242 versioned files and was verified unchanged after build.
- Xcode 27.0 (27A266a), production App `com.yangwy30.whereismyfriend`, Widget `com.yangwy30.whereismyfriend.widget`, team `93RUQ2A6KX`.
- Release App/Widget both **1.0.3 (14)**; other configurations unchanged. Archive, signed export and signature verification passed; local demo is disabled.
- **107 backend tests, 141 iOS unit tests, 3 UI workflows passed** from frozen source. UI covers member reminder/opt-out, creator removal/delete, and quiet notification settings. Results: `verification.xcresult`, `verification.log`, `backend-tests.log` in the release folder.
- Exported IPA SHA-256: `9a79171c186ba877e6a77170fd93625284c1136018a2cdf1f9ca787dce691adc`.

## Backend deployment

- Private database/schema/ledger backup: `.migration-backups/app-predeploy-7CiYSa`; SHA-256 `b209a550b7533a822ee706d0c47ce11320715dc4610d83c9571a2743a6221d11`. Auth/Storage/secrets excluded; not a full disaster-recovery backup.
- Backed up existing API and push-worker source. Applied only `20260917010000_trip_booking_reminders`, guarded by ledger baseline, live snapshot function fingerprint and lock/statement timeouts.
- Deployed **api v23** (JWT verification remains enabled) and **push-worker v18** (existing worker-secret authentication). **trip-worker v4** remains unchanged. Existing cron schedules retained; no new cron job added.
- Hosted verification passed in a fully rolled-back transaction with synthetic app-only profiles/device records. Checked recipient-local morning time across time zones, duplicate prevention, private/localized previews, opt-out/re-enable, flight addition, delete cleanup and service-role-only RPC access. No Auth account was created and no synthetic APNs was sent.
- Before and after: **6 users / 1 Trip / 2 flights / 4 memberships**. After rollback, reminder contexts and events were both zero; no existing account was enrolled automatically.

- Scheduled push-worker responses after deployment returned **HTTP 200**, no timeout, and `bookingReminderError=false`. The reminder context HTTP endpoint rejected an unauthenticated request with **401**.

## Apple upload

Xcode confirmed **Upload succeeded** at **14:31:31 PDT, September 17, 2026**. App Store Connect confirmed build 14 upload status **Complete**, with **Testers / Internal / 1 tester** attached. Apple build ID: `a5d2773e-f0a9-45f0-b096-021bb9b06601`. Build-specific Chinese/English What to Test notes were saved; the UI confirmed **Saved**. No new tester group, external Beta App Review or public App Store submission was created.

Build page: https://appstoreconnect.apple.com/teams/9b0eb9fa-54ee-4f56-83ae-1e79e3cf4125/apps/6807634842/testflight/ios/a5d2773e-f0a9-45f0-b096-021bb9b06601

## Device acceptance

Use disposable test trips to verify reminders on actual notification-enabled devices. The morning scheduler follows the latest reported device time zone and the 9–10 AM delivery window; APNs/Focus/connectivity can affect receipt. Already delivered notifications cannot be recalled.
