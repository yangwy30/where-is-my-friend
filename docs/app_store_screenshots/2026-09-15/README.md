# Across Us — refreshed marketing screenshots

## Creative direction

Retains the September 3 set's bright green / warm sand palette, oversized dark headlines, rounded screenshots, and soft shadows. All App imagery is captured from the current SwiftUI implementation using local demo data. Layout, headline, subtitle, and footer are HTML/CSS; the raw captures remain unmodified. English headlines match the previous store set.

## Sequence

1. **Your friends. Around the world.** — Friends and latest shared cities.
2. **Same city. Time to say hello.** — Expanded Here together card.
3. **Your next “See you there.”** — An overlap from mutually shared personal plans.
4. **More places. More time together.** — The multiple-Trip library.
5. **Different flights. One reunion.** — A shared Trip's routes and arrivals.
6. **A glance closer.** — The App's Widget Studio preview.
7. **Your city. Your choice.** — City sharing controls.

## Deliverables

- `contact-sheet.png`: overview of the complete sequence.
- `gallery.html`: full-size local gallery.
- `1290x2796/`, `1284x2778/`, `1242x2688/`: seven opaque PNG posters per size.
- `raw/`: original simulator PNGs exported from XCTest attachments.
- [Current bilingual listing](../../APP_INTRO_20260915.md).

The 1284 × 2778 set has been uploaded in sequence to the App Store 1.0.2 draft, shared by its English and Simplified Chinese localizations. Version 1.0.2 (build 9) has now been submitted for public review; status is Waiting for Review, with automatic release after approval. The Widget image is the App's built-in preview; sample flights and friend names are demo data. Headlines do not promise instantaneous city updates, live aircraft tracking, or automatic messaging.

## Reproduction

Run `PrototypeUITests/testCaptureSeptemberMarketingScreenshots` and `PrototypeUITests/testPersonalPlanCreatesOverlapAndRevokingShareRemovesIt` on an iPhone 17 Pro Max simulator, with parallel testing disabled and local simulator signing enabled (`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`). Export the result bundle using `xcresulttool export attachments`. Map the seven named attachments to the filenames in `raw/` referenced by `scripts/render_marketing_screenshots.mjs`.

Run the renderer with Node.js, Playwright, and Chrome installed. Set `NODE_PATH` to the available Node package directory if necessary. It renders all three sizes and the contact sheet from the same source layout.

## Capture verification

- Current working-tree build, iPhone 17 Pro Max (1320 × 2868), iOS 26.4.1, local demo repository.
- Both capture workflows passed: **2 tests, 0 failures**. Result bundle: `/private/tmp/across-us-marketing-signed-20260915.xcresult`.
- Earlier unsigned simulator runs exited unexpectedly; the final exported raw files all come from the successful locally signed run.
- The original September 3 marketing set is retained. No App Store upload, release, or backend change was performed.
