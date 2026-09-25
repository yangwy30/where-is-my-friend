# Friend plan indicators and same-city notification diagnosis

## Client changes

- Friends with an active or upcoming plan visible to the signed-in viewer have a small calendar badge on their city emblem. The badge pulses twice, respects Reduce Motion and stops when the home view is inactive. It adds no new row to the home screen.
- Tapping the friend card opens their profile with shared cities and dates above current-city details. Each plan opens the existing plan detail view. Data comes only from the authorized friend-plan feed; ended, blocked, removed and unavailable plans do not generate badges or profile rows.
- Active Friends refreshes the snapshot and plans once per minute. Newly discovered same-city events younger than five minutes can show an in-app banner even if APNs did not arrive. First successful snapshots after launch/account changes establish a baseline without replaying history. Existing current-city, consent and friendship checks still apply. Snapshot discovery and foreground APNs share the same bounded account-scoped deduplication history.
- Friend details expose notification setup when same-city alerts are on but system permission or device registration needs attention. No permission is enabled automatically.

## Production diagnosis (read-only)

- Examined recipient-specific event/outbox/device delivery records. Production app deliveries failed with `APNs 400: TopicDisallowed`; the equivalent staging-production deliveries were accepted by APNs. A second examined account had no registered devices, so its events had no device delivery rows. No permission state can be inferred from the absence of server device registrations alone.
- Confirmed the server's existing key ID matches the Apple Developer key. The Apple key configuration permits only `com.yangwy30.whereismyfriend.staging` in Production, excluding `com.yangwy30.whereismyfriend`.
- Prepared adding only the production app topic to the existing key. Saving this permission expansion is pending explicit user confirmation. No new key, revoked key, broad historical replay or test push has been performed.
- APNs acceptance on an old staging installation is not evidence of notification delivery to the production app or display on a physical iPhone.

## Verification

- 158 iOS unit tests passed, including new remote snapshot banner delivery, late-push deduplication, history/consent/account filters and background suppression.
- Friend badge → selected friend's shared cities → plan detail UI test passed on iOS 27. Checked home and profile screenshots.
- These client changes are source changes after App Store build 20; they have not been uploaded to TestFlight or included in its existing review submission.
