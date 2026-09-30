# Skeleton Parity Suite

This document defines the non-negotiable direction for skeleton rendering in the HAVEN stack.

Related architectural rule:

- [SkeletonPortabilityRequirement.md](SkeletonPortabilityRequirement.md)

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
   - now records which capture mode succeeded per step (`window`, `region`, or `fullscreen`) so a flaky macOS window capture no longer kills the whole smoke pass

That gives us a good base, but it is not yet a full parity suite.

## Original gap

Today the local verifier proves that Binding can render a fixture-backed contract.
It does not yet prove that the exact same skeleton payload hosted remotely by CellScaffold renders identically in Binding.

That gap is where many "small Binding fixes" keep coming from.

## Original-payload native/web captures (September 2026)

The snapshot test now hosts **BindingSkeletonView** in a real NSHostingView on
macOS, including AppKit-backed inputs. It decodes the original `skeleton.json`
and `root.json` and preserves style metadata. A legacy `skeleton.static.json`
is used only when no original exists, and the artifact records that distinction.
Style parity findings are diagnostics, not a reason to strip styles before testing.

The Binding host preserves List/Grid row templates and item/root data instead
of flattening Lists into VStacks. Extracted presentation panels retain row data
and stable identities scoped to their list. A light host opts into CellApple's
`skeletonHostTheme(.portholeLight)` defaults; dark mode retains the platform theme.
The matching CellProtocol renderer changes are required. Do not infer that the
unchanged production package pin contains those changes: use the coordinated
local workspace for integration, then update release dependencies together.

Create comparable inputs from the Binding repository:

```sh
python3 Scripts/capture_skeleton_parity_corpus.py \
  --base-url "$STAGING_BASE_URL" --output "$ARTIFACTS/original"
python3 Scripts/capture_skeleton_parity_corpus.py \
  --source-corpus "$ARTIFACTS/original" --output "$ARTIFACTS/candidate-host"
python3 Scripts/create_skeleton_element_corpus.py \
  --matrix "$CELLSCAFFOLD/Tests/fixtures/SkeletonElementParityMatrix.v1.json" \
  --output "$ARTIFACTS/elements"
node Scripts/render_skeleton_parity_web.cjs \
  --cellscaffold "$CELLSCAFFOLD" \
  --playwright-package "$CELLSCAFFOLD/node_modules/@playwright/test/package.json" \
  --corpus "$ARTIFACTS/elements" --output "$ARTIFACTS/web"
```

The first capture performs public GETs with an ephemeral cookie jar. The second
uses frozen bytes without network access and composes aliases only for identical
cell endpoints; it is explicitly a candidate host root, not the originally
deployed composition. The element generator covers the current 26 enum cases
at 390 and 1280 logical width. Supplemental Tree/ComponentSurface inputs come
from existing semantic oracles and are distinct from raw all-modifier stress fixtures.

For native execution, build the coordinated workspace for testing and set
`BINDING_SNAPSHOT_CORPUS_DIR` and `BINDING_SNAPSHOT_OUTPUT_DIR` in the BindingTests
test target's environment. For `test-without-building`, copy the generated
`.xctestrun` beside the original and edit its `TestConfigurations[].TestTargets[]`
`EnvironmentVariables`; this preserves `__TESTROOT__`. Run
`BindingTests/SkeletonSnapshotRenderXCTest/testRenderCorpusToPNG`, alongside
`SkeletonRendererParityTests`, `SkeletonPresentationOverlayTests` and
`CellConfigurationVerifierXCTest/testNoLocalSurfaceHidesItsOwnWaysIn`.

Every capture reports visible-string expectations, style findings and failures.
Image cases additionally require known raster colors; the web harness checks
decode, natural dimensions and visible geometry. `img.complete` alone is not
proof: the original Image fixture had invalid CRC/zlib bytes and Chromium
tolerated it as a white pixel. Empty text expectations are marked raster-only,
not counted as meaningful content assertions. Spacer/Divider still require
layout/paint interpretation; ZStack's canonical labels intentionally overlap.

The comparison host is explicitly **light Porthole (`porthole-webo.css`)**.
Published fixture pages use conference CSS with different typography and colors.
Successful text/raster checks do not establish pixel identity, arbitrary CSS
parity, live remote action delivery, authentication, or general bridge readiness.
Keep the live bridge gate separate; HTTP fixture success must never make it green.

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
- `remote-http`
  - runs the staging-hosted HTTP fixture contract suite
  - skips only the live bridge command-response canary
- `remote-bridge`
  - runs the live staging bridge canary only
- `remote-contract`
  - runs the full staging-hosted contract suite, including the bridge canary
- `remote`
  - runs the full staging-hosted skeleton fixture contract suite
  - then runs the staging-backed conference smoke
- `all`
  - runs both

Remote fixture tests are opt-in for direct `xcodebuild` runs and are enabled in the script via `BINDING_ENABLE_REMOTE_PARITY=1`.
This is still phase 1, not the end state.

## 2026-04-22 status

The remote HTTP fixture contract is now broad enough to be useful as a real Binding gate:

- catalog
- text
- list
- grid
- form
- markdown
- relative-keypath
- nested-reference
- remote-bridge metadata
- unavailable
- invalid fixture diagnostics

Last observed `remote-http` result:

- 11 of 11 staging HTTP contract tests passed
- the catalog advertised all expected fixture routes
- public skeleton parity fixtures are now treated as open contracts in Binding, so Binding does not try scaffold admission before reading them

The remaining red check is intentionally isolated:

- `remote-bridge`
  - `testBridgeBackedFixtureResolvesThroughBindingAndExecutesAction`
  - direct bridge `get(state)` to `cell://staging.haven.digipomps.org/SkeletonParityTextFixture` times out

That means the remaining failure is earlier than skeleton rendering. Binding can reach the staging bridge route far enough to issue the command, but the fixture does not return the bridge `get` response. Until CellScaffold/staging exposes that command-response path reliably, the bridge canary must stay red and cannot be counted as an App Store release gate for "renders all supported skeletons".

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
- the native smoke evidence is now more trustworthy because the run completes even if `screencapture -l` temporarily fails on one step

## Phase 2

The next required implementation step across Binding and CellScaffold is broader coverage:

- expand Binding from the first fixture slice to the full suite (`markdown`, `relative-keypath`, `nested-reference`, `remote-bridge`, `unavailable`)
- keep the Personal Co-Pilot style-role allowlist small and verify curated local surfaces stay inside it
- add cross-host screenshot evidence for the same fixture set
- fail CI when local and remote parity diverge

Only when that exists can we honestly say skeleton rendering is verified independently of where cells run.
