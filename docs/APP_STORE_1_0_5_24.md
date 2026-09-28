# Across Us 1.0.5 (24)

## Release scope

- Friend plans use permission-aware cursor pagination; the legacy API still returns complete lists for older clients.
- Friends shows the first three upcoming overlaps and the exact total; opening Together soon loads the complete list. Notification links can resolve an item beyond the preview.
- Concurrent refreshes are coalesced and ordinary existing-account bootstrap avoids redundant initialization work.
- Bounded client error/timing diagnostics join the already active backend monitoring. Privacy declarations use App Functionality, linked to identity, no tracking.
- Existing widget design and eight screenshots per language are retained from released 1.0.4 (23). No flight provider, subscription, or quota changes.

## Validation

- Backend suite: 140 passed; an additional eight-test diagnostics run passed after adding the actual production migration ordering regression (0400 before 0200/0300).
- iOS 27: 189 unit tests and seven selected UI flows passed. Flows cover the second friend-plan page, complete overlap list and deep links, revocation, Trip creation/persistence/completion, notification settings, and widget privacy/edge states.
- Production migration 0200 deployed using source fingerprint guards and private backup, followed by 0300 and API version 27. Existing monitoring migration 0400 retained.
- Read-only comparisons across seven active production accounts passed: overlap totals, complete overlap records, first-page sizes and bounded summaries match legacy behavior. New RPCs reject direct anon/authenticated execution.
- Downloaded production API entrypoint matches the local source byte for byte. Protected health endpoint returns 200 with no active failure/backlog flags.
- Isolated cloud functional/concurrency validation from the same implementation is documented in [ISOLATED_STAGING_20260927.md](ISOLATED_STAGING_20260927.md). The old TripFlights backend remains active; staging remains paused.

These checks do not claim a new two-device Apple sign-in/APNs presentation test or a production load test. All UI tests use controlled fixtures.

## App Store material

Version 1.0.5 has been created and bilingual What's New, promotional text and reviewer notes saved. Existing descriptions, keyword experiment, screenshots, automatic release choice and ratings are retained. Performance Data is added to the existing Other Diagnostic Data declaration; the bundled manifest also matches the existing user-content and search-history declarations.

English What's New:

> • Friend plans load in smaller batches for smoother browsing.
> • See a concise Together soon preview, then open the full list of upcoming meetups.
> • Improved refresh reliability and more reliable links to shared plans.
> • Stability and performance improvements.

Chinese What's New:

> • 好友计划分批加载，浏览更顺畅。
> • 首页先展示即将相聚的摘要，点开即可查看完整列表。
> • 改善刷新体验，以及从通知打开计划的可靠性。
> • 提升稳定性与性能。

## Distribution state

- Final archive succeeded: `/tmp/across-release105/AcrossUs-1.0.5-24-final.xcarchive`, source commit `358497f`.
- App and widget are both 1.0.5 (24), with production bundle IDs/backend/APNs, local demo disabled, diagnostics enabled and the complete nine-type privacy manifest verified against source.
- App Privacy changes are published. The bilingual public privacy policy returns HTTP 200 and contains the matching diagnostic description.
- Distribution export is **blocked by Xcode login**: `No Accounts` and missing Apple Distribution signing identity. Xcode Settings > Apple Accounts visibly has no signed-in account. The owner has been asked to sign in there; the browser App Store Connect session remains valid.
- **Not uploaded to TestFlight and not submitted for App Review yet.** Resume export from the verified final archive after Xcode login, validate the exported signature/configuration, upload, confirm Apple processing and test-group assignment, then select build 24 for 1.0.5 and submit.
- Backend monitoring remains healthy after rollout, with successive external probes observed approximately five minutes apart.

Private migration/API backups, read-only verification output and rollout receipts are in `.ops-private/release-105/`; the pagination rollback bundle is at the private path printed by its deployment command. Do not remove v2 endpoints after new clients are distributed. Prefer a forward-compatible fix; preserve the additive migrations.
