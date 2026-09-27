# U.S. App Store discovery — first implementation pass

**Release status update:** English metadata and bilingual screenshots were submitted with 1.0.4 (23) on September 26, 2026 at 10:08 PM PDT. Apple shows Waiting for Review; automatic release is enabled. The changes below are not yet public. See [release record](../../APP_STORE_1_0_4_23.md). The original preparation notes below describe the earlier paused state.

## Changes

- Replaced both generic TestFlight links on the public landing page with App Store Connect-generated links to Across Us, Apple ID `6807634842`.
- Navigation, hero and the redesigned footer use distinct campaign tokens. No advertising campaign, purchase or outreach was started.
- Prepared a first English ASO metadata experiment for the next permitted release:
  - **Across Us: Friends & Trips** (26/30 characters)
  - **Share cities & travel plans** (27/30 characters)
  - `widget,location,group,together,overlap,reunion,flight,arrival` (61/100 characters)
- Simplified the opening of the draft English description and removed a few interface-mechanics phrases. Screenshots retain their existing sequence and design.
- App Store version/review state is unchanged. The name, subtitle and keyword changes are local next-release material, not live metadata.

## Research and limits

`keyword-research.csv` records 12 candidate queries, their intent fit and supporting U.S. product listings. Discovery was through web search of U.S. listings; this does **not** measure iPhone App Store rankings, search volume or keyword difficulty. All missing measurements are explicitly marked.

The evidence favored concrete city/travel-sharing language. [YouInTown](https://apps.apple.com/us/app/youintown-friends-and-travel/id6769513590) and [Droozi](https://apps.apple.com/us/app/droozi-travel-networking/id6708242315) provide close examples of city/date sharing. [Flock](https://apps.apple.com/us/app/flock-group-travel/id6755789809) combines shared plans with broader trip organization. These listings support intent relevance, not a claim that the queries are high-volume.

[welago](https://apps.apple.com/us/app/welago-group-trip-planner/id6770325388) and [Trip Planner · Share Itinerary](https://apps.apple.com/us/app/trip-planner-share-itinerary/id6748044059) illustrate the broader expectations around complete trip planning. [Bump](https://apps.apple.com/us/app/bump-real-life-is-happening/id6471519217) and [Flight Tracker+](https://apps.apple.com/us/app/flight-tracker/id533365777) illustrate precise-location and live-aircraft expectations. Across Us should not target those promises as its core value.

The first keyword set intentionally leaves room rather than filling all 100 characters with unrelated or duplicate terms. Terms already in the new name/subtitle are omitted from the keyword field, including singular/plural variants. `location` and `widget` are a qualified experiment; the subtitle and imagery explain that the app shares cities. `planner`, `tracker`, `itinerary`, `calendar` and competing brands are not included. This is a relevance-led starting point, not a proven optimal keyword set.

Apple's [search guidance](https://developer.apple.com/app-store/search/) supports accurate metadata, nonduplicative keywords and relevant categories. Its [product page guidance](https://developer.apple.com/app-store/product-page/) distinguishes clear product communication from unnecessary keyword stuffing. Existing primary Social Networking classification is retained; no speculative category changes were made.

## Attribution setup

`campaign-links.json` contains two observed generated website links, a footer link added for the redesigned homepage, and three optional distribution examples using the same provider token. The provider token is a public attribution identifier intended to appear in URLs, not a credential. Optional channel examples have not been posted anywhere.

The [Apple campaign-link documentation](https://developer.apple.com/help/app-store-connect-analytics/acquisition/campaign-links) explains the provider/campaign tokens and reporting thresholds. The current UI says a campaign needs installs from at least five individual Apple Accounts before it appears; do not interpret an initially empty report as broken tracking. Campaign links measure attributed acquisition, not a standalone real-time click counter. No new cookies or user-content telemetry were added to the website.

## Measurement handoff

Keep separate dates for the website link fix and the eventual metadata release. Compare U.S. Search impressions and unique impressions, first-time downloads and source conversion across equal 14–28 day windows after metadata becomes live. Treat paid-search data separately if a paid test is subsequently authorized. Track website campaign results independently; they do not demonstrate improved organic ranking.

No search rank improvement or impression uplift is claimed yet. The next metadata experiment cannot begin while publishing remains paused and the new fields are still local.

## Files

- `keyword-research.csv`: 12-query qualitative worksheet.
- `next-release-fields.json`: version-controlled fields for the first experiment.
- `campaign-links.json`: validated account-specific attribution links and optional examples.
- `../../APP_INTRO_20260925.md` and `../../app_store_screenshots/2026-09-26/listing.json`: synchronized next-release copy.
