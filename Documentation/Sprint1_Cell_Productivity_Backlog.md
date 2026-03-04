# Sprint 1 Backlog - Binding (Desktop UX)

## Sprint Objective
Ship the first usable Obsidian-like UX layer on top of cells: vault browsing, drag-and-compose flows, and provider-aware AI controls.

## Issues

### BD-01 (P0, 3 days): Vault Workspace Shell
Goal:
- Add a dedicated vault workspace shell with notes list, note editor, and graph quick panel.

Implementation touchpoints:
- `Binding/ContentView.swift`
- `Binding/FullLibraryView.swift`

Acceptance criteria:
1. User can open a note, edit markdown, and save through runtime keypaths.
2. Workspace has a clear split view: note content + related links panel.
3. Failed save shows recoverable error surface without losing local draft.
4. Basic keyboard shortcuts are wired (`Cmd+N`, `Cmd+S`, `Cmd+P`).

### BD-02 (P0, 2 days): Drag-and-Compose Cell Drops for Chat and Utilities
Goal:
- Enable drag insertion of `ChatCell`, `MermaidRendererCell`, and utility cells into the current project workspace.

Implementation touchpoints:
- Porthole insertion flow and skeleton editor integration.

Acceptance criteria:
1. Drag from library inserts selected cell into active workspace at drop position.
2. Inserted cell instances preserve config identity and are editable.
3. Undo/redo works for insert and remove actions.
4. Insert flow works in both empty and populated workspaces.

### BD-03 (P0, 4 days): Mindmap Panel with Note/Task/Cell Nodes
Goal:
- Introduce an interactive mindmap panel bound to vault graph data.

Implementation touchpoints:
- New panel in Binding UI plus graph data adapters.

Acceptance criteria:
1. Nodes can represent note, task, and cell types.
2. Clicking a node opens the corresponding note or cell inspector.
3. Creating an edge in UI updates underlying link contract.
4. Graph refresh picks up external edits without full app restart.

### BD-04 (P1, 2 days): AI Access Settings (Subscription + BYOK)
Goal:
- Provide one place in UI for model access mode and key alias management.

Implementation touchpoints:
- Settings pane and keypath integration with orchestrator/provider listing.

Acceptance criteria:
1. User can switch between `subscription` and `byok` modes.
2. BYOK mode allows selecting stored key alias and validates availability.
3. Settings surface shows routing rationale from orchestrator plan response.
4. State persists across app relaunch.

### BD-05 (P1, 2 days): Sprint 1 UX Integration Tests
Goal:
- Add UI/integration tests for the primary user journey.

Test flow:
- Open workspace -> create note -> add chat cell -> request AI action -> inspect related items.

Acceptance criteria:
1. At least one automated test covers full primary flow.
2. Tests run in CI and fail on regressions.
3. Test output includes artifact screenshots on failure.

## Dependency Order
1. BD-01
2. BD-02
3. BD-03
4. BD-04 and BD-05 in parallel once BD-01 to BD-03 are stable

## Definition of Done
1. Primary flow works without manual JSON edits.
2. UI tests pass on clean environment.
3. Known UX gaps are logged as post-Sprint backlog items.
