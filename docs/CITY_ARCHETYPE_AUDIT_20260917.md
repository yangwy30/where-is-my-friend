# Audit of the new city archetype illustrations

Reviewed incoming commits `3cef555` and `f31d183` against shipped build 14 (`876df1b`). Their scope is illustration assets, fallback selection and tests; Trip/notification/backend behavior was not changed.

## Findings and disposition

1. **State-name inconsistency.** The new rules recognized postal codes for most states but not full names. `AZ` and `Arizona` could select different artwork. Resolved using the existing country-scoped administrative alias catalog.
2. **Unscoped locality assumptions.** US dictionaries accepted absent country/state metadata, combined California and Washington names under the same guard, and some international names ignored country. Required known US country/state, partitioned reviewed names by state/country, and kept incomplete metadata on the generic fallback.
3. **Substring false positives.** Fragments such as `key`, `ski` and `field` inside unrelated names selected coast/mountain/farmland artwork. Changed keyword motifs to complete words. Regression tests use ambiguous/scoped names and synthetic word-boundary cases.
4. **Corrupt alpine PNG alpha.** The chalet roof contained visible transparent holes. Two imagegen repairs produced opaque checkerboard backgrounds rather than valid RGBA output; both were rejected and excluded from the repository. The broken alpine imageset was removed from this release. Alpine fallback uses the existing intact generic neighborhood until a valid chalet asset is available. Five other new illustration families and the updated generic/globe assets are retained.
5. **Missing-asset recovery.** If a specialized fallback asset cannot be loaded, the renderer now tries the intact generic neighborhood before falling back to a system symbol. Unknown/private geography remains separate.

## Scope of the artwork

Country/state style defaults remain artistic motifs, not verified geographic classifications. They do not replace actual city/state labels, alter same-city identity, merge cities, or affect notifications. Existing curated landmarks keep their precedence. Comprehensive geographic disambiguation of the older landmark registry is outside this diff.

## Validation

- App/Widget simulator build succeeded; 144 unit tests and two UI workflows passed: `/private/tmp/across-archetype-audit.xcresult`.
- Asset checks cover bundled loading, transparency and visible content. Added regression coverage for state aliases, absent metadata, cross-country/state namesakes, whole words, and equal artwork with unequal city identity. Existing hidden-presence tests passed.
- The first comparison capture inherited Night Jade from an earlier simulator run. The test was corrected to explicitly select Solar Jade before its first capture and then Night Jade; the corrected light/dark workflow passed in `/private/tmp/across-archetype-light-dark.xcresult`. Both screenshots were visually inspected. This follow-up only changed test code; product source matches the archive snapshot.
- The damaged chalet's replacement attempts are preview-only files under Codex generated_images; they are not release assets. No production backend migration/deployment is needed for this change.
