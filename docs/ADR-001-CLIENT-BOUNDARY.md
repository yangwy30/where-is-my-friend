# ADR-001: Repository boundary before selecting a backend

- Status: Accepted
- Date: 2026-08-12

## Context

The iOS product needs authentication, friendships, per-friend authorization, city presence, Widget data and same-city events. A production database and server have not been selected yet. Coupling SwiftUI directly to Firebase, Supabase or a custom API would make that future choice expensive and would make offline product validation difficult.

## Decision

All application mutations and reads cross the `AppRepository` protocol. The App owns one `AppStore` that publishes a complete `AppSnapshot` to SwiftUI.

- `LocalDemoRepository` is a deterministic, persistent in-process implementation used for product development, UI tests and demos.
- `RemoteAppRepository` is an HTTPS REST adapter with Keychain session storage.
- SwiftUI, city presence rules, notification presentation and Widget caching do not know which repository is active.
- The local repository is not a security boundary. Production authorization is always enforced by the server on every request.

## Consequences

The full client can be implemented and tested without infrastructure. Connecting a server means implementing the documented endpoints and supplying `WIFAPIBaseURL`, rather than rewriting screens. Backend-specific realtime subscriptions may later extend the protocol, but must preserve the same authorization and snapshot semantics.
