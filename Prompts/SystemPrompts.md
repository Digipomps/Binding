# System Prompts Index

This file is now an index to avoid prompt drift across assistants.

## Canonical Sources
- `../CellProtocolDocuments/Prompts/CoreContext.md` (shared concepts and non-negotiable rules)
- `Prompts/CoreContext.md` (Binding-specific overlay)
- `Prompts/CurrentState.md` (living implementation status)
- `Prompts/Architecture.md` (authoritative architecture policy)
- `Prompts/CONTRIBUTING.md` (contribution conventions)

## Assistant Wrappers
- `Prompts/SystemPrompt-Codex.md`
- `Prompts/SystemPrompt-Xcode53.md`

## Legacy Rules (still valid)
- Process work in small, verifiable steps.
- If work fails, always explain why.
- If editing CellProtocol is the right place for a change, call it out explicitly.
- Keep documentation in English unless explicitly requested otherwise.
