# Friend plans navigation refresh failure

## Evidence

After build 21, a user reported the Friend plans screen showing “Couldn’t load shared plans. Try again.” Nearby hosted travel-plan requests returned HTTP 200, and a read-only account query returned a correctly structured shared-plan array. Those server observations alone cannot distinguish client cancellation from every other client failure.

A delayed repository regression reproduced a concrete client defect: Friends started a plan refresh, the destination screen requested the same data, and navigation cancelled Friends' task. `TravelPlanLibrary.refresh` returned immediately to the destination because `isLoading` was true; the cancelled first task then cleared shared plans and set the exact reported error. The pre-fix regression failed its plan, sync-state and error assertions.

## Fix

The library now owns one unstructured read task. Overlapping callers await that task; disappearance of an individual view does not cancel it. Only the active operation ID may apply results or clear loading state. Account changes and plan mutations invalidate and cancel the previous read. Cancellation is handled as control flow; real fetch failures still clear memory-only shared plans and show the existing retry state.

## Verification

- The navigation-cancellation regression failed before the fix and passed afterward.
- Added coverage for a new account replacing an in-flight read, saving while a read is pending, and Swift/URLSession cancellation handling. Existing network-failure and shared-plan privacy tests continue to pass.
- iOS 27: 162/162 unit tests and 2/2 UI tests passed (friend badge → profile plan → details, and Friend plans → copy a draft).
- No server data, sharing permissions or backend functions were changed for this fix.
