# Contributing Guidelines

This document provides conventions for contributing to the Binding app and the broader CellProtocol ecosystem.

## Scope and repos
- Binding: focus app in this repository.
- CellProtocol: shared framework used across projects (e.g., CellScaffold, CellUtility, HAVEN_MVP). Only one project in a workspace should have write access to shared framework sources at a time.

## Architecture and documentation
- Follow the rules in `Prompts/Architecture.md`. That document is authoritative.
- Keep documentation in English unless explicitly requested otherwise.
- Add or update component guides under `Prompts/` (e.g., `EdgeMenusOverlay.md`, `AppleIntelligenceCell.md`).

## Interface policy (Cells)
- Expose behavior/state only through interceptors:
  - `addInterceptForGet(key:getValueIntercept:)`
  - `addInterceptForSet(key:setValueIntercept:)`
- Do not use ad-hoc side channels or `registerAction` / `registerSetter`.
- Publish events/intents via `Emit.flow` using `FlowElement` with `.object` payloads.
- Enforce access control inside the cell (per-keypath authorization via the agreement/contract model).

## Code style and Swift conventions
- Prefer Swift Concurrency (`async/await`).
- Keep UI logic declarative; avoid side effects in SwiftUI bodies.
- Minimize coupling to third-party packages; wrap in adapters if needed.

## Testing and verification
- Prefer the Swift Testing framework for new tests when XCTest isn’t already in use.
- Validate that skeletons render on iPhone and iPad and that edge menu items remain within visible bounds.

## Pull requests
- Keep changes minimal and focused.
- Include a short rationale and a reference to related docs or prompts.
- Update relevant `.md` files when behavior or conventions change.
