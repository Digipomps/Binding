# CellScaffold Skeleton Parity Prompt

Use this in the active `CellScaffold` thread when the goal is to eliminate renderer drift between web/scaffold and Binding.

## Goal

Treat skeleton rendering as a shared contract, not a Binding-specific integration detail.

The immediate objective is to build a staging-hosted skeleton parity suite in `CellScaffold` so Binding can verify:

- the same remote skeleton payload renders coherently in Binding
- the same payload is legible and structurally correct in CellScaffold web
- regressions are caught as parity failures instead of surfacing later as Binding workarounds

## Why This Pass Exists

Binding now has:

- deterministic local skeleton/configuration verifier
- remote conference smoke automation
- stronger remote-route registration before absorb

That is useful, but it still leaves a gap:

- Binding can prove local fixture parity
- Binding cannot yet prove that the exact same staging-hosted fixture skeletons render correctly across clients

This gap is now considered a product/platform bug, not acceptable demo noise.

## Required Deliverable In CellScaffold

Add a dedicated staging-hosted skeleton verification suite.

That suite should expose stable, intentionally non-product-critical remote cells dedicated to renderer verification.

Examples:

- `SkeletonParityTextFixture`
- `SkeletonParityListFixture`
- `SkeletonParityGridFixture`
- `SkeletonParityFormFixture`
- `SkeletonParityMarkdownFixture`
- `SkeletonParityRelativeKeypathFixture`
- `SkeletonParityNestedReferenceFixture`
- `SkeletonParityRemoteBridgeFixture`
- `SkeletonParityUnavailableFixture`
- `SkeletonParityInvalidFixture`

The names do not have to be exactly these, but the suite should be explicit and discoverable.

## Fixture Requirements

Each fixture should be:

- stable across runs
- safe to expose on staging
- deterministic in state payload
- deterministic in skeleton payload
- small enough to debug quickly
- rich enough to cover real renderer behavior

Each fixture should also define:

- expected visible headings
- expected structural sections
- expected button labels and action routes
- expected empty/loading/unavailable behavior where relevant
- expected failure mode for intentionally invalid cases

## Minimum Coverage

The staging-hosted suite should cover at least:

1. Basic structure
   - text
   - stacks
   - sections
   - dividers

2. Repeated content
   - `SkeletonList`
   - `flowElementSkeleton`
   - collection/grid cards

3. Binding paths
   - relative keypaths
   - absolute keypaths
   - nested object fields
   - `url`-based porthole references where still supported

4. Interaction
   - buttons with payloads
   - deterministic action responses
   - text field / text area draft bindings

5. Presentation-specific behavior
   - markdown text
   - long text wrapping
   - badge/chip text
   - unavailable/loading placeholders

6. Failure contract
   - at least one intentionally invalid fixture that should fail with clear diagnostics instead of silently degrading

## Deliverables Back To Binding

When this pass is done, Binding should receive:

1. A short fixture catalog
   - endpoint
   - purpose
   - expected visible strings
   - expected actions

2. Any routing/admission requirements
   - host
   - websocket route
   - admission requirement or explicit no-auth guarantee

3. Any known non-determinism
   - things Binding should not snapshot-compare yet

4. A “next pass” note
   - what Binding should wire first against the new suite

## Parallel Work Split

CellScaffold owns in this pass:

- staging-hosted fixture cells
- stable remote routes
- stable payload/skeleton contract
- web-side confidence that fixtures render correctly in Scaffold itself

Binding owns in parallel:

- parity runner wiring
- remote route and absorb robustness
- screenshot and visible-string verification on the Binding side
- local-vs-remote comparison harness

Do not wait on Binding to design the fixtures.
Do not ask Binding to fake remote parity with more local fallbacks.

## Synchronization Protocol

We are explicitly working in parallel. Use this lightweight sync loop:

1. At the start of each pass, read the other thread's latest “next pass” note before changing direction.
2. End each pass with:
   - what changed
   - what is now ready for the other thread
   - what is still blocking
   - exact endpoints/files/tests to use next
3. Keep the sync note concrete and short.

Recommended format:

- `Next pass for Binding: ...`
- `Next pass for CellScaffold: ...`

## Prompt To Paste Into CellScaffold

```text
Treat skeleton rendering as a shared cross-client contract, not a Binding integration detail. Build a staging-hosted skeleton parity suite in CellScaffold using stable remote fixture cells dedicated to renderer verification. Cover basic structure, lists/flowElementSkeleton, grids, forms, markdown, relative vs absolute keypaths, nested bindings, deterministic actions, loading/unavailable states, and at least one intentionally invalid case with a clear failure contract. For each fixture, document the endpoint, purpose, expected visible strings, and expected actions. Keep the suite deterministic and safe for staging. Do not optimize for the current Binding demo only; optimize for a reusable renderer-contract suite that Binding and future scaffold clients can test against. End the pass with a short handoff note for Binding that lists what is ready to consume next, including exact endpoints and any admission/route constraints.
```

## What Binding Will Do In Parallel

Binding will use the delivered fixture catalog to:

- add remote parity tests beside the local verifier
- compare expected visible strings and screenshots
- fail the parity gate when local and remote drift
- reduce or remove product-specific renderer workarounds where the fixture suite proves the shared contract
