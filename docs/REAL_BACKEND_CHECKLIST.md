# Connecting the real backend

The client is intentionally complete before infrastructure. Work through this checklist when the server and Apple account are ready.

1. Register the final App ID, App Group, Sign in with Apple capability, Push Notifications and background modes in the Apple Developer portal.
2. Replace the placeholder Team and confirm all bundle identifiers.
3. Build the schema from `DATABASE_SCHEMA.sql` with managed migrations.
4. Implement every endpoint in `API_CONTRACT.md` and server-side authorization integration tests.
5. Verify Apple identity tokens on the server using Apple keys, issuer, audience, nonce and expiry.
6. Store session tokens in a revocable server-side session table; the iOS access token remains in Keychain.
7. Encrypt APNs tokens at rest and run notification delivery through the outbox.
8. Replace `WIF_API_BASE_URL` and `WIF_INVITE_BASE_URL` in the Staging and Release build configurations. Both configurations intentionally set `WIF_ALLOWS_LOCAL_DEMO=NO` and fail closed until a real HTTPS API is present; never commit secrets.
9. Add certificate pinning only if the team can operate safe pin rotation; normal ATS HTTPS remains mandatory.
10. Run two-account tests covering invitation, mutual authorization, pause, removal, block, sign-out and deletion.
11. Complete a 72-hour multi-device background city test before enabling automatic location in production.
12. Add privacy policy, support URL, App Privacy answers, App Review test account and release feature flags.

Do not ship the local demo repository in the App Store build. Debug is the only configuration that enables it. Staging and Release select `UnavailableAppRepository` unless `-useRemoteAPI` is supplied and `APIConfiguration.fromBundle()` can load a non-placeholder HTTPS origin.

Before connecting infrastructure, the client already supports profile editing, invite deep links, blocking, Widget privacy modes, city normalization, same-city session entry/exit/cooldown, cached offline reads, coalesced mutation retry, and visible sync state. Keep server behavior aligned with those invariants rather than duplicating different rules.
