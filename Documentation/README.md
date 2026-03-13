# Binding + CellProtocol

This repository hosts the Binding app and integrates the CellProtocol ecosystem.

## Overview
- Binding (app): Hosts a porthole canvas and edge menus to quickly load `CellConfiguration`s.
- CellProtocol: A modular ecosystem comprising:
  - CellBase: platform-agnostic core (protocols, ValueType, CellConfiguration, Perspective, etc.).
  - CellApple: platform-specific integrations and views (SwiftUI, SkeletonView, EdgeMenus, Apple Intelligence under `CellApple/Intelligence`).
  - CellVapor: server-side (Vapor) integrations.

## Latest successful changes (February 16, 2026)
- Added a local `ConfigurationCatalogCell` in Binding at `Cells/ConfigurationCatalogCell.swift`, modeled after the scaffold catalog contract (`upperLeftMenu`, `upperMidMenu`, `upperRightMenu`, `lowerLeftMenu`, `lowerMidMenu`, `lowerRightMenu`, `syncScaffoldPurposeGoals`).
- Registered `ConfigurationCatalog` resolve in `Binding/BootstrapView.swift` so Binding can instantiate and serve catalog data locally.
- Updated `Binding/ContentView.swift` to fetch menu configurations directly from `cell:///ConfigurationCatalog` after `connectIfNeeded()`, and to trigger `syncScaffoldPurposeGoals` before reading menus.
- Enhanced menu examples/configurations to more polished card-style skeletons (title, subtitle, chip/badge, border/shadow styling), while still supporting imports from scaffold cells when available.
- Added interactive Skeleton editing:
  - Select elements from canvas/tree.
  - Add/delete elements.
  - Add/edit/delete modifiers.
  - Add/edit/delete element parameters (for example `endpoint`, `name`, `text`, `keypath`, `topic`, `label`).
- Added macOS floating editor tool windows (`NSPanel`) for `Elements` and `Inspector`, while keeping mode switching (`view`/`edit`) in the main window.
- Validation status: `xcodebuild` succeeded for Binding after these editor changes.

## Latest successful changes (February 23, 2026)
- `ConfigurationCatalogCell` now exposes purpose-aware library query endpoints:
  - `query` (ranked retrieval with deterministic score breakdown and explainability)
  - `facetCounts` (facet aggregation for Full Library filters)
  - `query.state` (latest query snapshot for UI status/debug)
- Catalog entries now carry richer metadata for large-scale discovery:
  - display metadata (`displayName`, `summary`, `categoryPath`, `tags`)
  - purpose/interest refs (`portableRefs-v1`)
  - compatibility hints (`supportedInsertionModes`, `supportedTargetKinds`)
  - IO/auth hints (`ioSignature`, `authRequired`, `policyHints`, `flowDriven`, `editable`)
- Existing persisted catalog entries are migrated on load through metadata enrichment defaults.
- Added Binding tests for:
  - ranked query response contract
  - facet bucket contract for `supportedInsertionModes`.
- Added Full Library UI in Binding:
  - New `FullLibraryView` sheet with tabs (`All configs`, `For my purposes`, `Sources`, `Templates`)
  - Search-as-you-type + token input (`purpose:`, `interest:`, `category:`, `source:`, `compatibility:`)
  - Facet panel backed by `facetCounts` and result list backed by `query`
  - Preview pane with score breakdown, badges and skeleton preview
  - Offline fallback surface for cached favorites/templates when catalog is unavailable
- Edge menu behavior update:
  - `upperMid` main action now opens Full Library directly (search-first role)
  - Added a `Library` button in mode panel for explicit access
- Build verification:
  - `xcodebuild ... build` succeeded for Binding.
  - `xcodebuild ... build-for-testing` succeeded for Binding + BindingTests.

## Apple Intelligence (high level)
- Implemented under `CellApple/Intelligence`.
- State is accessed exclusively via `Meddle.get/set(keypath:value:requester:)`.
- Updates and intents are emitted as `FlowElement` with `.object` payloads (via Emit/flow).
- Porthole (and other consumers) read state on demand and react to Flow updates.
- Explore interface standardizes request/response keys for discovering configurations.

## Documentation structure
Projects importing CellProtocol must include:
- `Documentation/`: Architecture and developer docs.
- `Prompts/`: Operational docs, system prompts, and component guides.

## Canonical doc placement
- Core protocol/runtime documentation needed for CellProtocol/HAVEN interoperability belongs in:
  - `CellProtocolDocuments` (submodule), for example:
    - `CellProtocolDocuments/Book/13_Agent_Instructions.md`
    - `CellProtocolDocuments/Book/14_Perspective_Runtime_Matching.md`
- Binding `Documentation/` should primarily contain Binding-specific integration notes.
- Product/commercial behavior built on top of CellProtocol/HAVEN should stay in product repositories (for example DiMy repos), including their product docs.

### Quick links
- Architecture overview: [Prompts/Architecture.md](../Prompts/Architecture.md)
- Contributing guidelines: [Prompts/CONTRIBUTING.md](../Prompts/CONTRIBUTING.md)
- Edge menus overlay: [Prompts/EdgeMenusOverlay.md](../Prompts/EdgeMenusOverlay.md)
- Apple Intelligence cell: [Prompts/AppleIntelligenceCell.md](../Prompts/AppleIntelligenceCell.md)
- Explainer for LLMs: [Prompts/ExplainToAnotherLLM.md](../Prompts/ExplainToAnotherLLM.md)
- Documentation index (folder): [Documentation/](./)
- Prompts index (folder): [Prompts/](../Prompts/)
- Skeleton editor: [Documentation/SkeletonEditor.md](Documentation/SkeletonEditor.md)
- Skeleton modifiers and new elements: [Documentation/SkeletonModifiers.md](Documentation/SkeletonModifiers.md)
- Skeleton elements reference: [Documentation/SkeletonElements_Detailed.md](Documentation/SkeletonElements_Detailed.md)
- Full Library UX/UI: [Documentation/FullLibraryView.md](Documentation/FullLibraryView.md)
- Component drag/drop plan: [Documentation/ComponentDragDropPlan.md](Documentation/ComponentDragDropPlan.md)
- How to create a Cell: [Documentation/HowTo_CreateCell.md](Documentation/HowTo_CreateCell.md)
- Perspective runtime matching (canonical): [CellProtocolDocuments/Book/14_Perspective_Runtime_Matching.md](../CellProtocolDocuments/Book/14_Perspective_Runtime_Matching.md)
- Perspective local stubs: [Documentation/PerspectiveCell_WeightedMatching_Proposal.md](Documentation/PerspectiveCell_WeightedMatching_Proposal.md), [Documentation/Perspective_Signal_Network_Implementation.md](Documentation/Perspective_Signal_Network_Implementation.md)

See also:
- `Prompts/EdgeMenusOverlay.md`
- `Prompts/AppleIntelligenceCell.md`
- `Prompts/ExplainToAnotherLLM.md`
- `Prompts/Architecture.md`
