# Location refresh and social-region granularity review — 2026-09-13

Read-only review in response to user feedback. No application behavior, permissions, backend schema or production data changed. Findings are based on current source, not a trace of the reporting user's device.

## 1. Automatic refresh: confirmed implementation gaps

- `AppRootView` startup and `scenePhase == .active` refresh the cloud snapshot and push registration. Neither requests a new foreground location. Cloud refresh is not location refresh.
- `requestForegroundCity()` is called by initial location setup and explicit refresh actions in Sharing/Profile. It uses `CLLocationManager.requestLocation()`, a one-shot request. No foreground `startUpdatingLocation()` loop is present.
- Background monitoring requires the account preference plus Always authorization in `setBackgroundUpdatesEnabled`. The preference defaults to false. This should not be described as automatic background movement tracking for every user who merely allowed While Using access.
- Significant-change/visit monitoring is OS-controlled and not a precise city-boundary event stream. The configured `distanceFilter = 5000` does not set the significant-change service's trigger distance.
- Incoming location samples are not checked for age or horizontal accuracy before geocoding. Geocoding results have no generation/recency protection against an older result overwriting a newer one.
- `ResolvedCity` contains city/country/source, but no observation timestamp. Root delivery uses `removeDuplicates()`, so a fresh observation in the same city and source may not refresh its freshness timestamp. City changes and freshness heartbeats should be separate concerns.
- Geocoding falls back from locality to administrative areas and finally `placemark.name`. The final name may describe a specific place rather than a city. Do not upload that as city-level presence; this is a privacy/granularity risk in the implementation, not evidence that such a value was actually uploaded.

### Recommended behavior

1. In explicit automatic-location mode, request a fresh location on authenticated launch/foreground entry, with a freshness/rate guard. Preserve paused sharing and deliberate manual-city overrides.
2. While actively using the App, use a bounded low-power refresh/monitoring strategy rather than depending exclusively on the next app foreground transition. Stop unnecessary work when backgrounded unless the user opted into background updates.
3. Keep background monitoring optional, clearly show when Always access is missing, and do not promise immediate updates after travel or force-quit.
4. Validate sample timestamps and accuracy; serialize or cancel obsolete geocoding work. Maintain last-observed and last-successfully-synced timestamps. Reconfirming the same region can update freshness without creating a new same-city alert.
5. Handle failed upload separately from failed location acquisition. Avoid new permanent dashboard panels; use the existing city details/status text.

Apple references: [one-shot requestLocation](https://developer.apple.com/documentation/corelocation/cllocationmanager/requestlocation()), [significant-change monitoring](https://developer.apple.com/documentation/corelocation/cllocationmanager/startmonitoringsignificantlocationchanges()), [authorization behavior](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services).

## 2. Granularity: separate real locality, social matching region and artwork

Current geocoding uses `placemark.locality`, so Milpitas is a normal result rather than necessarily a location bug. [Milpitas describes itself as part of Silicon Valley](https://www.milpitas.gov/780/About-Milpitas).

Current code couples geographic matching to artwork: `CityIdentity.matches` considers the `cityID` returned by `CityEmblem.resolve`. The backend's `wif_city_key`, however, normalizes city/country text. Simply making more localities share an emblem can therefore widen frontend matching without changing server notifications or future-plan matching.

### Confirmed alias defect

`CityEmblem.resolve` uses `normalized.contains(alias) || alias.contains(normalized)`. Static evaluation of the current registry/rule found:

- Milpitas: not registered, no matching alias, falls back to a generic archetype.
- Santa Clara: not registered; substring `la` matches the Los Angeles alias.
- San Jose and Sunnyvale: exact registered entries.

Replace fuzzy substring aliasing with explicit, scoped identity aliases. Country and relevant state/region matter. Artwork should never decide that two people are geographically together.

### Proposed product model, not implemented

- **Locality:** raw validated city identity, such as Milpitas; can remain on-device for the user's own location explanation.
- **Social region:** an explicit stable ID and display label, such as a defined Silicon Valley/South Bay grouping. This is a product taxonomy with deliberate boundaries, not an assertion that informal region names have one universally agreed boundary.
- **Artwork key:** a reusable icon family for that region, independent of the geographic identity/matching key. Unknown cities can use generic artwork without being falsely assigned to a nearby major city.

Proposed first-step examples: consider Milpitas, San Jose and Santa Clara under a defined Silicon Valley grouping, while keeping San Francisco separate. The exact membership must be reviewed; do not silently group the entire Bay Area as one city or use an arbitrary radius across waterways. If the product matches regions, its copy should say “same area” / “both in Silicon Valley”, not imply close physical proximity.

Friends cards can show the social-region label and shared illustration. The user's own location details can explain “Detected Milpitas → shown as Silicon Valley”. Do not automatically expose the finer locality to friends. Trips must retain actual airports and flight route details; SJC and SFO must not be merged by an illustration or presence-region rule.

## Migration and acceptance before release

- Apply a consistent, versioned region-identity policy to current presence, future plans, server overlap/notification generation, frontend cards and widgets. Do not update only the display name.
- Keep precise coordinates on-device under the current privacy promise. Use reviewed locality/region mappings or published boundary data, not loose string matching or invented geographic boundaries.
- Avoid treating migration of old city IDs to a region ID as fresh travel and sending a wave of duplicate “new same-city” alerts.
- Verify: foreground crossing A→B; same-city fresh observation; stale cached sample; failed geocode/upload; manual override; sharing paused; When In Use versus Always; permission downgrade; background return.
- Verify: Milpitas/Santa Clara grouping as explicitly chosen; San Francisco separation; country/state namesakes; no `la` substring collision; frontend/server parity; same-region movement does not produce repeated arrival alerts.

## Suggested order

First fix foreground refresh and unsafe identity aliasing. Then define the initial Bay Area social-region mapping and apply it consistently. Do not try to solve geography by generating an icon for every municipality or by merely reducing location accuracy.
