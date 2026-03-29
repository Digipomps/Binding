# Conference Configuration Verifier

This document describes the deterministic verifier we now use to keep conference `CellConfiguration`s honest in Binding.

## Why this exists

We repeatedly hit two classes of regressions:

- the `CellConfiguration` looked valid, but one or more `CellReference`s or action routes were broken at runtime
- the configuration contract was valid, but the renderer still failed to produce the expected conference surface

The verifier gives us two explicit layers:

1. `contract`
   - validates the configuration structure
   - resolves referenced cells
   - loads the configuration into `Porthole`
   - probes root keypaths
   - executes selected buttons/actions
   - records per-operation timing
2. `render`
   - renders the configuration in a real `NSHostingView`
   - waits for expected visible strings
   - records first meaningful content and total render time
   - fails if the expected surface never materializes

This is not a replacement for live staging auth/bridge debugging. It is a local regression net above the config/skeleton/runtime contract.

## Files

- Verifier core: [BindingTests.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/BindingTests/BindingTests.swift)
- XCTest wrapper: [CellConfigurationVerifierXCTest.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/BindingTests/CellConfigurationVerifierXCTest.swift)
- Runner script: [run_conference_configuration_verifier.sh](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Scripts/run_conference_configuration_verifier.sh)

## What is covered now

Current conference surfaces:

- `Conference Participant Portal`
- `Conference Participant Agenda Snapshot`
- `Conference Nearby Radar`
- `Conference Participant Nearby Follow-Up`
- `Conference Control Tower`

Current contract assertions:

- no validation errors from `CellConfigurationValidationService`
- all flattened `CellReference`s resolve
- all root probes are readable
- selected actions return `ok`
- large composed conference pages can now use explicit composition probes instead of brute-forcing every inferred root probe

Current participant actions exercised:

- `Vis for deg`
- `Vis timeline`
- `Vis lagret`
- `Fokuser governance`
- `Hele timeline`
- `Oppdater treff`
- `Oppdater discovery`
- `Start scanner`
- `Stop scanner`
- `Åpne full radar`
- `Åpne profilflate`

Current participant agenda assertions:

- the participant portal resolves a local `ConferenceParticipantAgendaSnapshot`
- agenda actions stay deterministic even when bridge or preview refresh fails after the local click
- the participant portal now requires explicit agenda selection grids:
  - `agendaSnapshot.state.modeChoices`
  - `agendaSnapshot.state.trackChoices`
- the participant portal contract now probes its composed snapshot surfaces directly:
  - `agendaSnapshot.state`
  - `matchmakingSnapshot.state`
  - `discoverySnapshot.state`
  - `nearbyRadar.state`
- the local snapshot preserves:
  - selected agenda mode
  - selected track focus
  - visible active-card badges (`AKTIV NÅ`, `FOKUS NÅ`)
  - focused action labels
  - next-step guidance
- transient sync issues now surface through `storageSummary` / `persistenceStatus` instead of resetting the visible agenda state
- the local participant renderer path now expects `0` occurrences of `Innholdet er ikke tilgjengelig akkurat nå.`

Current participant recommendation assertions:

- the participant portal resolves a local `ConferenceParticipantMatchmakingSnapshot`
- recommendation cards use the same inline-first action route the GUI uses
- `Vis i siden` focuses one participant inline on the current page
- the focused participant card exposes explicit next actions:
  - `Åpne chat`
  - `Fjern markering` / `Marker for oppfølging`
  - `Be om møte`
- the focused participant state survives the local action refresh path instead of falling tilbake til rå preview-data

Current participant discovery assertions:

- the participant portal resolves a local `ConferenceParticipantDiscoverySnapshot`
- discovery cards now follow the same inline-first rule as nearby and recommendations:
  - `Vis i siden`
  - explicit focused participant summary inside the current page
  - explicit next actions in the focused block
- focused discovery state is explicit and readable:
  - `statusSummary`
  - `selectionSummary`
  - `navigationSummary`
  - `nextStepSummary`
  - `focusedProfile`
  - `focusedActions`
- discovery action flow is deterministic and survives local refresh:
  - `Vis i siden` focuses the participant inline
  - `Marker for oppfølging` toggles inline follow-up state
  - `Åpne chat` upgrades in-place after the local chat handoff
- the local snapshot now falls back directly to `ConferenceParticipantPreviewShell` instead of relying on hidden Porthole internals

Current nearby radar assertions:

- the dedicated nearby-radar workbench resolves both `ConferenceNearbyRadar` and the participant preview shell
- nearby workbench contract checks now use an explicit focused root probe (`nearbyRadar.state`) instead of assuming the whole participant preview shell must be readable as one coarse root
- `Start scanner` and `Stop scanner` stay reachable through the same local direct-action route the GUI uses
- `Tilbake til portalen` returns through the same local action route the GUI uses
- a focused participant panel is rendered as part of the nearby-radar workbench (`Valgt deltager`)
- approximate MPC-only peers are kept separate from hard directional claims through a dedicated `Retning usikker` bucket
- the inline-vs-workbench transition is explicit:
  - `Vis i siden` focuses a participant on the current page
  - `Åpne full radar` opens the dedicated radar workbench
  - `Åpne profilflate` opens the dedicated participant profile workbench

Current nearby radar state assertions:

- `selectionSummary` points at the currently focused participant
- `selectedEntity` exposes the currently focused participant card payload
- `selectedEntityActions` expose the next concrete follow-up actions from that focused participant
- `spatialTruthSummary` explicitly says when one or more peers are nearby but direction is uncertain

Current nearby follow-up assertions:

- start the local nearby scanner through the same `dispatchAction` route the UI uses
- verify scanner status transitions to `started`
- inject a deterministic nearby candidate into the local conference radar
- execute `requestContact` before verified contact exists
- verify that the nearby card upgrades to `Contact pending`
- inject a deterministic verified nearby contact into the local conference radar
- open the follow-up chat handoff through the same Porthole wiring the UI uses
- verify that the nearby card upgrades to `Open chat`
- verify that purpose/interest text reflects verified overlap
- verify that participant preview state advances (`nextStep`, shared chat summary, recent message)
- stop the local nearby scanner through `dispatchAction`
- verify scanner status transitions to `stopped`
- verify that the selected participant flow stays coherent across:
  - inline focus in the current page
  - separate profile workbench
  - separate radar workbench

Current organizer actions exercised:

- `Publish content`
- `Discard draft`

Current render assertions:

- `Conference Participant Portal`
  - expected strings include `Conference Participant Portal`, `Entity Discovery`, `Start scanner`, `Radar i siden`, `Åpne full radar`
- `Conference Nearby Radar`
  - expected strings include `Conference Nearby Radar · Full oversikt`, `Start scanner`, `Tilbake til portalen`, `Valgt deltager`
- `Nearby Participant Profile`
  - expected strings include `Valgt deltager · profilflate`, `Åpne full radar`, `Tilbake til portalen`, `Neste steg`
- `Conference Control Tower`
  - expected strings include `Conference Control Tower`, `Publish content`, `Operations & Insights`

## Commands

Run all contract checks:

```bash
./Scripts/run_conference_configuration_verifier.sh all contract
```

Run all render checks:

```bash
./Scripts/run_conference_configuration_verifier.sh all render
```

Run participant only:

```bash
./Scripts/run_conference_configuration_verifier.sh participant all
```

Run nearby radar only:

```bash
./Scripts/run_conference_configuration_verifier.sh nearby all
```

Run organizer only:

```bash
./Scripts/run_conference_configuration_verifier.sh admin all
```

## What worked in the latest green run

Latest verified on March 29, 2026:

Targeted green checks:

- `./Scripts/run_conference_configuration_verifier.sh participant contract`
- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantPortalContract`
- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantAgendaSnapshotSupportsInlineSelectionAndActions`
- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantMatchmakingSnapshotSupportsInlineSelectionAndActions`
- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantDiscoverySnapshotSupportsInlineSelectionAndActions`
- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyRadarContract`
- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantNearbyFollowUpContract`
- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceControlTowerContract`
- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantPortalRenderer`
- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyRadarRenderer`
- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyParticipantProfileRenderer`
- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceControlTowerRenderer`
- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/BindingTests/conferenceNearbyRadarSeparatesApproximateSignalsFromFocusedParticipantActions`

Observed isolated timings from the latest green checks:

- `Conference Participant Portal` contract: about `1.55s`
- `Conference Participant Agenda Snapshot` focused-action contract: about `6.45s`
- `Conference Participant Matchmaking Snapshot` focused-action contract: about `1.92s`
- `Conference Participant Discovery Snapshot` focused-action contract: about `3.90s`
- `Conference Nearby Radar` contract: about `1.55s`
- `Conference Participant Nearby Follow-Up` contract: about `1.90s`
- `Conference Control Tower` contract: about `1.37s`
- `Conference Participant Portal` render: about `3.34s`
- `Conference Nearby Radar` render: about `2.79s`
- `Nearby Participant Profile` render: about `2.70s`
- `Conference Control Tower` render: about `3.54s`
- focused nearby-radar state truth test: about `2.07s`

These timings are useful as a moving baseline, not as hard budgets yet.

## What the verifier already caught

The verifier forced us to fix several real issues:

- direct `dispatchAction` buttons with explicit `url` were not fully understood by the diagnostics validator
- organizer `Publish content` / `Discard draft` were routed through a weaker nested path and could produce `notFound`
- participant conference actions needed direct endpoint routing for deterministic verification
- the dedicated nearby-radar workbench needed its own verifier path so local radar actions and return-to-portal routing do not silently drift
- nearby follow-up chat needed deterministic local injection and post-action state reads, otherwise we could falsely pass or fail depending on shared runtime state
- participant recommendations used to depend too directly on raw preview-shell state; the local matchmaking snapshot and its focused-action verifier now catch regressions in inline selection, follow-up marking, and chat handoff
- participant discovery used to depend on fragile live access through Porthole internals; the local discovery snapshot and its direct preview fallback now catch regressions in inline selection, focused actions, and follow-up state without hanging
- the agenda snapshot used to reset back to stale `viewSummary` / `trackSummary` values after a local click whenever the remote refresh path glitched; the focused-action contract test now catches that optimistic-state regression
- the nearby radar used to blur together “nearby” and “direction known”; the focused-state test now catches that by requiring `Retning usikker` and a selected participant action surface
- coarse root probes like `conferenceParticipantShell.state` could report `notFound` even when the surface itself was readable through real descendant bindings
- running multiple verifier targets in one `xcodebuild` process allowed shared Porthole/runtime state to leak between tests
- render verification was too brittle when hosted through a temporary `NSWindow`
- long waits used to hang; now the verifier times out specific operations and reports them explicitly

## Known caveats

- The render verifier is currently macOS/AppKit-only.
- The contract runner is intentionally process-isolated now: the script launches one fresh `xcodebuild` per verifier test so singleton/Porthole state does not leak across cases.
- If local tool sandboxing blocks `xcodebuild test` from writing to Xcode or SwiftPM caches, rerun the same verifier command with broader local execution privileges. Treat that as an environment issue, not as a conference regression.
- The test environment may still log local keychain noise like `-34018` and `missingMasterKey`; those logs do not currently fail the verifier when the surface itself resolves and renders correctly.
- A green verifier does not prove that staging is healthy. It proves that the local conference configuration, local fallbacks, local routing, and renderer contract are currently coherent.

## Recommended use

Before chasing a new conference regression in live GUI:

1. run the contract verifier
2. run the render verifier
3. only after that move to live staging/debug-panel/bridge tracing

That order keeps us from blaming staging for a broken local config, and it keeps us from blaming the config for a live auth or preview denial problem.
