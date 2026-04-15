# CellScaffold Handoff: Public Profile Configurations and Tab Strip V1

Date checked: 2026-04-08

## What CellScaffold Has Done

CellScaffold now exposes two new conference-facing `CellConfiguration` entries directly from `ConfigurationCatalogCell`:

- `Conference Public Profile Editor`
- `Conference Public Profile`

Concrete code and exported config anchors:

- `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Sources/App/Cells/ConferenceMVP/Skeleton/ConferencePublicProfileConfigurationFactory.swift`
- `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Sources/App/Cells/ConfigurationCatalog/ConfigurationCatalogCell.swift`
- `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Documentation/ConfigurationCatalog/CellConfiguration.conference.public-profile.editor.json`
- `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Documentation/ConfigurationCatalog/CellConfiguration.conference.public-profile.json`
- `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Documentation/ConfigurationCatalog/CatalogConfigurations.md`

The important architectural point is this:

- these are real exported `CellConfiguration` payloads, not Binding-local workbench mirrors
- the editor points at `cell:///ConferencePublicProfileEditorPreview`
- the viewer points at `cell:///ConferencePublicProfilePreview`
- both are cataloged as ordinary menu-loadable configurations

## What Binding Changed

Binding now has a configuration-level endpoint retargeting pass so staging-backed configs can be consumed directly from exported `CellConfiguration` payloads without building a Binding-specific substitute configuration.

Concrete Binding changes:

- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/CellConfigurationEndpointRetargeting.swift`
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/ContentView.swift`
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/BindingTests/BindingTests.swift`
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/BindingTests/CellConfigurationVerifierXCTest.swift`

What changed in practice:

- `ConferencePublicProfileEditorPreview` and `ConferencePublicProfilePreview` are now treated as staging-backed scaffold cells
- Binding retargets endpoint-like strings across the whole `CellConfiguration` JSON shape, not only top-level `cellReferences`
- that means nested `configurationLookup.sourceCellEndpoint` payloads can also be lifted to staging instead of staying `cell:///...`
- Binding now has direct tests that load the exported CellScaffold JSON files and attempt to resolve them through the existing remote bridge path

## Test Result

Local Binding compile/test pass:

- the targeted `xcodebuild` pass compiled with the new retargeting code in place
- no new compile failures were introduced by the public-profile support work

Remote Binding verification against the exported CellScaffold configs:

- both new tests were run:
  - `testConferencePublicProfileEditorExportedCellConfigurationLoadsRemotely`
  - `testConferencePublicProfileViewerExportedCellConfigurationLoadsRemotely`
- both currently fail before skeleton/state verification completes

Observed failure shape:

- `Cloud Bridge connect failed with error: timeout`
- test failure surfaces as `notFound`
- logs also show missing signing identity in the remote admission path:
  - `Did not find vault identity for ...`
  - `consumeCommand signing data failed with error: noVaultIdentity`

Interpretation:

- the blocker is not the exported `CellConfiguration` shape itself
- the blocker is the current remote admission/identity path for these preview endpoints in the Binding verifier runtime
- Binding can now ingest the exported config objects directly, but the staging-backed preview cells still need a bridge/admission path that succeeds in this verifier context

## Tab Strip V1

Binding's current tab recommendation is documented here:

- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/TabStripSkeletonV1.md`

Recommended V1 contract:

- use `SkeletonList`
- set `selectionMode = single`
- set `selectionPayloadMode = item`
- use `selectionStateKeypath` for highlighted tab state
- use `activationActionKeypath` to load `selected.configuration`
- tag the list with `modifiers.styleRole = "tabstrip"`
- use `styleClasses` such as `top-pinned` or `bottom-pinned`

Row shape:

- `id`
- `title`
- optional `icon`
- optional `badge`
- `configuration`

Important constraint:

- please produce tabs directly as `CellConfiguration` data
- do not rely on Binding-only wrappers or an ad hoc `TabView` interpretation layer
- pin top or bottom through normal skeleton composition, not a new sticky primitive

## Next Pass For CellScaffold

- verify that `ConferencePublicProfileEditorPreview` and `ConferencePublicProfilePreview` are reachable through the same remote admission path Binding uses in verifier mode
- confirm whether these endpoints require a specific preview identity bootstrap that Binding cannot infer today
- if a specific requester/admission contract is required, document the exact identity context or route rule Binding should use
- if possible, expose one deterministic no-surprises verification route for each config, similar to the skeleton parity fixtures
- when tabbed conference flows are ready, emit them as `SkeletonList(styleRole: "tabstrip")` with `selected.configuration` payloads rather than introducing a divergent web-only tab contract

## Next Pass For Binding

- keep using the exported CellScaffold JSON files as the source of truth for these two configs
- once CellScaffold confirms the remote admission path, rerun the two new verifier tests against staging
- if CellScaffold ships a deterministic tabstrip-backed config, add it to the same direct-export verifier path instead of creating a local workbench clone
