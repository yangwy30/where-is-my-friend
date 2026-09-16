# Deeper timeout investigation — September 11, 2026

## Conclusion and confidence

Latest follow-up: [worker-load experiment and APNs retry repair](APNS_RETRY_LOOP_FIX_20260912.md). Concurrency/staggering were tested and withdrawn; a confirmed sandbox environment-error retry loop was fixed. Do not interpret the earlier regional or A/B evidence as proof that normal concurrency alone caused the failures.

The confirmed failure boundary is the hosted HTTP gateway/upstream-service path. Real profile RPC and Auth `/user` calls return gateway 504s after roughly five seconds. Our former API error mappings incorrectly converted these to 400 and 401; version 18 fixes that secondary defect, not the underlying intermittent availability problem.

Available database and pool evidence does **not** support blaming a slow profile SQL statement, a saturated PostgREST pool, or deadlock. However, current/cumulative measurements do not exclude every transient host stall or network issue. The exact internal component producing the gateway timeout is not exposed by the available customer logs. Do not describe the ultimate platform root cause as confirmed.

## Additional evidence gathered this turn

### Database and pool

- Project primary region: `us-east-2`; Management API reports `ACTIVE_HEALTHY`.
- Postgres last started August 12, 2026, 20:31:28 UTC.
- At September 12 03:13:47 UTC: 10 connections to the current database, maximum configured connections 60; no blocked sessions; no cumulative deadlocks. Five PostgREST connections were idle.
- Metrics scrape at 03:16:14 UTC: PostgREST pool maximum 10, waiting 0, available 4, **pool timeouts total 0**. Database load averages 0.11 / 0.10 / 0.04. Available memory approximately 173 MB; data volume has approximately 1.74 GB free. These are snapshots, not historical CPU/IO charts.
- Completed statement aggregates: notification claim maximum 117.60 ms; notification completion maximum 45.38 ms; trip refresh claim maximum 110.28 ms; App user resolution maximum 29.86 ms. These are far below the gateway's roughly 5-second failures. A separate travel-save statement reached 1,175 ms; it is not the profile save under investigation.
- Postgres warning/error and PostgREST logs contain no recorded pool exhaustion, deadlock or SQL cancellation corresponding to the three user-facing incidents. SQL history is not a per-request audit trail; this is not proof that a timed-out mutation never committed.
- Cron dispatches complete in under 163 ms in the observed daily window. That measures enqueueing via pg_net, **not** the complete asynchronous worker runtime, and cannot rule out overlapping worker requests.

### Routing and timing

- Latest 24-hour aggregate, read at approximately 03:13 UTC: 177 upstream 504s via CMH versus 4 via IAD. CMH successes numbered 3,053; IAD successes 2,020.
- This is **not a controlled region comparison**: CMH traffic is predominantly scheduled workers running in `us-east-2`; IAD traffic is predominantly interactive API requests. Do not attribute the failures to region alone or recommend moving production solely on these counts.
- The actual profile failure and both observed Auth timeout/bootstrap failures traversed **IAD**, not CMH.
- Read-only regional A/B at 03:17:11–03:17:27 UTC: 12 requests each forced to `us-east-1` and `us-east-2`, verified through the returned region header. Used only the anonymous project JWT and `GET /v1/bootstrap`, so Auth rejection was expected and no account could be created or edited. All 24 requests returned expected 401; no request exceeded two seconds. Median latencies 318 ms and 263 ms respectively. This tests the rejection/transport path only, not a real Apple authorization or profile mutation; it did not reproduce the intermittent failure.
- Diagnostic requests carry `x-client-info: wif-readonly-region-diagnostic`. Their expected Auth failures must be excluded from future user-incident counts.
- Additional IAD-only timing query (September 11 21:00 UTC onward): all four observed gateway failures started at second 0, 2 or 5 of a minute; successful requests were distributed across all seconds. This small-sample correlation warrants checking scheduled-task bursts, but does not establish causation or authorize pausing production jobs.
- **Live reproduction:** repeated the same 24-request read-only A/B across the minute boundary, from **03:20:58.002 to 03:21:20.465 UTC**. One `us-east-1` request took **5,564 ms** (outer request `01a093a1-fcc6-7ba8-8df9-dcdff7edfee0`). New deployed telemetry recorded `stage=auth_user`, `status=504`, `attempt=1`, `elapsed_ms=5047`, upstream request **`01a093a1-fd69-7471-a74c-e9723efd47eb`**, at 03:21:07.068 UTC. The bounded retry then produced the expected anonymous-credential rejection. This directly reproduces an upstream Auth timeout without Apple authorization, user profile data, or a write operation. It does not by itself establish that cron caused it. The other 23 requests completed under two seconds.

### Platform incident context — not a proven attribution

Supabase's [Unresponsive Projects incident](https://status.supabase.com/incidents/4mkcsnlf6p5x) concerned Nano projects becoming unresponsive, was fixed across regions, and was marked resolved September 11 at 19:06 UTC. Earlier incident updates recommended restarting projects that remained affected. Our profile failure occurred **after** that resolution time; customer evidence does not establish that it is the same fault.

The separate [JWT rejection incident](https://status.supabase.com/incidents/6q5902p2xd9f) remained under rollout as of September 11 23:41 UTC. Our two recorded false-expiry incidents have upstream **504**, not direct upstream JWT rejection, so this report cannot be used to declare them caused by the known JWT-cache bug.

## Remaining action requiring coordination

Update after explicit user approval: the controlled worker A/B/A comparison has now completed. See [comparison results](BACKGROUND_WORKER_ABA_20260911.md). It found 2 affected requests while running, 0 while paused, and 3 after restoration, out of 48 per phase. Both schedules were restored unchanged. This adds evidence for investigating worker bursts; support escalation is not the only actionable next step. The earlier statement below describes what had not been done at the end of the initial read-only investigation.

The next high-value step is a Supabase support investigation using the exact gateway request IDs below, asking which upstream phase timed out and whether this project needs a platform-side repair/restart. No support message, production restart, region change, schedule pause or paid upgrade was performed. Restarting could briefly interrupt users and needs explicit approval; it would be a controlled remediation test, not a guaranteed fix.

---

## Draft support request — NOT SENT

Subject: Intermittent gateway 504s to Auth and PostgREST despite zero pool timeouts — us-east-2 project

Project: `cdhpaujazbuppbxyhjxq`, primary region `us-east-2`, PostgREST 14.5. We see repeated gateway v2 504s at approximately five seconds affecting both Auth and RPC endpoints, including interactive users and scheduled Edge Functions.

Please trace these gateway request IDs:

| UTC start | Endpoint | Gateway request ID | Status / origin time | Ingress |
| --- | --- | --- | --- | --- |
| 2026-09-12 00:03:00.732 | `/auth/v1/user` | `01a092ec-b264-7088-92cf-857edcedc474` | 504 / 5215 ms | IAD |
| 2026-09-12 00:53:02.064 | `/auth/v1/user` | `01a0931a-7e13-738d-b9c3-4ddd92758d70` | 504 / 5043 ms | IAD |
| 2026-09-12 01:45:05.297 | `/rest/v1/rpc/wif_update_profile` | `01a0934a-2658-7b01-a837-956fd2d3e650` | 504 / 5145 ms | IAD |
| 2026-09-12 03:05:01.150 | `/rest/v1/rpc/wif_trip_claim_refresh` | `01a09393-5445-78bb-a787-4c75efc79cef` | 504 / 5342 ms | CMH |

We also reproduced the Auth timeout using an anonymous JWT solely for a read-only rejection-path diagnostic at the 03:21 UTC minute boundary: outer request `01a093a1-fcc6-7ba8-8df9-dcdff7edfee0`, upstream request `01a093a1-fd69-7471-a74c-e9723efd47eb`. Our measured upstream attempt returned HTTP 504 after 5047 ms. No actual user account or Apple authorization was involved. A second bounded attempt returned the expected rejection.

At 03:16 UTC PostgREST reported pool_timeouts_total=0, pool_waiting=0, pool_available=4, pool_max=10. No DB deadlocks or blocked sessions were observed. Completed RPC statement times are mostly tens of milliseconds. Errors continue after the September 11 unresponsive-project incident was marked resolved. Project has not restarted since August 12.

Could you determine whether these timeouts occur during gateway connection establishment, upstream response waiting, internal routing, or a project-host stall? Please check whether the project is affected by lingering issues from the Nano-project incident and whether a restart/platform repair is recommended. Is the profile mutation's commit outcome recoverable from internal tracing?

The four IAD failures cluster in the first six seconds of a minute, close to existing cron dispatches. Please check host/network resource contention at those exact instants, even though observed SQL duration and pool-timeout counters are low. We have not paused the production schedules to test causality.

We have corrected application-side error classification and added one bounded retry for explicitly read-only validation/snapshot operations. Writes are not automatically retried. Please investigate the original upstream 504s rather than the former derived application HTTP 400/401 responses.
