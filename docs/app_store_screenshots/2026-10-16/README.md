# App Store screenshots for 1.0.8 — 2026-10-16

Approved by the user on 2026-10-16 for the 1.0.8 listing. Not uploaded yet: 1.0.7 is still in review, so the 1.0.8 version doesn't exist in App Store Connect.

Five frames, English and Chinese, in four sizes each: `1320x2868` (6.9"), `1284x2778` and `1242x2688` (6.5"), and `1206x2622` (6.3"). All are opaque RGB PNGs.

| # | Background | Screen | English | Chinese |
|---|---|---|---|---|
| 01 | lime | Friends, three friends in your city | Where are your friends today? — Shared cities, never exact locations. | 朋友们，现在都在哪？— 只分享所在城市，不显示精确位置。 |
| 02 | mist | Together soon timeline | Same city. Same dates. — See the days your plans overlap. | 行程重叠，约上见一面 — 提前发现你们在同一座城市的日子。 |
| 03 | ink | Shared trip flight map | Coming from everywhere. — Everyone’s flights, on one map. | 从四面八方，飞到一起 — 大家的航线，放在同一张地图上。 |
| 04 | mist | Friends (large, light) and Here together (medium, dark) widgets | Friends, one glance away. — Home Screen widgets, light or dark. | 把朋友，放在主屏幕 — 浅色深色两款小组件，一眼看到朋友。 |
| 05 | lime | Friend detail with Share my city and Same-city alert | City-level only. Your call. — Choose who sees your city, friend by friend. | 只到城市，边界由你定 — 按好友单独开关共享城市和同城提醒。 |

Frame 03 doesn't use "Different cities. One destination." because the map screen already says "Different cities. Same destination."

## Design rules

- One idea per frame: a two-line headline, one line of support copy, and the product.
- No labels above the headline, no floating stickers, and nothing overlapping text.
- Lime (`#A6E677`) is the only accent and matches acrossus.app. Other backgrounds are mist (`#F3F4F0`) and ink (`#0E1A13`).
- English uses Geist (in `assets/`); Chinese uses PingFang SC.
- Real 1.0.8 captures only, with the status bar at 9:41.

## Sources

`raw/` holds the captures:

- `store-*-friends.png` and `store-*-together-soon.png` were captured from `ui/1.0.8-combined` with demo data (the 108 captures from the 2026-10-15 set).
- The flight map, friend detail and widget captures were taken on 2026-10-16 from `ui/1.0.8-combined` on an iPhone 18 Pro Max simulator, with `-skipOnboarding -resetDemoData` and the status bar overridden to 9:41.
- Flight map: `-previewTrips -seedTripExamples`.
- Widgets: `-previewWidgets`, plus `-widgetPreviewDark` for the dark one.

## Render

```bash
NODE_PATH=<dir with sharp>/node_modules node scripts/render_store_20261016.mjs
```

The script renders HTML with headless Google Chrome, then writes `en/` and `zh-Hans/`. Temporary files go to `.work/`, which isn't committed.
