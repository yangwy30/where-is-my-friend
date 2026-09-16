# Freestanding onboarding city assets

Built-in image_gen editing was used; no CLI fallback. Only onboarding consumes these sibling assets. The shared CityEmblem images are unchanged.

## Final assets

- `WhereIsMyFriend/Resources/Assets.xcassets/OnboardingNewYorkFreestanding.imageset/landmark.png`
- `WhereIsMyFriend/Resources/Assets.xcassets/OnboardingParisFreestanding.imageset/landmark.png`
- `WhereIsMyFriend/Resources/Assets.xcassets/OnboardingTokyoFreestanding.imageset/landmark.png`

All three PNGs have real alpha transparency. Thick presentation bases are removed. Small structural tower footings remain. Contact shadows are supplemented in SwiftUI.

## Verification

- Simulator build and four-chapter navigation UI test passed.
- `OnboardingAssetTests.testFreestandingCityAssetsHaveTransparentBackgrounds` passed: all three assets load from the app bundle, have transparent corners and contain visible landmark pixels.
- Shared city asset files were not replaced; only `OnboardingView` consumes these three new images.

## Prompts

### New York

Use case: precise-object-edit. Asset type: transparent PNG city landmark cutout for a refined cream-and-jade iOS onboarding. Image 1 is the edit target. Remove ALL thick silver/white platforms, trays, plinths, rounded square tiles, outlines and white ground patches, including the cast shadow of the removed platform. Preserve the recognizable landmark and its small companion object, original viewpoint and miniature 3D geometry. The objects should stand directly on an invisible ground plane. Keep only a very faint short soft contact shadow with translucent alpha directly below the objects, never an opaque white patch. Unified warm matte material, soft upper-left studio illumination, clean natural antialiased edges with NO white halo. Real transparent RGBA background, not black, white, beige or a checkerboard painted into the pixels. Square canvas, landmark fully visible, centered, fills roughly 80 percent of image height with even transparent margins; no cropping, no text, no frame, no new objects. Do not create a UI screenshot.
Subject/invariants: Keep the Empire State Building and the small yellow taxi. Remove the entire silver tray beneath both. Retain the warm ivory building and yellow taxi.

### Paris

Edit image 2 to match the freestanding, baseless treatment of image 1. Image 1 is the successfully finished New York asset and is the reference for background transparency, miniature matte material and lighting. Image 2 is the edit target. Keep its Eiffel Tower and its little green tree, but remove every silver display tray and pedestal underneath. Output ONLY the Eiffel Tower and its little green tree, isolated on an actual transparent background, as an RGBA PNG cutout just like image 1. All background pixels must be transparent. Preserve the original landmark identity and companion tree. No backdrop, no surface, no platform, no text. Square composition, entire landmark visible, occupying 80% of the canvas height.

### Tokyo

Edit image 2 to match the freestanding, baseless treatment of image 1. Image 1 is the successfully finished New York asset and is the reference for background transparency, miniature matte material and lighting. Image 2 is the edit target. Keep its red-and-white Tokyo Tower and its little pink cherry tree, but remove every silver display tray and pedestal underneath. Output ONLY the red-and-white Tokyo Tower and its little pink cherry tree, isolated on an actual transparent background, as an RGBA PNG cutout just like image 1. All background pixels must be transparent. Preserve the original landmark identity and companion tree. No backdrop, no surface, no platform, no text. Square composition, entire landmark visible, occupying 80% of the canvas height.

The first Paris/Tokyo attempts contained painted checkerboards; those variants were rejected and are not shipped. Successful final edits used New York as a transparency/material reference.
