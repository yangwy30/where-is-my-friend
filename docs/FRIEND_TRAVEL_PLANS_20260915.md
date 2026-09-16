# Friend plans — implementation and integration, 2026-09-15

Release update: the subsequent user-authorized deployment and TestFlight **1.0.2 (11)** upload are complete. See [the release record](TESTFLIGHT_1_0_2_11.md). The implementation-only status and release checklist below describe the earlier development step.

## User-visible behavior

- Friends keeps Around the World as its primary content. A compact **Friend plans / 好友计划** link sits beside the section heading; it does not insert a feed above the friend grid. Large accessibility text can wrap the heading and link vertically.
- The secondary page is **Where are friends going? / 朋友接下来去哪**. It lists future/current plans a friend explicitly allowed the viewer to browse, ordered by start date. Matching personal dates are not required for browsing.
- **My plans** and **Add my plan** are separate entry points for the viewer’s own plans.
- A plan detail shows the owner, city and destination-local dates. **I’ll be there too / 我也会去** creates a new editable draft containing only the destination and dates: new ID, revision zero, no audience, no reminders, no browsing consent.
- **Say hello** opens the existing system sharing mechanism. Publishing a plan does not broadcast a new-plan push. Reciprocal overlap notifications remain governed by the existing rules and user preferences.
- English and Simplified Chinese strings are included for the new feature and its plan-editor flow.

## Explicit browsing consent and compatibility

`allowFriendBrowsing` is separate from the existing overlap audience. It defaults to false in the database, new drafts and decoding of legacy plans/caches. Users enable **Let selected friends view this plan** to allow the selected audience to browse the full city and date range.

- Migration `20260915040000_friend_travel_plans.sql` adds the field without enabling it for any old plan.
- `wif_friend_travel_plans` only returns minimal plan fields for an accepted, matching friendship generation, an explicit audience grant and a live owner/recipient. Blocks in either direction and destination-local end dates are checked on each read. No audience list or notification preferences are disclosed to readers.
- `wif_travel_snapshot` adds `friendPlans` and the owner’s consent flag. New clients tolerate older snapshot responses that omit these fields; they never invent shared plans.
- API writes with explicit boolean consent use `wif_travel_save_v2`; old request bodies retain the legacy write. The v2 function reuses ownership, revision, input and audience validation in one transaction.
- A legacy client editing a plan resets its browsing permission to false. It can still update overlap sharing, but cannot unknowingly expand full-date access to a new audience. Users can re-enable browsing from the updated client.
- Shared friend plans are kept only in memory. A failed refresh or account change clears them; a cold launch cannot load them from the personal-plan disk cache. Views also filter removed/blocked friends locally. List/detail refresh on appearance, foreground return and approximately once per minute while active. Revocation is reflected on the next successful refresh, not through a new real-time push mechanism.
- Detail views resolve the live plan ID from the library instead of retaining a stale plan value. When it disappears, the page shows an unavailable state and offers refresh.

## Integration with the other tasks

The task inventory showed **评估集成 TripFlights 功能** and **Audit trips 界面体验** idle and using this exact directory:

`/Users/wangyang/.gemini/antigravity/where_is_my_friend`

This work used their latest local source as its baseline. It did not reset Git, replace the working directory with an old checkout, or cherry-pick older files. A source-only baseline was saved in `/private/tmp/across-friend-plans-baseline` before edits.

The existing Trips redesign, flight-date handling, invitation routing, push registration and friend-request notification changes remain present. Content hashes against the baseline confirm no changes in these core files:

- `Features/Trips/TripsView.swift`, `TripLibrary.swift`, `TripPlanningSheets.swift`.
- `Core/AppStore.swift`, `PlatformServices.swift`, `Features/Friends/AddFriendView.swift`.
- `supabase/functions/push-worker/index.ts` and migration `20260915030000_friend_invitation_notifications.sql`.

Shared files received narrow additions: Friends gains the link, the API chooses the travel-save RPC, the demo repository gains incoming plan fixtures, and the project registers the new view. Existing invitation tests and code were retained. The new tests are additive.

This is integration into the current local source. It does not imply that every change from every task is already deployed, uploaded to TestFlight, or available in the App Store.

## Verification

- Initial client run: **123 unit tests passed**; `/private/tmp/across-friend-plans-unit.xcresult`.
- Full backend run after the final migration/index: **85 tests passed**; `/private/tmp/across-friend-plans-backend-final.log`.
- New backend tests cover legacy consent migration, single-sided browsing without overlap, private defaults, audience revocation, blocks, removal/re-adding, deletion, owner/revision protection, old-client writes, destination-local expiry, field projection and service-role-only access.
- New client tests cover backward decoding, private draft copying, memory-only shared data, refresh failure, account-generation protection, sorting and local-date expiry.
- Integration verification: **123 unit tests and 7 distinct UI scenarios passed** across the runs below. The initial UI failure was a test locator looking for a separate text element inside an accessibility-combined friend card; the corrected button locator verifies the card is actually visible on the home screen.
  - `/private/tmp/across-friend-plans-ui.xcresult`: existing friend-request notification, Trip invitation, personal overlap/revocation, Trips overview/map, and flight add/edit/delete flows all passed; the Chinese new-feature flow also passed.
  - `/private/tmp/across-friend-plans-final.xcresult`: 123 unit tests plus the two new English/Chinese UI flows passed, including the corrected home-card assertion.
  - `/private/tmp/across-friend-plans-layout-final.xcresult`: final rebuilt source with translated field/date labels and lazy list rendering; both new UI flows passed again. Screenshots were exported and inspected.
- App/Widget Debug simulator build and `git diff --check` passed. Physical-device delivery, real two-account browsing and production deployment remain separate acceptance steps.

## Release order — not executed by this task

1. Freeze the combined source and inspect the live migration ledger. Retain the other task’s friend-invitation changes; if its `20260915030000` migration is still pending, include it in the reviewed release plan before deploying code that depends on it.
2. Apply `20260915040000_friend_travel_plans` after the existing travel-plan schema. Do not blindly apply unrelated historical migrations.
3. Deploy the matching API. Include the invitation worker/deployment steps from `INVITATION_NOTIFICATION_RELIABILITY_20260915.md` when publishing that task’s changes too. This feature itself adds no worker, cron or notification category and changes no flight-query budget.
4. Publish the updated privacy text and App. The new client sends explicit browsing consent, so the database/API must be ready before releasing it; there is no insecure fallback that drops consent fields on a failed save.
5. With two approved test accounts, confirm A’s private plan is hidden from B, A’s explicit audience/browsing grant makes it visible, B can copy a private draft, and revoke/block/remove/delete makes subsequent reads unavailable. Verify current-city sharing and reciprocal overlap notifications remain independent.

No production database changes, function deployments, real messages, real-account deletion or TestFlight upload were performed here.
