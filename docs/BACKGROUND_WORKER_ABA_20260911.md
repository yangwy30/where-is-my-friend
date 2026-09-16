# Background worker A/B/A comparison — September 11, 2026

## Outcome

The experiment supports investigating background-task bursts as a contributor to upstream Auth latency. It does not prove the precise contention mechanism or which worker is responsible. No permanent schedule, concurrency, database-size or region changes were made.

| Phase | Requests | Requests with confirmed upstream timeout | Upstream timeout attempts | Longest client wait | Final API timeouts |
| --- | ---: | ---: | ---: | ---: | ---: |
| A1: workers running | 48 | 2 | 3 | 11.923 s | 1 |
| B: workers paused, after drain | 48 | 0 | 0 | 2.151 s | 0 |
| A2: workers restored | 48 | 3 | 3 | 6.305 s | 0 |

Counts above use correlated server `upstream_failure` events, not latency alone. Four of the five affected requests recovered on the bounded retry. One A1 request failed both attempts. Its first attempt hit our 6.5-second transport deadline; its second received a gateway 504. One B request and one A2 request took slightly over two seconds without an upstream timeout event.

## Protocol

- Same API deployment before/after: version **18**, JWT verification enabled.
- Same `GET /functions/v1/api/v1/bootstrap` rejection-path request, anonymous project JWT, no user session. Auth must reject it; the expected HTTP outcome is 401. This is not an Apple-login success-rate test and does not execute a profile write.
- Each phase contains two minute-boundary windows, each with 12 rounds and one concurrent request to each of `us-east-1` and `us-east-2`, followed by a one-second interval. The actual returned function regions were recorded.
- 144 total probes. Header marker: `x-client-info: wif-worker-aba-diagnostic`. Exclude these expected rejections from user-login incident analysis.
- No production code deployment during the comparison. No real account/profile data was changed, no temporary account was created, and no manual notification or flight lookup was sent.

## Intervention and restoration

Only active flags for the exact existing jobs changed:

1. `wif-push-worker-every-minute`, job 1, original command hash `6aad6f685a1daf460ca822f178a7b1f2`.
2. `wif-trip-worker-every-five-minutes`, job 2, original command hash `988751f59a19d9153dcbce5d40d3f735`.

Paused at approximately **2026-09-12 03:31:25 UTC / Sep 11 23:31:25 EDT**. Waited 90 seconds to drain existing invocations; prior observed maximum worker execution was approximately 12.5 seconds. Restored at **03:34:20 UTC / 23:34:20 EDT**, a pause of approximately **2 minutes 56 seconds**.

A DB-side self-removing recovery job was installed atomically with the pause, scheduled to restore after six minutes if the client failed. It executed successfully while waiting. Normal restoration removed it; final verification found **zero** diagnostic recovery jobs. Original jobs are active, with identical schedules and command hashes. Subsequent normal dispatches succeeded (push at 03:35, 03:36 and 03:37 UTC; flight at 03:35 UTC). These dispatch successes mean scheduled requests resumed, not a claim of every push reaching a phone.

Push dispatches at 03:32, 03:33 and 03:34 UTC were skipped and reminders may have been delayed. The flight job had no scheduled tick inside the actual pause interval, so no flight tick was skipped. This matters when interpreting the experiment.

## Measurement windows (UTC)

| Phase | First window | Second window |
| --- | --- | --- |
| A1 | 03:29:58–03:30:29 | 03:30:58–03:31:21 |
| B | 03:32:58–03:33:15 | 03:33:58–03:34:16 |
| A2 | 03:34:58–03:35:20 | 03:35:58–03:36:20 |

All confirmed upstream failures in A1/A2 began in the first few seconds of a minute. Failures also occurred at 03:31 and 03:36, minutes without a scheduled flight tick. Both worker flags were paused together; this was not a randomized factorial experiment, and it does not isolate a specific worker or eliminate time-varying platform conditions.

## Correlated affected requests

| Phase | Outer request ID | Client wait | Upstream evidence |
| --- | --- | ---: | --- |
| A1 | `01a093aa-3c58-7713-a27f-af35ea1a2e40` | 11923 ms | attempt 1 deadline 6501 ms; attempt 2 gateway 504, 5031 ms, upstream `01a093aa-5737-70de-8b47-c3a6eb8a84e5` |
| A1 | `01a093ab-20c7-7b83-9584-ff0e33bbad7f` | 6702 ms | gateway 504, 6112 ms, upstream `01a093ab-2361-7668-8162-f4769efd6bdd` |
| A2 | `01a093ae-cb03-7b19-943c-29802f9e0184` | 6263 ms | gateway 504, 5714 ms, upstream `01a093ae-cd10-70fc-bbe1-144d4921761a` |
| A2 | `01a093af-b3f2-71d5-af77-31a12688f5cc` | 5963 ms | gateway 504, 5125 ms, upstream `01a093af-b4cb-7825-918d-aae8de2d284f` |
| A2 | `01a093af-b3f2-7eea-b46a-b2d8202d90e4` | 6305 ms | gateway 504, 5872 ms, upstream `01a093af-b4be-76c1-8a53-aaacad8fe28a` |

Raw timings, restore SQL, original job state and events: `.migration-backups/worker-comparison-HcRJ0w/`. Script: `scripts/trip-migration/compare-background-workers.mjs`.

## Recommended next step

Follow-up completed: the concurrency/stagger experiment did not show a clear benefit and was withdrawn. A separate runaway sandbox APNs retry loop was found and repaired. See [final decision and evidence](APNS_RETRY_LOOP_FIX_20260912.md); intermittent gateway timeouts still require investigation.

Inspect and separately test bounded worker concurrency and staggered dispatch, especially the per-minute push worker's parallel requests. Preserve invitation/notification semantics and existing API quota caps. Then repeat the same measurement protocol. This evidence supports that direction before considering a database migration or paid infrastructure change; it does not establish that the platform itself is fault-free.
