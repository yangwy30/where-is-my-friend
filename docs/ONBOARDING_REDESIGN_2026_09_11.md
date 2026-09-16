# Across Us onboarding refresh

Implemented September 11, 2026. This is a local app change, not a TestFlight upload.

## Direction

Four chapters share the same miniature-city scene and stable view identities:

1. Different cities. Still close. — friends in New York, Paris and Tokyo.
2. A little nudge. A real-life reunion. — people converge on Paris, followed by a notification-shaped example with the real app icon, app name, time, title and message.
3. Your next trip, together. — a shared Paris weekend, participant count and two example flight arrivals. Routes draw before the itinerary card appears.
4. Your city. Your privacy. — a single city label, no playback controls or extra privacy widgets.

Uses dedicated base-free edits of the CityEmblem raster assets, layered composition, soft contact shadows, a bounded drag tilt and spring transitions. Shared city assets elsewhere are unchanged. Asset paths and image-generation prompts are in [ONBOARDING_CITY_ASSETS_2026_09_11.md](ONBOARDING_CITY_ASSETS_2026_09_11.md). This is an illustrated 2.5D treatment, **not** a new 3D renderer or rotatable city model. No new dependencies, runtime asset downloads, location requests, repeating animation loops or automatic haptics.

## Interaction and accessibility

- Back, Skip, Continue and Get started remain available without waiting for animation.
- Skip and completion invoke the existing `onComplete` callback. Existing first-run and profile-preview routing are preserved.
- The discarded pause/resume preview control is removed. There is no repository or location-service access and no notification permission request.
- Notification and trip cards have discreet example labels; the repeated uppercase developer-preview caption is removed. Decorative cities and initials are grouped into descriptive accessibility labels.
- Reduce Motion shows the complete scene immediately, without delayed reveals, spring transitions or drag tilt. Cancellable chapter tasks prevent notifications appearing after a user leaves their page.
- Semantic text sizes, independently laid-out preview controls, scrolling content and a stable footer support larger text. Compact screens use a smaller hero and title style.
- Solar Jade and Night Jade use existing adaptive theme colors.

## Motion choreography

- Opening: Paris starts in a closer framing; New York and Tokyo enter 230 ms apart, followed by the people and connecting lines. The opening settles in roughly 1.5 seconds.
- Same-city: the camera refocuses on Paris, You moves next to Mia, a single ring dissipates, then the example notification slides down with a short spring response.
- Trips: two flights start 320 ms apart, follow quadratic curves with heading-aware plane icons and fading short trails, and reveal their arrival rows after reaching Paris. Route drawing and aircraft use the same curve parameter, avoiding mismatched tail positions.
- Privacy: deliberately still, with no recurring decorative effects.
- Drag: people, foreground landmark, distant landmarks and routes use different bounded parallax depths. Release springs them back to neutral.
- Sequences are cancellable view tasks, keyed to chapter, Reduce Motion and active scene state. There is no perpetual animation timer. Leaving the page or backgrounding cancels outstanding beats; navigation is never disabled by motion.
- Debug screenshot previews support `-previewOnboardingReducedMotion` alongside `-previewOnboarding`; this only overrides the preview and does not mutate system accessibility settings.

## Verification

- Simulator Debug build passed.
- `testOnboardingFourChaptersAndExamples`: four-page order, notification/trip examples, removed playback controls, back navigation and final CTA label.
- `testOnboardingCanSkipAndFinishFromProfile`: both Skip and Get started dismiss the real profile onboarding presentation.
- Motion follow-up: `testOnboardingMotionCanBeInterrupted`, `testOnboardingReducedMotionShowsCompleteExamples`, and `testFlightCurvesConvergeAndTrailsFollowTheAircraft` passed. The last test checks both endpoints, finite headings and agreement between aircraft and trail positions.
- Recorded the updated four chapters on iPhone 17 Pro Max. Frame-by-frame inspection confirmed the two aircraft advance along their curves before the arrival rows appear.
- Visual inspection on iPhone 17 Pro Max and a dedicated iPhone SE (3rd generation) simulator; light/dark and maximum accessibility text inspected. The initial oversized-text overlap was corrected by separating the example control from the scene.
- No physical-device, iPad or VoiceOver traversal pass in this change. Reduced Motion has explicit code paths but still merits a physical-device motion review.

## Preview

In a local demo build: You → Developer Lab & Tools → Preview onboarding.

The existing launch arguments remain supported: `-previewOnboarding -previewOnboardingStep=0` (or 1/2/3). This screenshot-preview entry point intentionally has a no-op completion callback; use the profile preview to exercise dismissal.

Do not interpret these fictional people/cities as live presence, exact location, a geofence, or an actual delivered notification.
