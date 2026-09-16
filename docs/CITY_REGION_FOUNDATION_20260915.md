# City-region foundation: artwork first

## Delivered scope

This is the first phase agreed in the design discussion: a reusable region catalog and shared artwork, with no widening of same-city notifications. It is not a worldwide metro-data import or a declaration that the listed product groups equal official metro boundaries.

- Canonical source: `supabase/functions/_shared/city-regions.v1.json`, schema 1, version `2026-09-15.1`. The exact same file is bundled into the iOS App and Widget and imported by the server-side resolver.
- Four reviewed presentation groups / 19 member names: Silicon Valley (6), Los Angeles Area (8), New York Area (4, including New York City alias), San Francisco Area (1). San Francisco stays separate from Silicon Valley; Irvine and Palm Springs are not silently absorbed into LA. Each group records source links and the limits of its reviewed coverage.
- Membership requires exact normalized city + country + administrative area. State names and postal abbreviations have explicit aliases. No nearest-major-city heuristic, substring match, assumed state, or ambiguous-first-record fallback.
- Existing San Jose, Los Angeles, New York and San Francisco assets are reused; no new bitmap/icon assets were generated. The actual city's name, accessibility label and identity remain intact.
- Friend cards/details, own location/settings, widget artwork and personal travel-plan artwork accept state metadata. Own location details can say `Part of Silicon Valley`; they do not claim that the shared city has already been replaced by the region.
- Trips, airports, flight lookup, route identity, future-plan dates, audiences and exact-city matching are unchanged.

## Metadata and compatibility

- Core Location's administrative area is carried alongside the existing city/country/observation time through AppStore deferral, repository upload, offline queue, snapshot persistence and widget storage. No coordinates are uploaded or stored by this change.
- New optional fields decode safely from old snapshots/queued uploads. Missing state means no inferred region membership. Older installations gradually gain the metadata after a fresh location update; no state is fabricated for historical data.
- Migration `20260915010000_city_region_metadata.sql` adds one nullable column, updates the existing snapshot projection with equivalent privacy guards, and introduces service-only `wif_update_presence_v2`. The original RPC remains available and clears state metadata when a legacy writer updates a presence.
- Both writers retain observation-time ordering. A stale fix cannot replace newer city/state information. Hidden friend cities also hide their administrative area.
- API input ignores client-supplied region IDs; the authenticated user owns the presence write. The only new accepted geography field is bounded administrative-area text.

## Deliberately not enabled

`regionMatchingEnabled` is false. The Swift catalog loader also fails closed if a catalog tries to enable matching without a client update. The resolver is presentation-only: city identity, SQL co-location keys, travel overlap keys and notification workers do not consult it. Merely editing a catalog cannot widen notification delivery.

Friends still share their existing city, not a coarser region-only presence. Main city labels have intentionally not been replaced with region labels while exact-city matching is retained.

Before enabling region-level matching, implement one versioned policy in current presence, future plans, SQL overlap evaluation, local/demo evaluation, notification text and widgets. Region matches must say “same area”, not imply nearby physical proximity. Migration must not look like a fresh arrival or replay old alerts. Explicitly review the initial membership boundaries before extending notification eligibility.

## Expanding coverage

The resolver contains no Bay Area/LA/NY conditionals. Add reviewed groups to the catalog rather than Swift or SQL switch statements. Require source URLs, scope notes, country, state aliases and explicit member names; validate duplicate/ambiguous memberships and asset availability. Census metro delineations and OECD FUA/eFUA data are potential import sources, not already-imported worldwide coverage. Any future import should produce this schema and retain provenance; product labels/boundaries can be reviewed separately from statistical boundaries.

## Release order (not executed)

Validation: 68 backend tests passed. On the dedicated `Across Us City Regions QA` iPhone 17 Pro Max simulator (iOS 26.4.1), 98 unit tests and 3 UI tests passed with zero failures: `/private/tmp/wif-city-regions-isolated-20260915.xcresult`. The UI cases cover regional artwork/real-city labels/no broadened matching, first-use location permission, and the Trips overview/flight interaction. Screenshots exported to `/private/tmp/wif-region-ui-preview` were visually inspected. An earlier run on a shared simulator was invalidated by another concurrent Xcode test installing/relaunching the same bundle; it was not treated as a passing run.

The in-App disclosure and privacy-page source now mention optional state/administrative-region metadata. This final copy-only change was made after the successful test run; the final Debug App/Widget build passed (`/private/tmp/wif-region-disclosure-build-20260915.log`). Publish that policy copy with the metadata-enabled release; the hosted page has not been updated in this task.

1. Apply the additive database migration.
2. Deploy the API using the new v2 RPC.
3. Ship the App/Widget build containing the catalog and optional metadata fields.

Old clients continue to work against the new API; new clients against the old API retain exact-city behavior but do not receive state metadata back. If rolling back the API, leave the additive column/RPC in place rather than deleting data. No production database, Edge Function or TestFlight upload was changed by this work.
