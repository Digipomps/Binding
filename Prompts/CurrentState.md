# Current State (Living)

This file captures current implementation status, active decisions, and near-term priorities.

## Update Protocol
- Update this file at the end of meaningful architectural or behavior changes.
- Keep entries short, factual, and dated.
- Prefer links to code paths over long narrative.

## Active Repositories
- Binding app: `/Users/kjetil/Build/Digipomps/HAVEN/Binding`
- CellProtocol framework: `/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol`

## Snapshot
- Date: 2026-02-13
- AppleIntelligence demo configuration exists in CellProtocol porthole suggestion view model.
- Binding now has initial `view/edit` mode scaffolding for skeleton editing.
- Editor foundation currently includes:
  - mode switching (`View`/`Edit`)
  - editor state (`workingCopy`, selection, undo/redo)
  - tree mutations (`updateModifier`, `delete`, `insert`)

## Known Build Notes
- Some builds may fail due to unrelated local changes (for example actor isolation issues in non-editor files).
- Treat unrelated compile failures separately from editor feature work.

## Near-Term Priorities
- Connect GUI inspector controls to `updateModifier`.
- Add node selection overlay in edit mode.
- Add add/delete actions in GUI.
- Add drag-and-drop palette insertion.

## Open Decisions
- Exact UX for edit mode toolbar placement on small screens.
- Whether to persist edits immediately or stage them until explicit save.

