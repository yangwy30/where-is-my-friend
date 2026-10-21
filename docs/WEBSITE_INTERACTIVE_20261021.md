# Interactive homepage — 2026-10-21

The homepage is a set of small, live versions of app screens that visitors can play with, in the app's own palette, type and emblem artwork. All names, cities and flights are examples (the footer says so).

| Section | What the visitor can do | Code |
|---|---|---|
| Hero globe | Pick a destination, drag to spin (with momentum), point at or tap a route to light up one friend's flight | `site/assets/globe.js` |
| Where are your friends today? | Switch the city you're in; friends there move up and "Mia is here too" follows. Tap a friend to flip to their next stop | `home.js` (Friends) |
| Same city. Same dates. | Drag your trip, or its ends, along two weeks; overlapping days with Lin light up and the count updates. Arrow keys work too | `home.js` (Together soon) |
| Same-city moments | Counts up and fills each friend's bar on scroll | `home.js` (reveal) |
| Everyone lands together | Pick anyone on the arrivals board for their boarding pass; Out and Back flip like the app's pass; Remind Mia; the pass tilts under the pointer | `home.js` (Trips) |
| City-level only. Your call. | Turn Share my city and Same-city alert on and off, see what Lin sees, send Lin to New York and watch whether an alert arrives | `home.js` (Privacy) |
| On your Home Screen | Switch the widgets between light and dark | `home.js` (Widgets) |

## Hero globe

A canvas port of the trip globe in `WhereIsMyFriend/Features/Trips/TripGlobeBoard.swift`, in the app's dark palette: the same land dots (`site/assets/land-dots.json`, from the `LandDots` asset, rounded to 0.1°), orthographic projection, lifted great-circle arcs and entrance timing (draw, fly, land, avatar pop, ripples, glint). Avatar colors are the app's person palette, chosen by the same SHA-256 name hash. Five example trips; origins sit on the visible side so routes stay on the globe. It moves on to the next city on its own until the visitor interacts, then waits 14 seconds.

## Accessibility and motion

- Every control is a real button, radio or switch; the trip bar is a slider that also moves with the arrow keys (Shift resizes).
- With reduced motion the globe draws one still frame with everyone landed, and transitions are cut to near zero.
- The globe pauses off screen. Tilt and the dark-section spotlight only run with a fine pointer.

## README preview

`site/assets/motion/trip-globe-preview.webp` is an animated WebP of the app's real trip globe, recorded from 1.0.9 (42) in the simulator with demo data (`-seedTripExamples -previewKauaiTrip -previewTrips`). To re-record:

```bash
xcrun simctl io <udid> recordVideo --codec=h264 --force rec.mov   # stop with Ctrl-C
swiftc -O scripts/website_motion/clip.swift -o /tmp/clip
/tmp/clip rec.mov clip.mp4 poster.png <start> <seconds> 590
swiftc -O scripts/website_motion/frames.swift -o /tmp/frames
/tmp/frames clip.mp4 <frames-dir> 12 340   # then join the PNGs into an animated WebP with sharp
```

`simctl` writes frames only when the screen changes, so `clip.swift` ends the session at the requested length to hold the last frame. The demo profile on the You tab shows a real name; keep it out of every capture.
