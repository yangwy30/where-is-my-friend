# Across Us product website — September 26, 2026

## Direction

Replace the previous gradient/glass card layout with an editorial page: warm paper, large typography, restrained green, and a contrasting navy section for shared trips. Use real product screenshots rather than invented interface cards or decorative landmark galleries.

## Feature coverage

| Section | What it explains |
| --- | --- |
| Friends | Shared cities, update times, same-city discovery and optional alerts |
| Future plans | City/date sharing, selected friends, one-calendar date selection and overlapping dates |
| Shared Trips | Invitations, shared destination, flight routes, flight details, arrival times and trip organization |
| Trip management | Optional flight-change alerts, morning reminders, member nudges, leaving, removing members and deleting trips |
| Widgets | Home/Lock Screen presence, friend selection, directory and together previews in light/dark |
| Questions | Plans versus Trips, sharing choices, changes, update freshness and getting started |

## Assets and availability

- Screens use demonstration data from existing simulator captures in `docs/app_store_screenshots/2026-09-25/raw/en/`.
- Widget crops come from `docs/widget_redesign/2026-09-26/`.
- The opening screenshot caption identifies this as a look at the next update; the widget section explicitly says **New designs · Next update**.
- The map crop preserves the Apple Maps attribution. The route map on the website is a product screenshot, not an interactive map.
- `scripts/build_site_product_images.mjs` regenerates ten WebP product images and the social preview using Sharp. Product assets total approximately 372 KB; fonts are system fonts.
- Navigation, hero and footer App Store links retain app ID `6807634842`, provider `128897130`, and distinct campaign tokens. The new footer token is recorded in the ASO campaign file.

## Verification

- Checked the desktop layout and mobile layouts, including a narrow 300 CSS-pixel stress test and approximately 393 CSS pixels.
- Corrected a selected-tab arrow that previously caused horizontal overflow on narrow screens.
- Verified plan tab selection by pointer and keyboard, widget light/dark changes, native FAQ expansion and absence of browser console errors.
- Validated local image references, unique section/tab IDs, three distinct download campaign links and existing privacy/support destinations.

## Deployment scope

Only the public GitHub Pages website changes. App Store metadata, approved builds and review/release state remain unchanged. This improves product explanation and the download path; it is not evidence of an increase in App Store impressions or organic search ranking.
