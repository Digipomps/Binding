// Apple Intelligence — Interaction Workflow

/*
This guide explains how to interact with the AppleIntelligenceCell using CellProtocol primitives,
how to add and rank CellConfigurations, how to provide instructions (hints) to the assistant,
and how to use Purpose and Interests (Perspective) to influence behavior and recommendations.

Quick Reference:

- Status (AIStatus): `idle`, `discovering`, `ready`, `error`
- Keys (AIKeys)
  - `ai.status`
  - `ai.currentPurposeRef`
  - `ai.purposeClusterRefs`
  - `ai.candidates` (list of CellConfiguration)
  - `ai.outbox` (list of ValueType.object messages intended for Flow)
- Topics (AITopics)
  - `ai.assistant.state`
  - `ai.assistant.recommendations`
  - `ai.intent.requestConfigurations`
  - `ai.intent.response.configurations`
  - `explore.request` / `explore.response` / `explore.announce`

Endpoints (Interceptors):

All interaction goes through `Meddle.get/set(keypath:value:requester:)` on the cell. The AppleIntelligenceCell exposes these endpoints:

- GET
  - `ai.state` → returns a snapshot of `ai.*` (status, currentPurposeRef, purposeClusterRefs, candidates)

- SET (commands)
  - `ai.discover` → triggers discovery; enqueues requests and a state snapshot
  - `ai.rank` → ranks `ai.candidates` (simple heuristic based on Purpose-aware naming)
  - `ai.ensurePurpose` → ensures `ai.currentPurposeRef` is set based on Perspective
  - `ai.buildCluster` → builds `ai.purposeClusterRefs` using the current purpose
  - `ai.ingestConfigurations` → accepts configurations to add to `ai.candidates`
  - `ai.send` → publishes a FlowElement (you provide `topic`, `type`, `content`, `title?`)
  - `ai.sendPrompt` → accepts a prompt and optional `instructions`; publishes prompt + response (if available)

Authorization: Only the cell owner can perform SET commands.

Typical Workflow:

1) Bootstrap and initial state
- On init, the cell seeds:
  - `ai.status = idle`
  - `ai.candidates = []`
  - `ai.outbox = []`
- Consider calling:
  - `ai.ensurePurpose` → sets `ai.currentPurposeRef` from Perspective
  - `ai.buildCluster` → initializes `ai.purposeClusterRefs`

2) Ingest configurations (candidates)
- Provide configurations to `ai.ingestConfigurations` as either:
  - A list of `.cellConfiguration` values, or
  - An object: `{ "configurations": [CellConfiguration...] }`

Example (Swift):
```swift
let configs: [CellConfiguration] = [/* ... */]
let vtList = ValueTypeList(configs.map { .cellConfiguration($0) })
_ = try await meddle.set(keypath: "ai.ingestConfigurations", value: .list(vtList), requester: identity)

