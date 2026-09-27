# App Store screenshot order — September 26, 2026

**Reserved for the next update by user decision; not uploaded.** This set moves the redesigned Home Screen widget to position 2. The prior September 25 set is preserved so earlier review links and capture references remain valid.

## Upload sequence

1. Friends and their shared cities.
2. Redesigned Home Screen widget: friends visible without opening the app.
3. Friends' upcoming plans.
4. Overlapping travel dates / Together soon.
5. Here together / same-city moments.
6. Shared Trips.
7. Expanded flight-route map.
8. Expanded flight details.

The first image explains the product; the second demonstrates its everyday Home Screen use; the third introduces future plans. The Trips → map → flight details sequence stays contiguous. Position 2 is an editorial recommendation, not a measured conversion result.

## Files

- `en/1284x2778/` and `zh-Hans/1284x2778/`: primary eight-image upload sets, filenames match the intended order.
- Matching `1320x2868/` sets are also provided.
- `gallery.html` and both contact sheets show the final ordering.
- `copy.json` maps each numbered output to the retained real capture in the September 25 set. The widget cards use actual redesigned SwiftUI captures. Position 2 combines them with the sourced iOS 27 blue wallpaper as an editorial close-up, without Dock/Search or a tall phone-shaped crop; it is not a single full Home Screen capture. See `widget-study/README.md` and `wallpaper-source.json` for provenance.
- `listing.json` contains the current bilingual listing copy.

Rebuild the custom widget composition with `node scripts/render_widget_presentation_study.mjs`, then the full set with `node scripts/render_marketing_20260925.mjs --set=2026-09-26`, with `sharp` in the Node module path.

## App Store Connect state checked today

- Signed in successfully; no login handoff is currently needed.
- 1.0.4 build 20 is **Pending Developer Release**; 1.0.3 is **Ready for Distribution**.
- Screenshots and description on the pending version are disabled. The page explicitly says to cancel the release to edit all information.
- The pending version still contains the previous seven-image green screenshot set.
- Build 20 does not contain the new widgets; build 22 also predates the new widget implementation and Chinese localization fixes.

Publishing these assets therefore requires a matching new build and a replacement review submission. No cancellation, release or store metadata write has been performed in this screenshot-ordering step. The user explicitly chose to keep the approved version and reserve this new screenshot set for the next update. Do not cancel or modify 1.0.4 (20) for this screenshot request.
