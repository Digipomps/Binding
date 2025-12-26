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

See also:
- `Prompts/EdgeMenusOverlay.md`
- `Prompts/AppleIntelligenceCell.md`
- `Prompts/ExplainToAnotherLLM.md`
- `Architecture.md`
