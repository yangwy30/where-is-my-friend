# Across Us 1.0.4 (20) — replacement review build

## Included

- Personal-plan city search opens in a compact sheet with the search field near the top. Recent cities, Trip destinations and search results use text rows without city artwork or flags. Cities with a matching region name, such as Tokyo, show the country once.
- Trip destinations remain search shortcuts so the user confirms a city result with region and country before saving a personal plan.
- Includes account-scoped Trip refresh safeguards, clearer inline manual-refresh errors, and the exclusion of ended Trips from personal-plan import since build 18.
- Adds Simplified Chinese labels for the city picker, including the search prompt, Trip shortcut action and search errors.

Frozen source commit: `91ce98b`. Source tar SHA-256: `e55c5e4cb275f8dec0b21aecfe4ac9b928cf3e1af99bba6c650dfa4e1e4fec2f`.

## Verification and delivery

- iOS 27 simulator: 155/155 unit tests passed on the build 20 source; English city shortcut/search and Chinese picker UI tests passed (3/3 distinct UI tests).
- Production App and Widget are both **1.0.4 (20)**. The production backend and push environment are configured, and local Demo is disabled.
- Xcode archive and export succeeded. Exported IPA passed strict signature verification with Apple Distribution team `93RUQ2A6KX`; IPA SHA-256: `aa18a48c377a4940cdf50b86e52bdf903dc61e1e7cba426686289029a3d515d3`.
- Xcode upload succeeded on September 23, 2026 at 9:25 PM PDT. App Store Connect showed build upload status **Complete**, build ID `8b0cecbe-3d97-4652-a1a3-c75e330fb069`, assigned to the existing **Testers / Internal / 1 tester** group. Bilingual What to Test notes were saved.
- [TestFlight build page](https://appstoreconnect.apple.com/teams/9b0eb9fa-54ee-4f56-83ae-1e79e3cf4125/apps/6807634842/testflight/ios/8b0cecbe-3d97-4652-a1a3-c75e330fb069).

App Store Review submission: [Across Us 1.0.4 (20)](APP_STORE_1_0_4_REPLACEMENT.md).
