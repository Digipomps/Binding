# Binding + CellProtocol

This repository hosts the Binding app and integrates the CellProtocol ecosystem.

## Overview
- Binding (app): Hosts a porthole canvas and edge menus to quickly load `CellConfiguration`s.
- CellProtocol: A modular ecosystem comprising:
  - CellBase: platform-agnostic core (protocols, ValueType, CellConfiguration, Perspective, etc.).
  - CellApple: platform-specific integrations and views (SwiftUI, SkeletonView, EdgeMenus, Apple Intelligence under `CellApple/Intelligence`).
  - CellVapor: server-side (Vapor) integrations.

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

### Quick links
- Architecture overview: [Prompts/Architecture.md](Prompts/Architecture.md)
- Contributing guidelines: [Prompts/CONTRIBUTING.md](Prompts/CONTRIBUTING.md)
- Edge menus overlay: [Prompts/EdgeMenusOverlay.md](Prompts/EdgeMenusOverlay.md)
- Apple Intelligence cell: [Prompts/AppleIntelligenceCell.md](Prompts/AppleIntelligenceCell.md)
- Explainer for LLMs: [Prompts/ExplainToAnotherLLM.md](Prompts/ExplainToAnotherLLM.md)
- Documentation index (folder): [Documentation/](Documentation/)
- Prompts index (folder): [Prompts/](Prompts/)
- Skeleton modifiers and new elements: [Documentation/SkeletonModifiers.md](Documentation/SkeletonModifiers.md)
- Skeleton elements reference: [Documentation/SkeletonElements.md](Documentation/SkeletonElements.md)
- How to create a Cell: [Documentation/HowTo_CreateCell.md](Documentation/HowTo_CreateCell.md)

See also:
- `Prompts/EdgeMenusOverlay.md`
- `Prompts/AppleIntelligenceCell.md`
- `Prompts/ExplainToAnotherLLM.md`
- `Prompts/Architecture.md`

