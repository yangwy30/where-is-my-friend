# Connecting the real backend

The client is intentionally complete before infrastructure. The selected route is remote Supabase Staging; Docker is optional. Use this short checklist together with the detailed [Supabase implementation plan](./SUPABASE_PRODUCTION_PLAN.md).

1. Register the final App ID, App Group, Sign in with Apple capability, Push Notifications and background modes in the Apple Developer portal.
2. Replace the placeholder Team and confirm all bundle identifiers.
3. Create and link only the remote Staging project, run the PGlite test suite, review `db push --dry-run --linked`, then deploy the canonical migrations in `supabase/migrations/`; `DATABASE_SCHEMA.sql` remains the earlier reference design.
4. Map `app_users` to `auth.users`, migrate the Edge API from custom sessions to verified Supabase JWTs, and only then deploy the hosted API.
5. Configure the Supabase Apple provider and exchange the native Apple identity token plus original nonce through Supabase Auth.
6. Let Supabase Auth manage access/refresh sessions; keep the iOS session in Keychain and derive the current business user only from the verified JWT `sub`.
7. APNs token encryption, per-installation registration and the durable outbox worker are deployed to Staging. Before enabling delivery, set the APNs `.p8` and Key ID, rotate the worker bearer secret into both Edge Secrets and Vault, then schedule the reviewed Cron template.
8. Replace `WIF_API_BASE_URL`, `WIF_INVITE_BASE_URL` and `WIF_INVITE_HOST` in the Staging and Release build configurations. Both configurations intentionally set `WIF_ALLOWS_LOCAL_DEMO=NO` and fail closed until a real HTTPS API is present; never commit secrets.
9. Replace `TEAMID` in `apple-app-site-association.json`, host it at `/.well-known/apple-app-site-association` on each invite domain, and verify the content type and both production/staging App IDs.
10. Keep the Staging App Group, URL scheme, invite domain and APNs environment separate from Production. Confirm that installing or using Staging never changes the Production Widget.
11. Add certificate pinning only if the team can operate safe pin rotation; normal ATS HTTPS remains mandatory.
12. Run two-account tests covering invitation, mutual authorization, pause, removal, block, sign-out and deletion.
13. Complete a 72-hour multi-device background city test before enabling automatic location in production.
14. Add privacy policy, support URL, App Privacy answers, App Review test account and release feature flags.

Do not ship the local demo repository in the App Store build. Debug is the only configuration that enables it. Staging and Release automatically select `RemoteAppRepository` when `APIConfiguration.fromBundle()` can load a non-placeholder HTTPS origin, and otherwise fail closed with `UnavailableAppRepository`; `-useRemoteAPI` is only needed to opt a Debug build into a remote API.

Before connecting infrastructure, the client already supports profile editing, invite deep links, blocking, Widget privacy modes, city normalization, same-city session entry/exit/cooldown, cached offline reads, coalesced mutation retry, and visible sync state. Keep server behavior aligned with those invariants rather than duplicating different rules.
