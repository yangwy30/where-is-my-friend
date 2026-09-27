# Widget presentation research — September 26, 2026

Research and composition study requested by the user: retain the system-wallpaper context, but avoid making the widget marketing image look like an entire phone.

## Official references inspected visually

- [Fantastical](https://flexibits.com/fantastical), “Fantastical Widgets” section: independent small/medium widget tiles in rows, with no phone enclosure. Useful lesson: give the component itself the visual weight.
- [Things — Interactive Widgets and More](https://culturedcode.com/things/blog/2023/09/interactive-widgets-and-more/), September 18, 2023: the introductory promotional artwork shows stacks of standalone rounded widget cards on a blue background. This is illustrative marketing artwork, not a literal Home Screen screenshot. Useful lesson: a component can be the object being promoted.
- [Widgetsmith](https://widgetsmith.app/), “One app; endless home screens” section: complete phones showcase coordinated wallpapers and widget styles. Useful lesson: preserve wallpaper's atmosphere and color relationship; the whole-phone composition is less suitable for this user's current request.

These are official website marketing examples, not a survey of current App Store conversions or evidence that one composition converts better.

## Draft direction

`comparison.png` shows the current next-release poster on the left and a proposed composition on the right.

- Retain real system wallpaper, the installed directory widget, and its Across Us Home Screen label.
- Crop away Search, Dock and unrelated application icons.
- Use a nearly square Home Screen detail with a modest outer corner radius, instead of a tall phone-shaped crop.
- Add a small real Here together widget as a separate secondary product detail.
- Keep the existing brand palette, title and position 2.

Both components are unchanged real SwiftUI captures. The main image is cropped from the installed Home Screen widget; the small component comes from the shared production-view preview. The two-component poster is an editorial composition and does not claim to be one full Home Screen screenshot.

## Files and status

- `zh-Hans-wallpaper-detail.png`, `en-wallpaper-detail.png`: 1284 × 2778 opaque PNG drafts.
- Matching SVG sources and `comparison.png`.
- Reproduce with `node scripts/render_widget_presentation_study.mjs`, with `sharp` in the module path.

This study does not replace the prepared eight-image upload set or modify the app. The user's instruction to keep approved 1.0.4 (20) unchanged and defer new store images to the next update remains in effect. No App Store Connect action was taken.
