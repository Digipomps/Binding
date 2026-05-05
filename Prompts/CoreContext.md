# Core Context (Binding Overlay)

Shared canonical context now lives in:
- `../CellProtocolDocuments/Prompts/CoreContext.md`

This file is Binding-specific overlay context only.

## Binding-Specific Context
- Binding is the integration app for porthole rendering and runtime demo flows.
- `Prompts/AppleIntelligenceCell.md` documents the local Apple Intelligence flow wiring.
- `Prompts/Architecture.md` and `Prompts/CONTRIBUTING.md` are authoritative for Binding-local implementation conventions.
- Agreement-template work must follow capability-based authorization (per-Identity grants, no role labels), support explicit rollout/re-evaluation behavior, and be checked against documented CellProtocol concepts before implementation.

## Reminder
- Keep shared concepts in `CellProtocolDocuments/Prompts/CoreContext.md`.
- Keep tactical state in `Prompts/CurrentState.md`.
