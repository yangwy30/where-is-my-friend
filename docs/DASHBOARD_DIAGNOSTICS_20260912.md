# Direct Supabase Dashboard inspection — September 12, 2026

Inspected the user's already signed-in Chrome Dashboard for project `cdhpaujazbuppbxyhjxq` at approximately 00:10–00:14 America/New_York. This turn used the visible Dashboard, not new load tests or backend mutations. Only report filters/navigation were changed. No restart, upgrade, query reset, session termination, credential edit or production configuration change.

## Visible results

- **Data API**, displayed last-hour window approximately September 11 23:10–September 12 00:10 EDT: 315 requests, 26 response errors, displayed response-speed summary 1,201 ms. Leading error routes were HTTP 504 on `wif_complete_notification_delivery` (10), `wif_trip_invitation_claim` (7), and `wif_claim_notification_deliveries` (3). These are request counts, not affected-user counts, and the window includes diagnostics and experiments.
- **Database resources**, 23:11–00:11 EDT: CPU summary 1.00%, network throughput 13.4 KB/s, disk IOPS summary below 1, disk throughput 6.6 KB/s. These displayed summaries do not rule out brief spikes. Initially unpopulated/off-screen charts loaded after refresh/scroll; this was not a persistent permission failure.
- **Database size:** 0.07 GB against a 2 GB provisioned volume. Largest listed object was `cron.job_run_details`, 40.61 MB / 58.47% of the reported database size. This is not evidence that disk capacity is exhausted.
- **Memory:** chart heading 435.66 MB, with Used, Cache + Buffers, Free and Swap series; commitment summary 1.04 GB. Do not equate the chart's total/stack including cache and swap, or virtual commitment, with actual process RAM consumption. Swap is visible, but this view alone does not establish memory exhaustion as the timeout cause.
- **Live connections:** 8–9 of 60 connections. Active queries, idle-in-transaction and blocked queries displayed zero when inspected. Expanded the view-only role filter from the default three roles to include `authenticator`, Auth admin, service role and Supabase admin. Listed service sessions were IDLE. A long-lived `LISTEN "pgrst"` session is not a multi-day running SQL query.
- **Query Performance** filtered to `wif_update_profile`: 6 completed RPC calls, maximum 15 ms, mean 10 ms, minimum 6 ms, 100% cache hit rate. Counts include prior test saves. This measures completed SQL execution, not the full HTTP call or an uncompleted gateway request. The table also contains a function-definition statement; it is not another profile save.
- **Auth**, approximately 23:13–00:13 EDT: the gateway table showed 311 `GET /auth/v1/user` HTTP 403 responses and 10 HTTP 504 responses (504 average 5,287.60 ms). The many `bad_jwt` entries include our deliberately anonymous diagnostic requests and must not be reported as hundreds of failed user/Apple logins. One `POST /auth/v1/token?grant_type=id_token` success was visible with HTTP 200 / 624 ms.
- Auth processing-time percentile panels explicitly say **Pro Plan and above** and display **Sample Report**. Those sample panels are not this project's real p95/p99 data. Apple-filtered usage also showed no data / possible refresh delay; that is not proof of no Apple activity.

## Interpretation

### Historical window around the real failed save

Also navigated the resource report to **September 11 21:40–21:50 EDT / September 12 01:40–01:50 UTC**, surrounding the recorded 21:45 profile failure. The visible selected time range was verified in the Dashboard:

- CPU summary **2.23%**; the displayed chart had small spikes but no near-capacity plateau.
- Network throughput summary **29.9 KB/s**.
- Disk IOPS summary **3**, far below the plotted maximum of 3,000.
- Disk throughput summary **562.9 KB/s**, far below the plotted maximum of 125 MB/s.
- Database connections summary **9**, with chart values well below the limit of 60.

This is stronger than a present-time-only check: the chart samples around the actual incident do not show sustained CPU, disk or connection saturation. Their aggregation/resolution still cannot exclude short sub-sample stalls or network/gateway faults. The browser was left on this historical resource view.

Dashboard access works and supports useful diagnosis. The views independently confirm persistent gateway/upstream errors despite fast completed profile SQL and no sustained saturation visible in the inspected summaries. They do not identify the exact internal timeout phase, prove that every interval was healthy, or establish that purchasing more compute will resolve the problem.

For the already-confirmed incident timeline, A/B/A results, final retry-loop repair and remaining timeout, see `UPSTREAM_ROOT_CAUSE_INVESTIGATION_20260911.md`, `BACKGROUND_WORKER_ABA_20260911.md`, and `APNS_RETRY_LOOP_FIX_20260912.md`.
