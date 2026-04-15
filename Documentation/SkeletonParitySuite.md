# Skeleton Parity Suite

This document defines the non-negotiable direction for skeleton rendering in the HAVEN stack.

Related architectural rule:

- [SkeletonPortabilityRequirement.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/SkeletonPortabilityRequirement.md)

## Requirement

Skeleton rendering must behave as one portable contract:

- the same `CellConfiguration` and `SkeletonElement` tree must render coherently regardless of where the cell runs
- Binding, CellScaffold, and future scaffold clients must all either render the same contract correctly or fail loudly with precise diagnostics
- renderer bugs must be caught by parity verification, not discovered ad hoc during demo work

This means we should stop treating remote skeleton issues in Binding as one-off UI fixes. They are contract failures.
It also means scaffold-local page replacements are not a scalable answer. Cache is fine; contract rewrites are not.

## What Binding already has

Binding already contains two useful pieces:

1. deterministic local verifier
   - `BindingTests/CellConfigurationVerifierXCTest.swift`
   - `Scripts/run_conference_configuration_verifier.sh`
   - verifies contract and renderer behavior against local preview cells and local fixture cells
2. remote staging fixture parity
   - `BindingTests/SkeletonParityRemoteXCTest.swift`
   - reads the CellScaffold catalog at `/skeleton-parity/api/catalog`
   - verifies remote `text`, `list`, `grid`, `form`, and `invalid` fixture contracts over HTTP
   - verifies one bridge-backed pass against `cell://staging.haven.digipomps.org/SkeletonParityTextFixture`
   - reuses one in-memory cookie jar per test case so mutable fixture behavior stays deterministic
3. remote staging smoke
   - `Scripts/run_conference_demo_smoke.sh`
   - opens the real app and drives staging-backed conference surfaces through the same menu automation the demo uses

That gives us a good base, but it is not yet a full parity suite.

## Current gap

Today the local verifier proves that Binding can render a fixture-backed contract.
It does not yet prove that the exact same skeleton payload hosted remotely by CellScaffold renders identically in Binding.

That gap is where many "small Binding fixes" keep coming from.

## Target architecture

We should treat skeleton verification as three explicit layers:

1. local contract parity in Binding
   - fixture-backed
   - deterministic
   - fast enough for regular test runs
2. remote parity against staging-hosted fixture cells
   - CellScaffold should host dedicated skeleton-fixture cells or a dedicated skeleton-suite endpoint
   - these cells must return stable state and stable skeleton payloads meant only for renderer verification
   - Binding should load those remote fixtures without product-specific fallbacks hiding renderer defects
3. visual parity evidence
   - capture screenshots for the same suite in at least:
     - Binding
     - CellScaffold web
   - compare expected visible strings, section order, and structural composition

## What the staging-hosted suite should contain

CellScaffold should expose a dedicated skeleton verification catalog with intentionally stable cases such as:

- simple text, stacks, sections, dividers
- lists with `flowElementSkeleton`
- grids and collection cards
- buttons with payloads and action routing
- text field and text area bindings
- relative keypaths vs absolute keypaths
- `url`-based porthole references
- nested object bindings
- markdown text rendering
- loading, empty, and unavailable states
- remote bridge-backed references
- intentionally invalid cases that must fail with specific diagnostics

These should not be conference-only. Conference should be one product suite on top of a more general renderer suite.

## Binding responsibilities

Binding should own:

- strict renderer verification against local fixtures
- remote staging parity runs against the same suite
- diagnostics that say exactly which binding, section, action, or visible string diverged
- smoke automation for demo-critical surfaces

CellScaffold should own:

- staging-hosted fixture cells
- stable fixture payloads
- stable route availability for remote skeleton verification

## Immediate gate

The script `Scripts/run_skeleton_parity_suite.sh` is now the first practical gate in Binding:

- `local`
  - runs the deterministic local configuration verifier
- `remote`
  - runs the staging-hosted skeleton fixture contract suite
  - then runs the staging-backed conference smoke
- `all`
  - runs both

Remote fixture tests are opt-in for direct `xcodebuild` runs and are enabled in the script via `BINDING_ENABLE_REMOTE_PARITY=1`.
This is still phase 1, not the end state.

## 2026-04-15 status

Locally in Binding, the conference verifier gates are now green for the important demo surfaces:

- `nearby contract startup unsigned`
- `participant contract startup unsigned`
- `CatalogAbsorbXCTest/testPortholeAbsorbsConfigurationCatalogAsCatalogLabel`

That supports one narrow but important conclusion:

- current local conference regressions are no longer being hidden by Binding-side skeleton rewrites or ad hoc fallback logic
- the remaining parity failures are still remote staging failures, not local renderer-contract drift

Last observed remote parity result:

- `zsh Scripts/run_skeleton_parity_suite.sh remote ...`
- 10 of 12 staging-backed tests passed
- the remaining failures were:
  - bridge-backed fixture timeout (`notConnected`)
  - HTTP timeout for the remote text fixture configuration endpoint

So the current practical boundary is:

- local Binding contract/render parity is strong enough to gate normal conference work
- staging parity is still valuable, but not yet reliable enough to be treated as a fully hard release gate on its own

## Phase 2

The next required implementation step across Binding and CellScaffold is broader coverage:

- expand Binding from the first fixture slice to the full suite (`markdown`, `relative-keypath`, `nested-reference`, `remote-bridge`, `unavailable`)
- add cross-host screenshot evidence for the same fixture set
- fail CI when local and remote parity diverge

Only when that exists can we honestly say skeleton rendering is verified independently of where cells run.
