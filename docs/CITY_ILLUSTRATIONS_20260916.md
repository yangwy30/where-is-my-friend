# City illustration fallback review

## Integrated artwork

Retains commit `1212c15` from the other implementation: a transparent 3D neighborhood (`City_generic_block`) for known cities without curated artwork, and a frosted globe (`City_unknown_location`) for unspecified locations. Both have 1x/2x/3x variants and use the existing pedestal style. No new images were generated in this review; the existing 204 curated city illustrations are unchanged.

Bakersfield and Fremont keep their real city/state labels and their independent geographic identity even though they share generic artwork. The fallback contains no flag or arbitrary three-letter abbreviation. Artwork remains separate from same-city matching, notifications and the region catalog. Comprehensive state-scoping of the older city/alias registry remains a separate follow-up; this change does not claim to resolve all geographic namesakes.

## Review fixes

- Added a shared friend-aware artwork entry point. Paused/unavailable presence uses the globe and the appropriate accessibility status even if old geography remains in a cached record. Friend cards, details, rows, widget previews and widgets use it.
- Removed invented New York/Tokyo defaults from actual widget presence states. Missing current-city data passes through to unknown-location artwork and an unavailable label; friend labels respect the sharing state. Explicit marketing/demo scenes retain their example cities.
- Centralized generic/unknown fallback asset names without assigning a generic asset as a city's geographic identity.
- Made debug comparison fixtures deterministic and limited to four demo friends, with a separate paused/unavailable fixture. Removed a hard-coded external screenshot write; captures are XCTest attachments.

## Verification

Xcode 27 simulator App/Widget build succeeded. On the dedicated iPhone 17 Pro Max / iOS 26.4.1 simulator, **20 unit tests and 2 UI workflows passed**. Unit coverage includes asset transparency/loading, hidden cached geography, region artwork identity and same-city policy. UI captures verify the active-city comparison in Solar Jade and Night Jade, plus paused/unavailable states.

Result: `/private/tmp/across-city-illustration-review.xcresult`.

Actual home-screen WidgetKit runtime was not separately placed/captured in this review. The Widget extension compiled successfully and uses the same tested artwork component. No production database, matching policy, backend deployment or TestFlight release changed.
