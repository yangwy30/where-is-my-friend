# App Store listing redo — 2026-10-14

Draft only. Nothing here has been uploaded to App Store Connect. The live listing is still 1.0.6 with the 2026-10-11 screenshot set.

## Review of the live listing (1.0.6)

**Screenshots** (2026-10-11 set): the visual system is consistent and the UI captures are real. Problems:

1. The first three images (the ones shown in search results) are Friends, Widgets and Friends' plans. The main differentiator, overlapping travel plans, only appears as image 4, and group trips are not shown until image 6.
2. Images 1 and 5 show almost the same Friends screen. The caption "Same city. Familiar faces." repeats image 1's subtitle "Shared cities. Familiar faces."
3. Three of eight images cover flights (6–8), which overweights one feature.
4. Nothing addresses the main hesitation with a location app: whether friends can see your exact position.
5. Some headlines read awkwardly: "Your next 'See you there.'", "Flight by flight."
6. The "01 / 08" page counter adds noise.
7. **The Chinese widget image shows an English widget** ("Friends, near and far.", "Shared cities"). That widget source capture was taken from an English simulator.

**Text:** The description reads like review notes. It covers audience defaults, the 100-friend limit, saved-audience behaviour, and three paragraphs of disclaimers. It never says who the app is for. The promotional text repeats the description's opening line. The English keywords use 62 of 100 bytes.

## What changed

Screenshots: 7 per locale at 1206×2622, 1284×2778 and 1320×2868, reusing the 2026-10-11 native captures.

| # | Old | New (EN) | New (ZH) |
|---|---|---|---|
| 1 | Your friends. City by city. | Where are your friends today? — *Shared cities, never exact locations.* | 朋友们，现在都在哪？ |
| 2 | Friends, one glance away. (widgets) | Same city. Same dates. (overlap card, cropped) | 行程重叠，约上见一面 |
| 3 | Where friends are headed. | Different cities. One destination. (route map) | 从不同城市，飞向同一站 |
| 4 | Your next "See you there." | Where friends are headed next. | 朋友的下一站，提前知道 |
| 5 | Same city. Familiar faces. | Friends, one glance away. (widgets) | 把朋友，放在主屏幕 |
| 6 | Your next trip. Together. | Group trip? All in one place. | 一起出发，安排都在一处 |
| 7 | Different cities. One destination. | Who's landed, who's en route. | 谁已落地，谁还在路上 |
| 8 | Your trip. Flight by flight. | *(removed)* | |

- The first three images now cover the three things the app does: where friends are now, when your plans overlap, and travelling together.
- Image 1's subtitle carries the privacy reassurance.
- The duplicate same-city image and one of the flight images are removed. The page counter is removed.

Text (`listing.json`):
- The description now opens with who the app is for and what you get. It is organised into four scannable sections, keeps one privacy section and one short footnote, and drops plan-audience implementation details. It is about half the old length.
- New promotional text. It can be changed without review, so it is a good place for seasonal hooks.
- Keywords: English 99/100 bytes, Chinese 93/100 bytes. Neither repeats words already in the name or subtitle.
- Name and subtitle are unchanged.

## Known gaps

- **Fixed 2026-10-14:** the Chinese widget image (05) now shows the Chinese widget. The Home Screen widget and the small Here together preview were recaptured on a zh-Hans iPhone 18 Pro Max simulator with demo data (`testCaptureActualMarketingWidgets`, `testCaptureRefinedWidgetsChinese`). The captures are in `docs/widget_redesign/2026-10-14-zh-Hans/`.
- The Chinese captures show city names in English ("相聚 Tokyo", "Paris"). This is app behaviour, not a screenshot issue.

## Render

```bash
NODE_PATH=<dir with sharp>/node_modules node scripts/render_marketing_20260925.mjs --set=2026-10-14 --no-pager
```

`--no-pager` is new and hides the "NN / NN" counter. Older sets render as before. The widget compositions are in `compositions/` (copies of the 2026-09-26 study with the counter removed). To refresh them after changing the widget study, run the study renderer, copy without the counter line, then run the set renderer above:

```bash
NODE_PATH=<dir with sharp>/node_modules node scripts/render_widget_presentation_study.mjs
for l in en zh-Hans; do sed '/>02 \/ 08<\/text>/d' docs/app_store_screenshots/2026-09-26/widget-study/$l-wallpaper-detail.svg > docs/app_store_screenshots/2026-10-14/compositions/$l-widgets.svg; done
```

Checked 2026-10-15: running this sequence from a clean copy reproduces all 42 posters and both contact sheets byte for byte.
