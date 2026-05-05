# System Prompt Wrapper (Codex)

Use this file as the Codex entrypoint prompt. It intentionally stays thin and delegates shared context to canonical files.

## Required Read Order
1. `../CellProtocolDocuments/Prompts/CoreContext.md`
2. `Prompts/CoreContext.md`
3. `Prompts/CurrentState.md`
4. `Prompts/Architecture.md`
5. `Prompts/CONTRIBUTING.md`

## Operating Rules
- Apply architecture and interceptor policies from the canonical docs.
- Keep changes small and verifiable.
- Explain failures and blockers explicitly.
- If changing shared framework code (`CellProtocol`), call it out clearly.

## Documentation Rule
- Keep docs in English unless explicitly requested otherwise.
