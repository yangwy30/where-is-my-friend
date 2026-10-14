# Across Us — Design Specification

Status: v2 Liquid Glass client baseline

Target: iPhone, iOS 18+, WidgetKit
Working language: English, localization-ready from day one

## 1. Design direction: Quiet Atlas

The product should feel like a calm view of the people a user cares about, not a tracking dashboard. The visual language is warm, quiet, and human. Native Liquid Glass controls float above a softly colored atlas-like backdrop, while city and recency remain clearer than decorative effects. We deliberately avoid UI that implies precise, continuous surveillance.

The interface follows five principles:

1. **People before geography.** A friend’s identity is always the primary anchor.
2. **City before coordinates.** The product never shows pins, street-level maps, or exact coordinates in v1.
3. **Freshness is part of the fact.** Every city is paired with an update time or an explicit unavailable state.
4. **Privacy is visible.** Paused sharing, stale data, and permission issues are first-class states rather than hidden errors.
5. **Glass communicates hierarchy.** Navigation, controls, alerts, and compact moments may use glass; long-form content does not become a wall of translucent cards.

## 2. Information architecture

The primary tab bar contains only three destinations:

- **Friends:** current friend presence, same-city moments, friend details, invites, and requests.
- **Shared trips / 共同旅行:** invite travel companions and coordinate their flights and arrivals.
- **You:** profile, city sharing, notifications, privacy, blocked people, and account deletion.

Supporting flows:

**My travel plans / 我的出行计划** tells selected friends where you will be and when; **Friends’ travel plans / 好友出行计划** is the friend-facing view of that same information. Keep these separate from shared-trip membership. Shared trips links to My travel plans; My travel plans links back to the existing Shared trips tab.

Copy actions say **Add to my travel plans** or **Use these dates for my travel plan**. Confirm the city before copying an airport-based trip, then review dates and the audience in an unsaved personal-plan editor. New editors select all current, unblocked friends by default; users can deselect people or clear the selection before saving. Editing an existing plan preserves its audience, including prior exclusions. Show the copy source and explain that copied dates are saved independently. Copying never joins a trip, sends invitations, carries over trip participants as its audience, or enables overlap alerts. The default audience comes from the owner’s current friend list, not the copied plan or trip. Cancelling creates no plan. Both languages must communicate these boundaries.

```text
Onboarding
  → Continue with Apple (prototype action)
  → City-level privacy explanation
  → Background location education
  → Friends

Friends
  → Add friend
  → Friend requests
  → Friend detail
      → Share my city toggle
      → Same-city alert toggle
      → Remove friend

You
  → City sharing
      → Current city and location access
      → Global sharing and background updates
  → Notification preferences
  → Privacy & data
  → Blocked people
  → Delete account
```

## 3. Visual hierarchy

### 3.1 Friends screen

The home screen answers three questions in order:

1. Is anyone in the same city as me?
2. Where are my friends?
3. How current is each answer?

The header shows a noninteractive city status, such as “You’re in New York, NY.” An older observation is labeled as the last shared city; an unset city is explicit. Paused global sharing adds a quiet status line. Routine sharing controls live under **You → City sharing**. The home screen offers a contextual recovery action only when a city is missing or outdated, or an existing permission reminder is due.

**Selected design, 2026-10-10 — integrated header:** the same-city summary sits directly beneath the user's city status, without a separate large card, decorative city illustration, or duplicate headline. A small avatar group and a short line such as “Mia is here too” introduce the people; an understated freshness line follows. The freshness label uses the oldest observation participating in the match, including the user's own city observation. A thin divider separates this area from the remaining Friends content.

The summary starts collapsed and expands only when the user taps it. Refreshing data, returning to the foreground, changing tabs, or opening/replaying a same-city event link must not expand it. Expansion reveals compact friend rows that open the corresponding friend detail; the summary never opens sharing settings. Count and rows use the same eligible people, independently of whether alerts for those people are muted. With no eligible matches, the current summary is hidden. Historical or unavailable notification links retain their safe fallback. A retained event selection must never reopen a summary the user collapsed.

At accessibility text sizes, omit decorative avatars and allow names and freshness text to wrap. The summary has a minimum 48pt target, friend rows 56pt, and the explicit Collapse action 44pt. Reduced Motion uses the existing reduced-motion behavior.

Historical note: the September 2026 implementation used an independent expandable same-city card. The user rejected its size/visual form and selected the “integrated header” mock on 2026-10-10. The earlier manual-expansion decision remains in force; only its presentation and expanded detail hierarchy changed. Implementation and regression status are recorded in [the October audit](ui-deep-review-20261010/README.md).

Each friend row contains:

- avatar or initials
- display name
- country flag and city
- relative update time
- an explicit paused or unavailable state when appropriate

### 3.2 Friend detail

The friend detail page uses a compact identity header and a large city surface. It never displays a precise map. Relationship-specific controls are grouped under “Between you two.”

“Share my city” describes the effective saved state: a disabled per-friend preference says the friend cannot see the city; an enabled preference with global sharing paused explains the pause; an enabled preference without a city asks for a city to be set. Only enabled global and individual sharing with a known city says the friend can see the latest city. Resuming global sharing preserves individual choices.

### 3.3 Sharing

The sharing page explains why the app requests background location, what it stores, and how users can pause it. The permission education screen should precede the iOS system prompt and use a single clear continuation action.

The global “Share my city” switch and its effective sharing state appear before the decorative city display. Refresh/manual-city actions and background-update settings follow. Accessibility text sizes open the full-height sheet, so the primary privacy control does not depend on scrolling past city artwork.

### 3.4 Settings

The profile screen reports the user’s own city and update time, then groups settings into Sharing and Privacy. Account deletion is visible and destructive-colored without being visually dominant.

The privacy summary covers personal plans, shared trips and flights, and same-city history as well as account and city data. It distinguishes flight routes supplied by users from device movement trails. Both the summary and account-deletion confirmation explain that participant names and flights may remain in shared trips for other members after account deletion.

### 3.5 Same-city history

An active stay starts at the latest valid active session for that friend and city. Earlier visit events never extend the current duration. Without an active session, show a recent city match and its observation time instead of inventing a duration. Previous visits remain in history, and separate visits on the same day are not collapsed. A group event is part of the current stay only when every participant's current session covers its timestamp. Visible durations refresh every minute and when the app returns to the foreground.

## 4. Design tokens

SwiftUI uses semantic, adaptive colors rather than fixed light-only values. On iOS 26 and later, custom glass surfaces use SwiftUI's native `glassEffect`, nearby controls use `GlassEffectContainer`, and actionable controls use the system glass button style. iOS 18–25 receive a legible native Material fallback with the same layout and semantics.

### 4.1 Liquid Glass behavior

- The Tab Bar is the system floating Liquid Glass control and minimizes on downward scroll on supported systems.
- Glass is reserved for navigation, buttons, compact status cards, permission prompts, and same-city moments.
- Interactive glass opts into the system interaction response; informational glass remains noninteractive.
- Nearby glass controls share a `GlassEffectContainer` so their sampling and morphing behavior remains coherent.
- A calm green-and-blue ambient layer sits behind glass so refraction is visible without reducing readability.
- Standard SwiftUI controls are preferred so newer iOS releases can inherit Apple's system design refinements automatically.
- Reduce Transparency removes ambient blur decoration and keeps every control readable.

### 4.2 Color roles

| Role | Light appearance | Dark appearance | Usage |
| --- | --- | --- | --- |
| Canvas | warm off-white | deep green-black | Main app background |
| Surface | translucent warm white | translucent lifted green-black | Lists and grouped settings |
| Primary text | forest ink | soft white-green | Titles and key facts |
| Secondary text | muted gray-green | light gray-green | Timestamps and descriptions |
| Fresh accent | calm green | mint green | Active sharing and fresh presence |
| Event accent | green-to-blue | deep green-to-indigo | Same-city moments |
| Destructive | muted red | soft coral | Remove and delete actions |

Color must not be the only carrier of meaning. Freshness and sharing state always include text.

Opaque accent fills use `onFresh` for their text: white on the light theme's dark green, and dark ink on the dark theme's pale green. Destructive count badges use the corresponding `onDestructive` foreground. Avoid a fixed white foreground on either pale accent.

### 4.3 Typography

- Use San Francisco through SwiftUI system fonts.
- Large screen titles use rounded or default system design with semibold emphasis.
- City names and friend names use semibold emphasis.
- Supporting text uses regular weight and the platform’s secondary color role.
- All layouts must support Dynamic Type without truncating city status or privacy messaging.

### 4.4 Shape and spacing

| Token | Value | Usage |
| --- | --- | --- |
| Small radius | 12 pt | Chips and compact controls |
| Medium radius | 18 pt | Rows and grouped settings |
| Large radius | 24 pt | Event and city surfaces |
| Screen horizontal inset | 20 pt | Primary phone layout |
| Tight spacing | 6–8 pt | Related labels |
| Standard spacing | 12–16 pt | Rows and components |
| Section spacing | 22–28 pt | Major information groups |

## 5. Presence states

Every friend must resolve to one of these UI states:

| State | Rule | Display behavior | Same-city eligible |
| --- | --- | --- | --- |
| Fresh | Updated less than 2 hours ago | Normal emphasis, green time accent under 30 minutes | Yes |
| Aging | Updated 2–24 hours ago | Secondary emphasis and exact relative time | Product decision; default No |
| Stale | Updated more than 24 hours ago | “Location unavailable” with last update in detail | No |
| Paused | Friend paused sharing | “Sharing paused” | No |
| Permission unavailable | System permission prevents updates | Explain remediation to the owner only | No |

## 6. Widget specification

Friend-directory widgets open the displayed friend: the small widget has one destination, and medium/large widgets have a link per friend row. Hidden identities use a generic destination. The app validates links against the current account after refreshing; unavailable friends receive a clear recovery message. Aggregate same-city widgets retain their overview destination.

The Widget shares the same hierarchy as the App: city, friend, freshness.

### 6.1 Small

- Displays one featured friend from the latest shared snapshot.
- Shows friend, city, flag, and update time.
- Production version should allow friend selection through App Intents.
- Tapping deep-links to the friend detail page.

### 6.2 Medium — recommended default

- Displays up to three friends.
- Each row includes avatar, name, city, and compact update time.
- Prioritizes fresh favorites and same-city friends.
- Tapping a row deep-links to that friend.

### 6.3 Large

- Displays a same-city moment when one exists.
- Displays three to five additional friends.
- Makes paused and stale states visible without crowding the surface.

### 6.4 Widget refresh behavior

- Widget content is always last-known state.
- App and Widget read a shared Codable snapshot through the App Group store.
- Every entry carries its source update time.
- Timeline updates are best-effort and never described as real-time.

### 6.5 Lock Screen

- The rectangular accessory shows up to two prioritized friends in two columns.
- Each friend uses only two lines: first name and shared city. Friend update times are intentionally omitted at this size.
- Same-city friends are prioritized, followed by favorites and the most recently updated locations.
- The circular accessory shows the number of fresh friends in the user's current city and a compact city label.
- Both accessories use the existing Widget privacy mode and render compact hidden/empty states.
- Lock Screen accessories use the system's vibrant/accented rendering instead of the Home Screen gradient.
- Tapping either accessory opens the Friends tab.

### 6.6 Friend configuration

- Every Widget instance can optionally pin a first and second friend through the system Edit Widget interface.
- Friend choices come from the signed-in account's App Group snapshot and are searchable by name, username, or city.
- A valid configured friend takes priority in Home Screen and rectangular Lock Screen layouts.
- Without a selection, Widgets prioritize same-city friends, then favorites, then the most recently updated locations.
- Duplicate selections are collapsed. Removed friends, sign-out, and account changes safely fall back to the current snapshot.

## 7. Accessibility

- Friend rows expose one combined accessibility label containing name, city, and freshness.
- Avatar initials are decorative when the name is already present.
- Buttons use SF Symbols plus text where space allows.
- Controls use native `Toggle`, `Button`, `NavigationLink`, and `TabView` semantics.
- Same-city gradients preserve text contrast in both appearances.
- Important content remains legible at accessibility text sizes.
- Reduce Transparency removes nonessential ambient color and blur without removing content hierarchy.
- Reduce Motion should disable nonessential transitions in later animation work.

## 8. Localization

- English is the source language for the prototype.
- UI strings use `LocalizedStringKey` or string catalogs, never string concatenation for sentences.
- Simplified Chinese is the first additional localization.
- City names come from structured place data and use the device locale when rendered.
- Relative dates use Apple formatters rather than hand-built English suffixes in production.

## 9. Prototype acceptance criteria

The client baseline is complete when:

- it builds for an iOS simulator with no external dependencies;
- onboarding can be completed without real authentication;
- Friends, Sharing, You, add-friend, and friend-detail flows are navigable;
- mock presence data is shared by the App and Widget code;
- Small, Medium, and Large Widget families render from the same timeline entry;
- iOS 26+ renders native Liquid Glass surfaces and system glass controls rather than static blur imitations;
- iOS 18–25 renders the same flows using the Material fallback;
- light and dark appearance use semantic colors;
- model unit tests cover freshness and same-city eligibility;
- a UI smoke test can bypass onboarding and reach the Friends screen;
- no real location, backend, authentication, or notification API is called.

## 10. Deferred decisions

The client baseline intentionally defers:

- final public App Store name;
- final App Store icon refinements and an Icon Composer layered variant;
- backend vendor and API schema;
- actual Sign in with Apple authorization;
- Core Location permission requests and background behavior;
- APNs and Widget push integration;
- production App Intent friend configuration;
- analytics and crash-reporting vendors.

These decisions should be made only after the client is reviewed on a real iPhone and in the Widget Gallery.


### Review follow-up: invitations, appearance and form accessibility

Use “Share a meetup invite” for the system share action. Cancelling the system sheet must leave the plan unchanged and must not claim an invitation was sent. Pending outgoing friend invitations offer withdrawal; the server verifies the sender and pending state under a row lock. Accepted friendships survive withdrawal attempts.

The empty Friends screen leads with “Invite your first friend”, followed by adding someone by username. The friend-plan feed uses its navigation title once, a compact add action, and then content.

“Follow system” is the default appearance when no explicit choice is stored. Preserve saved Solar Jade and Night Jade choices. Widgets follow the same preference without overriding their system color scheme in automatic mode.

Form actions remain above the keyboard and provide a Done action. Interactive labels have at least 44pt touch targets. Auxiliary text sizes use vertical input layouts and wrapping names/cities; decorative images must not squeeze long text into narrow columns. Same-city history updates every minute while active and refreshes on foreground entry.

## UI review follow-up — 2026-09-29

- Incoming friend requests precede username and invitation actions; refresh on entry, and remove resolved requests from the priority section.
- Cancelling Apple authorization returns quietly to sign-in. Only the authorization cancellation error is suppressed; genuine failures retain feedback.
- Notifications has five category entry points: friend invitations, trip invitations, same-city alerts, personal-plan overlaps, and shared-trip flight/planning alerts. Keep per-friend and per-trip preferences. Distinguish saved preferences from delivery permission; when iOS notifications are off, offer authorization/settings recovery. Shared-trip controls use the same library state as the Trips tab.
- City search requires a country, region, valid time zone and locality, with a bounded compatibility case for Apple's exact Tokyo administrative-city record. Never broaden this into arbitrary province/state fallback.
