# Website motion — 2026-10-21

The homepage moves the way the app does: a live globe in the hero and real screen recordings of 1.0.9 in phone frames.

## Hero globe

`site/assets/globe.js` ports the trip globe from `WhereIsMyFriend/Features/Trips/TripGlobeBoard.swift` to a canvas, using the app's dark palette:

- Same land dots (`site/assets/land-dots.json`, from the `LandDots` asset, rounded to 0.1°), orthographic projection, lifted great-circle arcs and entrance timing (draw, fly, land, avatar pop, ripples, glint).
- Avatar colors are the app's dark person palette, chosen by the same SHA-256 name hash.
- It cycles through five example trips (Tokyo, Paris, Honolulu, New York, Sydney) and turns the globe between them. Origins are on the visible side so routes stay on the globe. Dragging turns it a little.
- It pauses off screen. With reduced motion it draws one still frame with everyone landed.

## Recordings

`site/assets/motion/*.mp4` (590×1282, H.264, about 0.2–0.9 MB each) with a WebP poster of the last frame. All demo data, iPhone 17 Pro simulator, iOS 27.0, status bar 9:41, from `feature/email-google-sign-in` at 1.0.9 (42).

| Clip | Launch arguments | What happens |
|---|---|---|
| `here-with-you` | `-skipOnboarding -resetDemoData -marketingOverlap` | Tap "Mia is here too"; the Here with you sheet opens |
| `together-soon` | same | Tap Together soon; the card expands to the Tokyo week |
| `moments` | `-previewMomentsHistory` | Same-city moments, then a short scroll |
| `friend-controls` | `-skipOnboarding -resetDemoData` | Lin's page; Same-city alert off and on |
| `trip-globe` | `-seedTripExamples -previewKauaiTrip -previewTrips` | Open Kauai Thanksgiving; routes draw in and everyone lands |
| `boarding-pass` | same | David's pass flips from Out to Back and back |

`trip-globe-preview.webp` is an animated WebP of `trip-globe` for the README (340 px wide, 12 fps).

The You tab shows the demo profile's real name, so no clip includes it; the moments clip starts after the push from You has finished.

## Tools

No ffmpeg on this Mac, so the clips use AVFoundation:

```bash
xcrun simctl io <udid> recordVideo --codec=h264 --force rec.mov   # stop with Ctrl-C
swiftc -O scripts/website_motion/clip.swift -o /tmp/clip
/tmp/clip rec.mov out.mp4 poster.png <start> <seconds> 590
```

`simctl` writes frames only when the screen changes, so `clip.swift` ends the session at the requested length to hold the last frame. `frames.swift` dumps PNG frames for a contact sheet or an animated WebP.
