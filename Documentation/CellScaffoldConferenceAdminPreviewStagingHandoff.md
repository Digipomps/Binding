# CellScaffold Handoff: Conference Admin Preview on Staging

Date checked: 2026-03-31

Context:
- Binding `main` now routes conference demo start through `Conference Demo Launcher`.
- `Conference Public Surface` is intentionally staging-backed because staging is the deployed CellScaffold instance.
- Binding-side routing/build still looks healthy.
- The organizer/admin preview gap is now best understood as a deployment mismatch: local CellScaffold code and tests are green for fresh admin preview content/system state, while staging still serves the older fallback strings.

## Summary

`Conference Public Surface` on staging still looks healthy.

`Conference Control Tower` on staging is no longer a broad preview-shell failure. Access, audience discovery, access requests, insights, sponsor, session thread, session polling, and simulation are already returning meaningful state. The concrete organizer gap visible in staging right now is narrower:

- `content` still returns the older unavailable fallback strings
- `system` still returns the older denied metrics fallback strings

The important update since the previous check is this:

- local CellScaffold route tests now prove that fresh admin preview identities can read the organizer-backed published-content admin state and proof-backed admin metrics state
- fresh admin preview identities now also get explicit organizer/admin proof material plus preview-specific agreements for the admin shell, published content, and admin metrics lanes when those cells are present

So the remaining problem is no longer “we do not know how to make admin preview work.”
It is “staging has not yet been rolled to the code that makes those lanes work.”

## Current staging observation

Direct staging check on 2026-03-31 still returns the old fallback values from:
- `GET https://staging.haven.digipomps.org/conference-admin-preview/api/state?previewAdminId=preview-fresh-check`

Observed values:
- `content.intro = "Published content editor unavailable."`
- `content.lifecycleSummary = "Published content state unavailable."`
- `system.status = "Live admin metrics unavailable."`
- `system.topProcessSummary = "AdminOverview lookup failed: denied"`

Host check at the same time showed staging still running:
- repo HEAD: `40c63ca`
- `origin/main`: `40c63ca`
- container: `cellscaffold-app-1   Up About an hour`

That means the host is currently consistent with deployed `main`, but not with the local uncommitted CellScaffold fixes that now pass the relevant tests.

## What is healthy on staging right now

### Public surface

The public route is healthy and serves:
- correct HTML shell title: `Conference Public Surface`
- correct configuration name: `Conference Public Surface`
- correct cell reference label: `conferencePublicShell`
- non-empty state for:
  - `workspace`
  - `tracks`
  - `sessions`
  - `people`
  - `articles`
  - `facilities`
  - `access`

### Admin preview configuration

The admin preview configuration itself is healthy:
- configuration name: `Conference Control Tower`
- source cell: `ConferenceAdminPreviewShellCell`
- reference label: `conferenceAdminShell`

### Admin preview state lanes already healthy on staging

These lanes already return meaningful state:
- `workspace`
- `access`
- `accessRequests`
- `audienceDiscovery`
- `insights`
- `sponsor`
- `sessionPolling`
- `sessionThread`
- `simulation`

That still supports the same high-level conclusion:
- the preview route is alive
- the wrapper shell is alive
- most organizer-side subcells are resolvable
- the remaining bad lanes are specific, not systemic

## What is now green locally in CellScaffold

These local tests now pass against the fresh admin preview path:

- `ConferencePlaywrightIdentityVaultTests/testConferenceFreshAdminPreviewIdentityInstallsOrganizerAndObserverProofs`
- `ConferenceSurfaceRoutesTests/testConferenceAdminFreshPreviewIdentityCanReadAdminSubcellsDirectly`
- `ConferenceSurfaceRoutesTests/testConferenceAdminFreshPreviewStateIncludesPublishedContentAndProofBackedSystemMetrics`
- `ConferenceShellCellsTests/testAdminPreviewShellUsesProofBackedRequesterForLiveSystemMetrics`
- `ConferenceShellCellsTests/testAdminPreviewShellExposesOrganizerStateForForeignRequester`
- `ConferenceShellCellsTests/testAdminPreviewShellUsesStableOrganizerIdentityEvenIfVaultHasContextMapping`

What these prove:
- a fresh preview identity gets organizer same-entity proof
- a fresh preview identity gets organizer admin role grant
- a fresh preview identity gets explicit scaffold admin observer proof
- the preview path can read `ConferencePublishedContent.adminState`
- the preview path can read `AdminOverview.state`
- `/conference-admin-preview/api/state?previewAdminId=preview-fresh-check` can return non-fallback `content` and `system` objects locally

## CellScaffold changes that matter

Highest-signal code anchors:
- `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Sources/App/Cells/ConferenceMVP/ConferenceAdminPreviewAccessSupport.swift`
- `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Sources/App/Cells/ConferenceMVP/ConferenceAdminPreviewIdentity.swift`
- `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Sources/App/Cells/ConferenceMVP/ConferencePlaywrightPersonaBootstrap.swift`
- `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Sources/App/Cells/ConferenceMVP/Cells/ConferenceAdminShellCell.swift`
- `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Tests/AppTests/ConferencePlaywrightIdentityVaultTests.swift`
- `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Tests/AppTests/ConferenceSurfaceRoutesTests.swift`

In practical terms, the local fix did three things:
1. fresh demo-preview identities now receive explicit organizer/admin proof material, including scaffold admin observer proof
2. admin preview now seeds explicit preview agreements for the admin shell, published content admin state, and admin metrics observer state when those cells are available
3. organizer-backed fallback/requester selection in `ConferenceAdminShellCell` is now strong enough that the published-content and metrics lanes resolve correctly in the real route path

## Revised likely problem shape

The current status now suggests this split:

- Binding routing is not the active problem
- fresh admin preview logic in CellScaffold is locally fixed
- staging is still serving an older build that does not contain the fresh admin preview content/system repair

So the next likely win is no longer more preview architecture work.
It is rolling staging to the updated CellScaffold build and then re-checking the exact same endpoint.

## Revised suggested debug/deploy order

1. Roll staging to the updated CellScaffold build
- get the fresh admin preview fixes onto the actual staging host
- rebuild/restart `cellscaffold-app-1`

2. Re-check the exact admin preview state endpoint
- `GET /conference-admin-preview/api/state?previewAdminId=preview-fresh-check`
- confirm `content` and `system` no longer use the old fallback strings

3. Re-run Binding parity against the same staging host
- only after staging has the new build
- Binding should not carry extra compensating logic for a server-side gap that is already fixed locally

4. Only if staging still fails after rollout
- inspect whether host build inputs differ from local source or whether another runtime-only proof/config mismatch exists on host

## Expected outcome for Binding parity

Binding should be able to load staging admin preview without filling major sections with unavailable placeholders.

Minimum parity target after rollout:
- access section populated
- content section populated
- insights section populated
- sponsor section populated
- system section populated when the fresh preview identity carries the intended admin-observer proof/agreements

## Binding-side status

Binding commit used during the earlier check:
- `9a6384bc` `Align Binding conference demo launcher with staging`

Binding-side conclusion remains:
- public surface routing is healthy
- admin preview routing is healthy
- the remaining organizer problem is staging rollout parity, not dead preview routing
