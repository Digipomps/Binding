# System Prompt Wrapper (Codex)

Use this file as the Codex entrypoint prompt. It intentionally stays thin and delegates shared context to canonical files.

## Required Read Order
1. `../../CellProtocolDocuments/Prompts/CoreContext.md`
2. `Prompts/CoreContext.md`
3. `Prompts/CurrentState.md`
4. `Prompts/Architecture.md`
5. `Prompts/CONTRIBUTING.md`

If the sibling checkout in step 1 is missing, stop and report the missing
`HAVEN/CellProtocolDocuments` dependency. Do not fall back to a copied or stale
document inside Binding.

## Operating Rules
- Apply architecture and interceptor policies from the canonical docs.
- Keep changes small and verifiable.
- Explain failures and blockers explicitly.
- If changing shared framework code (`CellProtocol`), call it out clearly.

## Documentation Rule
- Keep docs in English unless explicitly requested otherwise.
