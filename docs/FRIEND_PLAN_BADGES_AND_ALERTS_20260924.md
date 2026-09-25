# Friend plan indicators and same-city notification diagnosis

## Client changes

- Friends with an active or upcoming plan visible to the signed-in viewer have a small calendar badge on their city emblem. The badge pulses twice, respects Reduce Motion and stops when the home view is inactive. It adds no new row to the home screen.
- Tapping the friend card opens their profile with shared cities and dates above current-city details. Each plan opens the existing plan detail view. Data comes only from the authorized friend-plan feed; ended, blocked, removed and unavailable plans do not generate badges or profile rows.
- Active Friends refreshes the snapshot and plans once per minute. Newly discovered same-city events younger than five minutes can show an in-app banner even if APNs did not arrive. First successful snapshots after launch/account changes establish a baseline without replaying history. Existing current-city, consent and friendship checks still apply. Snapshot discovery and foreground APNs share the same bounded account-scoped deduplication history.
- Friend details expose notification setup when same-city alerts are on but system permission or device registration needs attention. No permission is enabled automatically.

## Production diagnosis (read-only)

- Examined recipient-specific event/outbox/device delivery records. Production app deliveries failed with `APNs 400: TopicDisallowed`; the equivalent staging-production deliveries were accepted by APNs. A second examined account had no registered devices, so its events had no device delivery rows. No permission state can be inferred from the absence of server device registrations alone.
- Confirmed the server's existing key ID matches the Apple Developer key. Before repair, the Apple key permitted only `com.yangwy30.whereismyfriend.staging` in Production, excluding `com.yangwy30.whereismyfriend`.
- APNs acceptance on an old staging installation is not evidence of notification delivery to the production app or display on a physical iPhone.

## Production repair — September 24, 2026

- After explicit user confirmation, added only `com.yangwy30.whereismyfriend` to the existing Production key, retaining the staging topic. Apple confirmed **Your Key is Updated**. No private key rotation, server secret change, function deployment or app binary update was required for this authorization correction.
- Backed up and requeued exactly one existing failed delivery for the consenting owner's production install. The retry required the expected recipient/device/event, unchanged failure/attempt count, currently matching fresh city updates and no other pending or newly eligible devices. The regular worker retained its final sharing/eligibility check.
- At **September 24, 2026, 9:09 PM PDT** the production delivery became **delivered**, attempts increased from 1 to 2, a new APNs request ID was recorded, and the error cleared. Both staging rows remained at one attempt; no broad historical replay occurred.
- This proves APNs now accepts the production topic. Physical notification display is awaiting the owner's confirmation. The second examined account still needs successful notification permission/device registration on its own iPhone.

## Verification

- 158 iOS unit tests passed, including new remote snapshot banner delivery, late-push deduplication, history/consent/account filters and background suppression.
- Friend badge → selected friend's shared cities → plan detail UI test passed on iOS 27. Checked home and profile screenshots.
- These client changes shipped to the existing internal TestFlight group in [1.0.4 (21)](TESTFLIGHT_1_0_4_21.md). This upload did not replace build 20 in its existing App Store review submission.
