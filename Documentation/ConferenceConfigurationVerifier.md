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
- `Conference Participant Nearby Follow-Up`
- `Conference Control Tower`

Current contract assertions:

- no validation errors from `CellConfigurationValidationService`
- all flattened `CellReference`s resolve
- all root probes are readable
- selected actions return `ok`

Current participant actions exercised:

- `Vis timeline`
- `Oppdater treff`
- `Oppdater discovery`
- `Start scanner`
- `Stop scanner`

Current nearby follow-up assertions:

- inject a deterministic verified nearby contact into the local conference radar
- open the follow-up chat handoff through the same Porthole wiring the UI uses
- verify that the nearby card upgrades to `Open chat`
- verify that purpose/interest text reflects verified overlap
- verify that participant preview state advances (`nextStep`, shared chat summary, recent message)

Current organizer actions exercised:

- `Publish content`
- `Discard draft`

Current render assertions:

- `Conference Participant Portal`
  - expected strings include `Conference Participant Portal`, `Entity Discovery`, `Start scanner`
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

Run organizer only:

```bash
./Scripts/run_conference_configuration_verifier.sh admin all
```

## What worked in the latest green run

Latest verified on March 27, 2026:

- `./Scripts/run_conference_configuration_verifier.sh all contract`
  - 3 tests
  - 0 failures
  - participant portal contract, nearby follow-up contract, and control tower contract all passed
- `./Scripts/run_conference_configuration_verifier.sh all render`
  - 2 tests
  - 0 failures
  - participant portal render and control tower render both passed

Observed isolated timings from the latest green checks:

- `Conference Participant Portal` contract: about `0.90s`
- `Conference Participant Nearby Follow-Up` contract: about `0.13s`
- `Conference Control Tower` contract: about `0.29s`
- `Conference Control Tower` render: about `2.51s`

These timings are useful as a moving baseline, not as hard budgets yet.

## What the verifier already caught

The verifier forced us to fix several real issues:

- direct `dispatchAction` buttons with explicit `url` were not fully understood by the diagnostics validator
- organizer `Publish content` / `Discard draft` were routed through a weaker nested path and could produce `notFound`
- participant conference actions needed direct endpoint routing for deterministic verification
- nearby follow-up chat needed deterministic local injection and post-action state reads, otherwise we could falsely pass or fail depending on shared runtime state
- coarse root probes like `conferenceParticipantShell.state` could report `notFound` even when the surface itself was readable through real descendant bindings
- running multiple verifier targets in one `xcodebuild` process allowed shared Porthole/runtime state to leak between tests
- render verification was too brittle when hosted through a temporary `NSWindow`
- long waits used to hang; now the verifier times out specific operations and reports them explicitly

## Known caveats

- The render verifier is currently macOS/AppKit-only.
- The contract runner is intentionally process-isolated now: the script launches one fresh `xcodebuild` per verifier test so singleton/Porthole state does not leak across cases.
- The test environment may still log local keychain noise like `-34018` and `missingMasterKey`; those logs do not currently fail the verifier when the surface itself resolves and renders correctly.
- A green verifier does not prove that staging is healthy. It proves that the local conference configuration, local fallbacks, local routing, and renderer contract are currently coherent.

## Recommended use

Before chasing a new conference regression in live GUI:

1. run the contract verifier
2. run the render verifier
3. only after that move to live staging/debug-panel/bridge tracing

That order keeps us from blaming staging for a broken local config, and it keeps us from blaming the config for a live auth or preview denial problem.
