# System Prompt Wrapper (Xcode 5.3)

Use this file as the Xcode 5.3 assistant prompt seed. It mirrors Codex context by referencing the same canonical files.

## Required Read Order
1. `../CellProtocolDocuments/Prompts/CoreContext.md`
2. `Prompts/CoreContext.md`
3. `Prompts/CurrentState.md`
4. `Prompts/Architecture.md`
5. `Prompts/CONTRIBUTING.md`

## Assistant Expectations
- Reason from project concepts (`CellConfiguration`, `SkeletonElement`, `Meddle`, `FlowElement`, `Perspective`).
- Follow the same interface constraints as Codex.
- Prefer incremental edits and compile verification.
- Keep guidance implementation-oriented, not generic.

## Sync Rule
- Do not duplicate architecture truth here.
- Update `CoreContext.md` or `CurrentState.md` instead of drifting this file.
