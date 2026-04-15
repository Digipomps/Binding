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

## Identity modes

The verifier now has explicit identity modes instead of implicitly mixing keychain auth into every run:

- `startup`
  - uses `BindingStartupIdentityVault`
  - suitable for deterministic renderer/bridge verification
  - still produces real signatures and key agreement keys
  - avoids pulling Apple keychain auth into runs that are not trying to test Apple auth
- `test`
  - uses `BindingTests.testIdentityVault`
  - keeps older deterministic unit-test behavior for direct in-process test helpers
- `apple`
  - uses `IdentityVault.shared`
  - intended for signed macOS runs that explicitly verify Apple keychain-backed auth

The runner script defaults to `startup` for conference verifier runs. To verify Apple auth explicitly, run the verifier signed:

```sh
./Scripts/run_conference_configuration_verifier.sh identity render apple signed
```

## 2026-04-13 bridge verification outcome

What now works:

- the scaffold-hosted `ConferenceAIGatewayPreview` path renders through ordinary bridge resolution from Binding
- the live staging bridgehead at `https://staging.haven.digipomps.org` is verified on app revision `328bb465dfd47a22e470baa6603458cca1c93970`
- `./Scripts/run_conference_configuration_verifier.sh ai render` passed twice in a row after the bridgehead deploy and verifier identity fix

What those successful runs depend on:

- `CellScaffold` bridgehead must target the logical bridge reference (`bridgeId`) as the inbound publisher reference
- the verifier requester identity must carry a real `publicSecureKey` and be able to produce verifiable signatures
- no special skeleton path is involved; the same `CellConfiguration` loads through the same bridge/renderer stack as other remote cells

What we learned:

- the earlier timeout was two separate contract failures stacked together:
  - bridgehead route semantics on the scaffold server
  - verifier identities that were not cryptographically valid bridge identities
- once both were corrected, the AI assistant path became a normal remote-cell render instead of a conference-specific exception

## 2026-04-13 signed auth outcome

What now works:

- a signed macOS run of `testConferenceAIAssistantRenderer` passed with the Apple vault active
- a signed macOS run of `testConferenceIdentityLinkRenderer` also passed with the Apple vault active
- in those signed runs, the verifier used the Binding app container paths under `~/Library/Containers/com.digipomps.Binding/...`, which is the expected sandboxed app context

What this supports:

- the earlier `Authenticate failed ... -34018` was a verifier-runner mismatch, not evidence that Binding-on-macOS cannot use Apple keychain auth
- ordinary renderer/bridge verification should stay on `startup` mode unless the purpose of the run is explicitly to verify Apple auth behavior

## Files

- Verifier core: [BindingTests.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/BindingTests/BindingTests.swift)
- XCTest wrapper: [CellConfigurationVerifierXCTest.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/BindingTests/CellConfigurationVerifierXCTest.swift)
- Runner script: [run_conference_configuration_verifier.sh](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Scripts/run_conference_configuration_verifier.sh)

## What is covered now

Current conference surfaces:

- `Conference Demo Launcher`
- `Conference Scaffold Setup & Identity Link`
- `Conference Participant Portal`
- `Conference Participant Agenda Snapshot`
- `Conference Participant Chat`
- `Conference Nearby Radar`
- `Conference Participant Nearby Follow-Up`
- `Conference AI Assistant`
- `Conference Control Tower`
- `Conference Public Surface`
- `Conference Sponsor Follow-up`

Current contract assertions:

- no validation errors from `CellConfigurationValidationService`
- all flattened `CellReference`s resolve
- all root probes are readable
- selected actions return `ok`
- local fixture-backed conference shells now stand in for staging where deterministic verification matters:
  - `cell:///ConferencePublicShellFixture`
  - `cell:///ConferenceSponsorShellFixture`
- large composed conference pages can now use explicit composition probes instead of brute-forcing every inferred root probe

Current launcher assertions:

- the launcher resolves its local `ConferenceDemoLauncher` cell deterministically
- all launcher acts stay reachable through the same bridge path the GUI uses:
  - `Open public surface`
  - `Open identity link setup`
  - `Open participant cockpit`
  - `Open participant chat`
  - `Open control tower`
  - `Open AI assistant`
- the launcher can push the expected conference workbench configuration for each act without relying on hidden menu state

Current identity-link assertions:

- the identity-link workbench resolves the local `ConferenceIdentityLinkIntake`
- the workbench keeps explicit review state visible:
  - `incoming.statusSummary`
  - `incoming.challengeSummary`
  - `review.confirmationStatus`
  - `review.localIdentitySummary`
  - `review.nextStepSummary`
- deep-link or pasted challenge payload can be imported deterministically
- local review can be confirmed without inventing a separate Binding-only proof format
- `Back to launcher` returns through the same conference navigation pop bridge the GUI uses

Current AI assistant assertions:

- the production/menu path for the AI assistant resolves participant context plus scaffold-hosted `ConferenceAIGatewayPreview`
- the deterministic local verifier still uses an explicit local AI endpoint only for renderer/contract isolation, not as app-path truth
- setup and prompt controls stay reachable through the renderer path:
  - `Load copilot system prompt`
  - `Fill request: Daily brief`
  - `Fill request: Who should I meet?`
  - `Fill request: Follow-up plan`
  - `Fill request: Session priorities`
  - `Load session key`
- prompt draft and buffered session key state are readable after button execution

Current public / sponsor assertions:

- `Conference Public Surface` now has deterministic local contract/render coverage through `ConferencePublicShellFixture`
- `Conference Sponsor Follow-up` now has deterministic local contract/render coverage through `ConferenceSponsorShellFixture`
- public surface coverage proves the published landing/program/people/articles/facilities bindings stay readable even when staging is not part of the test
- sponsor follow-up coverage proves the inbox/compliance/retention bindings and action buttons stay wired without pretending the fixture is staging truth

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
  - `Åpne chatflate`
  - `Fjern markering` / `Marker for oppfølging`
  - `Be om møte`
- the focused participant state survives the local action refresh path instead of falling tilbake til rå preview-data
- when chat is already ready, the focused action opens the dedicated participant chat workbench instead of silently reusing a hidden shared-thread state

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
  - `Åpne chatflate` opens the explicit participant chat workbench after the local chat handoff
- the local snapshot now falls back directly to `ConferenceParticipantPreviewShell` instead of relying on hidden Porthole internals

Current participant chat assertions:

- the participant portal resolves a local `ConferenceParticipantChatSnapshot`
- the chat snapshot can open a dedicated participant chat workbench in Porthole without bypassing the existing participant shell
- the chat workbench keeps explicit summaries for:
  - `statusSummary`
  - `selectionSummary`
  - `nextStepSummary`
  - `actionSummary`
  - `focusedThread`
  - `recentMessages`
- the focused thread exposes concrete follow-up actions:
  - `Send oppfølging`
  - `Be om møte`
  - `Tilbake til portalen`
- chat readiness is now visible both inline in participant surfaces and in a separate dedicated workbench

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

## 2026-04-15 local verifier outcome

What now works locally:

- `./Scripts/run_conference_configuration_verifier.sh nearby contract startup unsigned` passed
- `./Scripts/run_conference_configuration_verifier.sh participant contract startup unsigned` passed
- `CatalogAbsorbXCTest/testPortholeAbsorbsConfigurationCatalogAsCatalogLabel` passed in a separate macOS run

What these successful runs depend on:

- Binding verifier runs use the same `startup` identity mode consistently instead of mixing in Apple-auth implicitly
- attached `CellReference` labels are allowed to become active before root probes and action execution are judged
- conference contract helpers that are pure value/build logic are treated as non-UI seams instead of inheriting `MainActor` unnecessarily

What we learned:

- the nearby/profile flake was not a skeleton-schema defect and not a special-case conference bug
- it was a deterministic attach timing issue between `loadCellConfiguration` and later root-probe/action assertions
- waiting for attached labels after load aligns the verifier with the same attach semantics the renderer already depends on

Remaining noise boundary:

- local Binding-owned verifier noise from duplicate local registration is reduced by treating duplicate coding-name registration as harmless
- remote parity still has separate staging-backed timeouts and should not be confused with local conference contract health

- `selectionSummary` points at the currently focused participant
- `matchSummary` explains how strong the currently focused or strongest nearby match looks
- `selectedEntity` exposes the currently focused participant card payload
- `selectedEntity.relevanceBadge` and `selectedEntity.relevanceSummary` make match strength explicit (`GRØNN MATCH`, `GUL MATCH`, `RØD MATCH`, or `NÆRHET FØRST`)
- `selectedEntity.followUpSummary` and `selectedEntity.chatSummary` make the next interaction step explicit
- `selectedEntityActions` expose the next concrete follow-up actions from that focused participant
- `spatialTruthSummary` explicitly says when one or more peers are nearby but direction is uncertain
- radar sectors now also carry `relevanceBadge`, so the embedded and full radar can show spatial direction and match strength together

Current nearby follow-up assertions:

- start the local nearby scanner through the same `dispatchAction` route the UI uses
- verify scanner status transitions to `started`
- inject a deterministic nearby candidate into the local conference radar
- execute `requestContact` before verified contact exists
- verify that the nearby card upgrades to `Contact pending`
- inject a deterministic verified nearby contact into the local conference radar
- open the follow-up chat handoff through the same Porthole wiring the UI uses
- verify that the nearby card upgrades to `Åpne chatflate`
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

- `Conference Demo Launcher`
  - expected strings include `Conference Demo Launcher`, `Open public surface`, `Open identity link setup`, `Open participant chat`, `Open control tower`
- `Conference Scaffold Setup & Identity Link`
  - expected strings include `Conference Scaffold Setup & Identity Link`, `Incoming challenge`, `Import challenge`, `Confirm local key & continue`, `Back to launcher`
- `Conference Participant Portal`
  - expected strings include `Conference Participant Portal`, `Entity Discovery`, `Start scanner`, `Radar i siden`, `Åpne full radar`
- `Conference Nearby Radar`
  - expected strings include `Conference Nearby Radar · Full oversikt`, `Start scanner`, `Tilbake til portalen`, `Valgt deltager`
- `Conference Participant Chat`
  - expected strings include `Conference Chat`, `Tilbake til portalen`, `Delte tråder`, `Siste meldinger`
- `Conference AI Assistant`
  - expected strings include `Conference AI Assistant`, `Copilot Setup`, `Conference Prompt Presets`, `Prompt Draft`, `Invoke conference copilot`
- `Nearby Participant Profile`
  - expected strings include `Valgt deltager · profilflate`, `Åpne full radar`, `Tilbake til portalen`, `Neste steg`
- `Conference Control Tower`
  - expected strings include `Conference Control Tower`, `Publish content`, `Operations & Insights`
- `Conference Public Surface`
  - expected strings include `AI & Digital Independence`, `Publication & Access`, `Tracks & Program Highlights`, `People, Articles & Facilities`
- `Conference Sponsor Follow-up`
  - expected strings include `Conference Sponsor Follow-up`, `Lead Inbox`, `Consent, Unlock & Retention`, `Refresh inbox`, `Run retention sweep`

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

Run demo launcher only:

```bash
./Scripts/run_conference_configuration_verifier.sh demo all
```

Run identity-link/setup only:

```bash
./Scripts/run_conference_configuration_verifier.sh identity all
```

Run AI assistant only:

```bash
./Scripts/run_conference_configuration_verifier.sh ai all
```

Run nearby radar only:

```bash
./Scripts/run_conference_configuration_verifier.sh nearby all
```

Run organizer only:

```bash
./Scripts/run_conference_configuration_verifier.sh admin all
```

Run public or sponsor only:

```bash
./Scripts/run_conference_configuration_verifier.sh public all
./Scripts/run_conference_configuration_verifier.sh sponsor all
```

## What worked in the latest green run

Latest verified on March 30, 2026:

Targeted green checks:

- `./Scripts/run_conference_configuration_verifier.sh chat contract`
- `xcodebuild -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantPortalContract -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantPortalRenderer -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantMatchmakingSnapshotSupportsInlineSelectionAndActions -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantDiscoverySnapshotSupportsInlineSelectionAndActions -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantChatContract -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantChatRenderer`
- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantPortalContract`
- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantAgendaSnapshotSupportsInlineSelectionAndActions`
- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantMatchmakingSnapshotSupportsInlineSelectionAndActions`
- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantDiscoverySnapshotSupportsInlineSelectionAndActions`
- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantChatContract`
- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceParticipantChatRenderer`
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
