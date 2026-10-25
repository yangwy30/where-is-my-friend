# App Store screenshots and listing for 1.0.9 — 2026-10-20

Proposed for the 1.0.9 submission; not uploaded. Screenshots and the description can only change with a new version in App Store Connect, so these go up when 1.0.9 is submitted. The promotional text can be changed at any time.

Six frames, English and Chinese, in four sizes each: `1320x2868` (6.9"), `1284x2778` and `1242x2688` (6.5"), and `1206x2622` (6.3"). All are opaque RGB PNGs. Contact sheets: `contact-en.png`, `contact-zh-Hans.png`.

| # | Background | Screen | English | Chinese |
|---|---|---|---|---|
| 01 | lime | Friends | Where are your friends today? — Shared cities, never exact locations. | 朋友们，现在都在哪？— 只分享所在城市，不显示精确位置。 |
| 02 | mist | Together soon timeline | Same city. Same dates. — See the days your plans overlap. | 行程重叠，约上见一面 — 提前发现你们在同一座城市的日子。 |
| 03 | ink | Trip globe, everyone landed on Kauai | Everyone lands together. — Every flight on its way to your trip. | 从各地出发，一起落地 — 每个人的航班，都飞向同一个目的地。 |
| 04 | mist | David's boarding pass | Every flight, one tap away. — Times, terminal and the flight home. | 每趟航班，一点就清楚 — 时间、航站楼和回程，一张登机牌看全。 |
| 05 | lime | Same-city moments by friend | All the days you shared a city. — Your time together, friend by friend. | 和朋友同城的每一天 — 按朋友记下你们在同一座城市的日子。 |
| 06 | ink | Friend detail with Share my city and Same-city alert | City-level only. Your call. — Choose who sees your city, friend by friend. | 只到城市，边界由你定 — 按好友单独开关共享城市和同城提醒。 |

Changes from the 1.0.8 set: the Apple Maps "Coming from everywhere" frame is gone (that screen no longer exists in 1.0.9); the trip globe, boarding pass and same-city moments frames are new; the widgets frame was dropped to keep six; Friends, Together soon and friend detail were recaptured on 1.0.9.

## Listing text

`listing.json` holds the full listing for both locales; `en-US-whatsNew.txt` and `zh-Hans-whatsNew.txt` hold What's New. Description changes from the live 1.0.8 text:

- Removed "then share a meetup invite" (the feature was removed in 1.0.8).
- Replaced "See all the routes on one map" with the globe and boarding pass.
- Added same-city moments by friend.
- Sign-in now names Apple, Google and email codes.

Name, subtitle and keywords are unchanged.

## Design rules

Same as the 1.0.8 set: one idea per frame, a two-line headline and one line of support copy, no labels above the headline, nothing overlapping text, lime (`#A6E677`) as the only accent with mist (`#F3F4F0`) and ink (`#0E1A13`), Geist for English and PingFang SC for Chinese, and real captures with the status bar at 9:41.

## Sources

`raw/` holds the captures, taken on 2026-10-20 from `feature/email-google-sign-in` (1.0.9 (42) code plus Chinese strings for the trip screen) on an iPhone 17 Pro simulator, iOS 27.0, with demo data only. They come from the UI test `testCaptureStore109` (attachments named `store-<lang>-<screen>`). The Kauai trip uses the demo friends' fictional names (`-previewKauaiTrip`); its Shanghai and New York flights are examples.

## Render

```bash
NODE_PATH=<dir with sharp>/node_modules node scripts/render_store_20261020.mjs
```
