# App Store 1.0.1 submitted — September 11, 2026

User requested updating the public App Store version to include the latest client features and invitation crash fix.

## Completed

- Verified current App Store version is **1.0**, Ready for Distribution, using **1.0.0 build 2**.
- Created **1.0.1** update draft in App Store Connect.
- Saved What's New covering the invitation/relaunch crash fix, shared Trips, redesigned onboarding and UI improvements.
- Updated the draft description and reviewer notes to distinguish on-device GPS/city presence from voluntarily submitted trip/flight itineraries. Removed the misleading blanket statement that the server stores no routes.
- Retained existing screenshots, URLs, contact details, ratings and automatic-after-approval release configuration.
- User approved updating the public privacy policy and App Store privacy declarations.
- Published bilingual policy dated **September 11, 2026**, covering shared Trips/flight records, member visibility, flight-provider queries, push identifiers and accurate shared-record retention after account deletion. GitHub commit `4a9449313070bb800f5d40f41cb418e54fbe4e0b`; Pages run `34627712811` succeeded. Verified live HTML contains the new date and disclosures.
- **Build 7 finished processing and was selected and saved** in the 1.0.1 App Store draft. Verified selected row `7 / 1.0.1 / No App Clip`; build 6 was not selected.
- Updated and saved the description's account-deletion bullet to explain that shared trip records may remain for other members, consistent with the policy.

## Final submission status

- **Submitted successfully.** Apple displayed **1 Item Submitted** and **1.0.1 Waiting for Review**, with zero draft submissions remaining.
- Submission ID: `6bd1fd52-d320-4ca8-bc0a-a44de067fea9`.
- The final submission panel explicitly showed **1.0.1 (7)** before Submit for Review was clicked. No build 6 was submitted.
- **App Privacy fully published**: Name, Contacts, Other User Content, Device ID, Other Diagnostic Data, Coarse Location, User ID, and Search History. All eight are App Functionality, linked to identity, not used for tracking. The user explicitly confirmed the conservative Search History classification/linkage after the safety review pause; it was then published and the pending-setup warning disappeared.
- Existing contact details were not fabricated or changed. Apple accepted the submission without requesting additional contact values. Reviewer notes explain Apple-only sign-in.
- Automatic release after approval, immediate rollout, and existing ratings remain preserved. Approval/public availability is still pending; no monitoring automation was created.
- Browser CDP operations intermittently timed out. Native Chrome accessibility UI successfully completed the final submission and verified the authoritative success state.

Review: `https://appstoreconnect.apple.com/apps/6807634842/distribution/reviewsubmissions/details/6bd1fd52-d320-4ca8-bc0a-a44de067fea9`.
