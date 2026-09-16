# Current-design review and next iteration — 2026-09-12

## Basis and limits

Reviewed the current SwiftUI implementation of Friends, Trips, You, personal travel-plan editing, upcoming overlap details and Trip people/invitations. Cross-checked the saved personal-travel screenshots. Live Simulator accessibility inspection timed out, so this is a code-backed flow review with saved visual references, not a completed live usability study. No application code, user data or deployment changed in this review.

Current source is authoritative over older design documents. Meeting-point/check-in presentation has been removed from Trips. Its dormant models/backend methods are not evidence of a visible feature.

## Already implemented — do not propose these as new features

- Multiple Trips, ongoing/upcoming groups, collapsed Past, completion/undo.
- City/dates-based Trip creation with generated name and optional custom naming.
- Own-flight add/edit/delete, missing-own-flight prompt, map and expandable flight detail.
- Trip invitations, member list and flight-notification settings.
- Personal city/date plans with explicit friend audience, private default, optional reminders and existing “Use dates from a Trip” flow.
- Current/upcoming match cards hidden when there is no matching event, except an explicitly opened unavailable notification.
- Upcoming detail already has “Say hello”, implemented as a system ShareLink rather than an in-app conversation.

## Recommended first iteration: make personal future-city planning discoverable

### Observed gap

`ProfileView` exposes the persistent `Travel plans` entry in You. The other entry, `Manage my plans`, is inside the expanded `UpcomingTogetherCard`. That card is hidden until a match exists. `FriendsView` has a Your city card, but it opens current-city sharing, not future plans.

Thus a person without any plans/matches may not discover where to enter the information needed to create a future match. This is a design inference, not a measured conversion result.

### Proposed change

Add one compact secondary row **below**, not nested inside, the existing tappable Your city card:

- No future plans: “Upcoming cities” / “Add a city”.
- Future plans exist: a concise next-city/date summary and an entry to manage the rest.
- Reuse the existing plan editor/library. Do not create another planning model or another Tab.
- Keep the You entry as a management shortcut; consider renaming its label to `Upcoming cities` / `未来城市安排` to distinguish it from Trips.
- Keep Here together / Together soon absent when there is no match. The planning entry is not an empty match card and must not imply a match exists.
- Keep plan visibility and reminders explicitly chosen. A future plan must not change current city or automatically share Trip dates with members/friends.

### Acceptance

A first-time user can find how to add a future city without navigating settings or already having a match. Saving a private plan does not create a false match or enable sharing. Removing/revoking a plan preserves the existing disappearance behavior.

## Second iteration: simplify the existing matching card

Current expanded upcoming details contain a city illustration, large headline, dates, days-together count, explanation, ShareLink, management link and back action. The saved screenshot shows this consuming a large part of the Friends screen.

- Preserve the existing expand/collapse interaction and Jade visual language.
- Keep the primary content to friend + city + dates, with a smaller city illustration.
- Replace implementation-oriented copy such as “1 upcoming overlaps” with a readable person/city/date summary; fix singular/plural wording.
- Keep a short clarification that this is based on mutually shared plans, not live location. Longer explanatory copy can use an information affordance; consent controls remain explicit in the editor.
- Retain the existing sharing action. Do not call it a new chat feature or imply it automatically contacts the selected friend.
- Once the persistent planning entry exists, remove redundant management/back controls from the card where the header already collapses it.

## Third, smaller Trips improvement: make invitations consistently discoverable

`FullTripArrivalBoard` has an explicit Invite friends action while there are no flights. Once flights exist, people management is primarily accessed by the participant-count button or the `People` menu item. A count can look like passive information.

- For an owner who can invite, make an invite affordance explicit next to the participant summary or as a clearly named toolbar action.
- Reuse `TripPeopleSheet` and its existing invitation logic; do not add another invitation surface or loosen owner-only authorization.
- For users who cannot invite, label the entry as viewing members instead of promising an unavailable action.
- Retain the existing own-flight prompt. Do not add a duplicate “next step” card or restore the removed meeting-point UI.

## What not to build in this iteration

No new meeting-point module, generic task engine, additional Tab, full chat system, automatic Trip-to-presence sharing, or extra notification category. A time-proposal/RSVP “meet up” feature would be genuinely new, but it should follow validation that users can discover and use the existing future-city flow.

## Suggested handoff order

1. Future-city entry and naming clarity.
2. Compact the existing matching card.
3. Consistent, permission-aware Trip invite entry.

Keep release reliability work separate: TestFlight install availability and physical-device login/push acceptance still need their existing release workflow. These product recommendations do not declare those issues resolved.
