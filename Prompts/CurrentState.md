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
- Agreement-template policy clarified:
  - authorization is capability/grant-based per `Identity` (not role labels),
  - template updates may target only new connections or also re-evaluate existing identities,
  - revocation can force renewed `signContract` when allowed by active contract terms,
  - `agreementTemplate.access.manage` can be delegated explicitly,
  - agreements should support signatures from all parties and retrieval for storage in each party-controlled entity context,
  - `Entity` is digital presence/resources/functionality controlled by a person (not the person itself),
  - non-compliance should be surfaced explicitly and handled by selected policy,
  - changes that may break CellProtocol concepts must be discussed with the user before implementation.

## Known Build Notes
- Some builds may fail due to unrelated local changes (for example actor isolation issues in non-editor files).
- Treat unrelated compile failures separately from editor feature work.

## Near-Term Priorities
- Connect GUI inspector controls to `updateModifier`.
- Add node selection overlay in edit mode.
- Add add/delete actions in GUI.
- Add drag-and-drop palette insertion.
- Define and review agreement-template editor implementation plan before code changes.

## Open Decisions
- Exact UX for edit mode toolbar placement on small screens.
- Whether to persist edits immediately or stage them until explicit save.
