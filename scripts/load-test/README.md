# Across Us — isolated local load tests

These tests start an ephemeral **real PostgreSQL server** and a loopback-only HTTP server. They run the production API handler and database migrations against synthetic data. They never read production credentials, connect to Supabase, call the flight provider, or deliver real notifications. There is deliberately no remote-target option.

## Run

Requires Node 22.22+ (for `stripTypeScriptTypes`) and a platform supported by the pinned embedded-postgres binaries. Dependencies are separate from the app's normal build.

```sh
npm ci --prefix scripts/load-test
node scripts/load-test/run.mjs --output=/tmp/across-load-normal
node scripts/load-test/run.mjs --dense=1 --output=/tmp/across-load-dense
node scripts/load-test/run.mjs --dense=1 --pagination=1 --output=/tmp/across-load-paginated
node scripts/load-test/run.mjs --notifications-only=1 --output=/tmp/across-load-notifications
```

For a runtime installed elsewhere, pass `--runtime=/absolute/path/to/that/npm/project`. `--quick=1` runs 10-user calibration instead of the full tiers and skips sustained load and notification delivery. Do not run multiple benchmarks concurrently on the same machine.

## Scenarios

- 1,000 synthetic existing accounts, 20 friends and 3 personal plans each; 600 shared trips, 3,000 flights, 5,000 past same-city events.
- Dense variant: 100 friends and 10 plans each, 1,000,000 plan-audience rows.
- 100 / 500 / 1,000 **distinct accounts** initialize simultaneously after simulated identity verification.
- 100 / 500 / 1,000 existing accounts each load Friends, Friend plans and Trips in sequence, with all actors starting together.
- 1,000 accounts refresh Friends and plans once, evenly spread over 60 seconds (about 33.3 HTTP requests/second).
- 32 HTTP requests initialize the same account; another 20 independent SQL connections initialize the same identity in each of 20 trials.
- A candidate per-identity initialization lock is tested only inside the ephemeral database, then the original function is restored. No production migration is created or applied by this experiment.
- 16 competing edits use one plan revision: exactly one success and 15 explicit conflicts are expected.
- A simulated 09:15 UTC scheduling window generates 1,000 reminders in batches of 500 / 500 / 0, checking the cap and deduplication. These local-only daily rows are removed before the separate delivery fixture.
- 1,000 persisted booking-notification records pass through actual SQL claim/prepare/complete operations and the production push-worker handler. The APNs sink is simulated at 50ms; calls are never sent over the network. Worker invocations run back-to-back, unlike production cron.

## Pagination comparison

`--pagination=1` measures the new overview plus the first 50-item page. A burst actor performs four requests (Friends, overview, first page, Trips), compared with three legacy requests. The steady homepage refresh uses Friends + overview only. A separate cursor walk verifies all expected plans without duplicates. The homepage overlap preview is limited to three rows while retaining the exact count; a full expansion and a notification detail outside that preview are compared with the legacy full response. A 100-user expansion burst measures the work deferred until a user opens the card. The report records whether the bootstrap lock is already part of the migrations. For comparison with older reports, the four-request navigation burst still uses `GET /v1/bootstrap`. The additional `app_home_refresh_burst_1000` scenario follows the actual iOS homepage path: `POST /v1/auth/bootstrap` followed by `GET /v2/travel-plans`. Client-side request coalescing is covered by iOS tests, not simulated as a server throughput improvement.

`--burst-only=1` omits the steady and notification stages for targeted iteration. `--profile=1 --quick=1 --dense=1` captures nested PostgreSQL execution plans and a local-only custom-plan experiment; these are diagnostics, not load results, and do not alter production.

## Measurement and limits

- 20 database connections, 6.5-second statement and pool-wait timeouts, 128MB PostgreSQL shared buffers, 4MB work memory.
- HTTP latency includes the 25ms simulated identity service, account lookup, real SQL, handler/JSON processing and local HTTP transport.
- Supabase Auth / Apple sign-in / Edge gateway / PostgREST / internet latency are **not** reproduced. APNs signing and decryption are also substituted. The generator and API run on the same computer, so results cannot certify hosted capacity.
- HTTP connections are gradually prewarmed, and the local server's idle keep-alive timeout is 180 seconds. This removes local TCP accept-backlog and 5-second idle-disconnect artifacts from the warm application benchmark. It is **not** a cold connection storm test.
- Reports separately record HTTP status, payload size, SQL execution, pool wait, event-loop delay and memory. Expected `409` edit conflicts are identified explicitly; they are not service failures.
- `bootstrap-lock-candidate.sql` is a **local experiment**, not a production patch. Review before turning it into a migration.
- The server stops in `finally`. Only generated temporary database files remain under the printed `across-load-db-*` directory. No operating-system users or persistent services are created.

## Output

- `results.json`: dataset/configuration, stage summaries, race checks and notification results.
- `requests.json`: per-request synthetic measurements, without tokens or identities.
- `rpc-metrics.json`: per-RPC timings and error codes.
- `bootstrap-lock-candidate.sql`: function definition tested locally to address concurrent initialization.

The report must state machine, dataset, active actors, pacing, mock boundaries and timeout settings alongside any latency/capacity claims. Production pressure tests require a separate, dedicated staging environment and are not performed by this script.
