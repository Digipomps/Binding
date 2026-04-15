# Skeleton Portability Requirement

This document captures a non-negotiable architectural rule for Binding and future scaffold clients.

## Core rule

`CellConfiguration` and skeleton JSON must be treated as portable UI contracts.

That means:

- a scaffold client must render the contract it receives
- a scaffold client must not replace a remote/product contract with a local page-specific fallback just because rendering or integration is inconvenient
- if the contract is broken, the client should fail loudly, diagnose precisely, and let parity tooling catch it

## Why this matters

Skeleton JSON is much closer to HTML than to app-local view code.

We would never say:

- "this website does not render correctly here, so let us hardcode a local replacement page for it in this browser"

That does not scale.

The same is true here:

- we cannot maintain one local fallback per conference page
- we cannot maintain one local fallback per scaffold
- we cannot maintain one local fallback per remote product surface

If every scaffold starts inventing its own replacements for the same contract, then the platform stops being a platform. It becomes a growing pile of app-specific interpretations.

## What does not scale

These patterns do not scale:

- Binding-only local replacements for specific remote conference surfaces
- scaffold-specific rewrites of canonical section hierarchies
- product-specific compatibility layers that silently mask renderer or contract bugs
- per-surface local preview cells becoming the de facto truth instead of the shared contract

This creates several failure modes:

- parity bugs are hidden instead of fixed
- clients drift from each other over time
- every new scaffold inherits more special cases
- changing one canonical skeleton requires touching many local copies
- demo work starts producing patches that make one app look good while the shared platform gets weaker

## What is allowed

Local cache is allowed.

That is an important distinction.

Allowed:

- cache the same remote `CellConfiguration`
- cache the same skeleton JSON
- cache state snapshots for offline use or startup speed
- replay cached content when the remote source is temporarily unavailable

Not allowed:

- replace the canonical contract with a different local layout
- rename, reshape, or reinterpret the contract in one scaffold only
- invent local fallback sections that are not part of the shared skeleton contract

Cache preserves the contract.
Local fallbacks rewrite the contract.

## Correct response to drift

When a surface fails remotely, we must classify the failure correctly:

- renderer drift
- contract drift
- staging/deploy drift
- legacy repair/fallback drift

Then we fix the right layer.

We should not solve:

- renderer bugs
- attach/admission bugs
- remote route bugs
- stale product contracts

by replacing the failing surface with a local scaffold-specific version.

## Practical requirement for Binding

Binding should aim for:

- one renderer for the shared skeleton contract
- parity verification for local and remote fixtures
- deterministic diagnostics when a contract cannot be rendered correctly
- minimal, explicit legacy support only where migration is temporarily unavoidable

Binding should avoid:

- accumulating local conference-page stand-ins
- making demo polish depend on scaffold-local forks of canonical surfaces

## Consequence

If a remote skeleton does not render perfectly in Binding, the default answer must be:

- fix the shared contract, the renderer, the route, or the deploy

not:

- add another Binding-only fallback page

That is the only direction that scales across many cells, many products, and many scaffolds.
