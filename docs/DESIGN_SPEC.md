# Where Is My Friend? — Design Specification

Status: v1 static-prototype baseline

Target: iPhone, iOS 18+, WidgetKit
Working language: English, localization-ready from day one

## 1. Design direction: Quiet Atlas

The product should feel like a calm view of the people a user cares about, not a tracking dashboard. The visual language is warm, quiet, and human. We emphasize cities and recency while deliberately avoiding UI that implies precise, continuous surveillance.

The interface follows four principles:

1. **People before geography.** A friend’s identity is always the primary anchor.
2. **City before coordinates.** The product never shows pins, street-level maps, or exact coordinates in v1.
3. **Freshness is part of the fact.** Every city is paired with an update time or an explicit unavailable state.
4. **Privacy is visible.** Paused sharing, stale data, and permission issues are first-class states rather than hidden errors.

## 2. Information architecture

The primary tab bar contains only three destinations:

- **Friends:** current friend presence, same-city moments, friend details, invites, and requests.
- **Sharing:** current city-sharing status, location permission education, and sharing controls.
- **You:** profile, notifications, privacy, blocked people, onboarding replay, and account deletion.

Supporting flows:

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
  → Location access
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

The same-city moment uses a soft green-to-blue surface and stacked avatars. It appears only when at least one fresh same-city match exists. The rest of the screen is a simple people list rather than a map.

Each friend row contains:

- avatar or initials
- display name
- country flag and city
- relative update time
- an explicit paused or unavailable state when appropriate

### 3.2 Friend detail

The friend detail page uses a compact identity header and a large city surface. It never displays a precise map. Relationship-specific controls are grouped under “Between you two.”

### 3.3 Sharing

The sharing page explains why the app requests background location, what it stores, and how users can pause it. The permission education screen should precede the iOS system prompt and use a single clear continuation action.

### 3.4 Settings

The profile screen reports the user’s own city and update time, then groups settings into Sharing and Privacy. Account deletion is visible and destructive-colored without being visually dominant.

## 4. Design tokens

SwiftUI uses semantic, adaptive colors rather than fixed light-only values.

### 4.1 Color roles

| Role | Light appearance | Dark appearance | Usage |
| --- | --- | --- | --- |
| Canvas | warm off-white | deep green-black | Main app background |
| Surface | white | lifted green-black | Lists and grouped settings |
| Primary text | forest ink | soft white-green | Titles and key facts |
| Secondary text | muted gray-green | light gray-green | Timestamps and descriptions |
| Fresh accent | calm green | mint green | Active sharing and fresh presence |
| Event accent | green-to-blue | deep green-to-indigo | Same-city moments |
| Destructive | muted red | soft coral | Remove and delete actions |

Color must not be the only carrier of meaning. Freshness and sharing state always include text.

### 4.2 Typography

- Use San Francisco through SwiftUI system fonts.
- Large screen titles use rounded or default system design with semibold emphasis.
- City names and friend names use semibold emphasis.
- Supporting text uses regular weight and the platform’s secondary color role.
- All layouts must support Dynamic Type without truncating city status or privacy messaging.

### 4.3 Shape and spacing

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

The Widget shares the same hierarchy as the App: city, friend, freshness.

### 6.1 Small

- Displays one featured friend in the static prototype.
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

## 7. Accessibility

- Friend rows expose one combined accessibility label containing name, city, and freshness.
- Avatar initials are decorative when the name is already present.
- Buttons use SF Symbols plus text where space allows.
- Controls use native `Toggle`, `Button`, `NavigationLink`, and `TabView` semantics.
- Same-city gradients preserve text contrast in both appearances.
- Important content remains legible at accessibility text sizes.
- Reduce Motion should disable nonessential transitions in later animation work.

## 8. Localization

- English is the source language for the prototype.
- UI strings use `LocalizedStringKey` or string catalogs, never string concatenation for sentences.
- Simplified Chinese is the first additional localization.
- City names come from structured place data and use the device locale when rendered.
- Relative dates use Apple formatters rather than hand-built English suffixes in production.

## 9. Prototype acceptance criteria

The static prototype is complete when:

- it builds for an iOS simulator with no external dependencies;
- onboarding can be completed without real authentication;
- Friends, Sharing, You, add-friend, and friend-detail flows are navigable;
- mock presence data is shared by the App and Widget code;
- Small, Medium, and Large Widget families render from the same timeline entry;
- light and dark appearance use semantic colors;
- model unit tests cover freshness and same-city eligibility;
- a UI smoke test can bypass onboarding and reach the Friends screen;
- no real location, backend, authentication, or notification API is called.

## 10. Deferred decisions

The prototype intentionally defers:

- final public App Store name;
- production app icon and illustration assets;
- backend vendor and API schema;
- actual Sign in with Apple authorization;
- Core Location permission requests and background behavior;
- APNs and Widget push integration;
- production App Intent friend configuration;
- analytics and crash-reporting vendors.

These decisions should be made only after the static prototype is reviewed on a real iPhone and in the Widget Gallery.
