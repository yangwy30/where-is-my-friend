# Worker-load experiment and APNs retry-loop repair — September 12, 2026

## Final deployed decision

**Do not retain the concurrency-3 / 20-second flight-stagger experiment.** It did not show clear latency benefit. Original worker scheduling and parallelism were restored. Keep the narrower, evidence-backed APNs environment-error retry fix.

Final worker versions: `push-worker` **15**, `trip-worker` **4**, both ACTIVE with their original worker-secret authentication (`verify_jwt: false`). App `api` remains **18**, ACTIVE with JWT verification enabled. No Apple credentials, device permissions, flight API quotas, database schema, TestFlight build or App Store submission changed.

## Experiment, and why it was withdrawn

Temporarily deployed concurrency 3 for notification pipelines and a 20-second Edge Runtime delay before scheduled flight claims. The delay did not hold a database connection or lease. Experimental versions were push 14 / trip 3; all 70 experimental backend tests passed.

Read-only probes with the same anonymous rejection-path request:

| Measurement | Probes | Over 2 seconds | Longest wait |
| --- | ---: | ---: | ---: |
| Experimental original minute boundaries | 48 | 3 | 5.751 s |
| Experimental shifted flight start | 24 | 0 | 0.531 s |
| Original scheduling after retry-loop repair | 48 | 1 | 5.585 s |

The 3 slow boundary probes during the experiment were comparable to the earlier A/B/A results; there was no basis to claim concurrency 3 fixed the issue. Experiment-only source and tests are preserved in `/private/tmp/wif-worker-load-stage.Q0IrQl`; the active local source was restored rather than leaving an undeployed experiment ready for accidental publication.

Experimental measurement report: `.migration-backups/worker-load-verification-Hs36EA/report.json`.

## Concrete defect found

Queue inspection found **25 pending notifications tied to one sandbox development device**, all with `APNs 403: BadEnvironmentKeyInToken`. The oldest was created August 25 at 04:33 UTC. One delivery had reached **4,576 attempts**. This was not 25 production users and was not a traffic-volume explanation.

The previous APNs classifier treated all HTTP 403 responses as retryable. The same-city delivery queue had no attempt ceiling for that path, so a provider key/environment mismatch could repeatedly occupy scheduled work without any chance of recovery until configuration changed.

The final classifier now treats these explicit environment mismatch reasons as terminal for **that delivery**, while retaining the device:

- `BadEnvironmentKeyInToken` (observed in this project)
- `BadEnvironmentKeyIdInToken` (documented APNs spelling)
- `BadCertificateEnvironment`

The result is `failed`, `disableDevice: false`, no retry delay. Transient 429/5xx failures and expired-provider-token recovery remain retryable. Other 403 handling was not broadly reclassified.

This does not repair the sandbox signing configuration or make sandbox push delivery work. It prevents the same invalid notification from retrying forever. Production credentials were not altered. [Apple's APNs response documentation](https://developer.apple.com/documentation/usernotifications/handling-notification-responses-from-apns) identifies an environment/key mismatch as a configuration problem, distinct from transient service failures.

## Historical queue repair

After normal scheduled processing had already handled some jobs under the new policy, **18 remaining unclaimed jobs** were backed up and finished through the existing `wif_complete_notification_delivery` RPC. Repair predicates required:

- exact snapshot IDs and attempt counts;
- pending, unclaimed delivery;
- sandbox device;
- exact recorded `APNs 403: BadEnvironmentKeyInToken` error;
- at least eight prior attempts.

Locked/in-flight or concurrently changed rows were skipped. No APNs request was sent by the repair script. Delivery records were marked failed, not deleted; device disabling was false; normal outbox completion logic was preserved. This is not a claim that these notifications were delivered successfully. Any future requeue after configuration repair would be a separate deliberate action, especially since these notifications are old.

Backup and repair output: `.migration-backups/sandbox-retry-repair-GPt736/`. Final checks found **zero pending deliveries bearing that environment error**. A snapshot after the repair still showed two other pending retries; do not call the entire queue empty based only on the environment-error count.

## Verification and remaining limitation

- **66 backend tests passed**, including explicit environment-error classification and actual worker-handler completion behavior (failed job, exactly one send attempt, device not disabled).
- Original cron schedules and command hashes remain unchanged and active: push every minute, flight every five minutes. No diagnostic recovery job remains.
- Post-repair probe: 48 requests over two minute boundaries, all reached the expected anonymous rejection outcome. One required retry and took 5.585 seconds. Its server log confirms `auth_user` 504 after 5,048 ms, upstream request `01a093c8-6cfe-74e3-9ac1-f5ac33d59aef`, outer request `01a093c8-6c34-7bbc-a8e1-6833f0b6b228`, at September 12 04:03 UTC.
- Therefore the retry-loop defect is fixed, but **the original intermittent gateway timeout is not fully resolved**. The small before/after samples do not establish the loop as the sole cause or quantify a reliable improvement.
- This probe does not test native Apple authorization or actual phone notification receipt. The previously prepared client spinner/error-state fixes still require a new client release.

Final measurement report: `.migration-backups/worker-load-verification-68bmhb/report.json`.
Pre-experiment worker backup: `/private/tmp/wif-worker-load-before.6nif1i`.
Final deployment staging directory: `/private/tmp/wif-retry-fix-stage.pSf022` (original workers plus the narrow `push-security.mjs` fix).

Next investigation should use the remaining exact gateway request ID and, if needed, a separately approved controlled test of empty-queue cron traffic versus background-task execution. Do not repeatedly lower normal delivery throughput or claim the observed reduction proves the underlying fault is gone.
