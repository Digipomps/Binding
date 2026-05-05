# EntityScanner Judged Proximity UX

This note captures the scanner UX direction from the April 26 design sketches and maps it to the current Binding / CellProtocol implementation.

## Direction

The scanner should feel like judged proximity, not radar hunting. It is calm by default, starts only after an explicit user action, and promotes nearby entities only when the local adapter has enough relevance or relationship state to justify attention.

The main flow is:

1. Idle: visible scanner status and a Start scanning action. No ambient urgency.
2. Scanning: capability/status chips show UWB versus BT/MPC-only behavior.
3. Relevant results: primary list shows only results above threshold or entities with pending/saved relation state.
4. Selection: detail separates local proximity/relevance from `OPENLY PUBLISHED` profile data.
5. Contact: `Send invite`, `Request contact`, and `Accept + exchange` remain distinct actions.
6. Established relation: UI says `Identity saved`; this means signed identity exchange completed, relation persisted, and encounter proof saved.
7. Chat: chat becomes actionable only after identity exchange and relation persistence. Scanner owns no chat state.

## Implemented now

- `ConferenceNearbyRadarLocalCell` now exposes filtered primary results via `nearbyRadar.state.nearby`.
- Lower or nearby-only results are hidden by default and surfaced through:
  - `nearbyRadar.state.hiddenEntityCount`
  - `nearbyRadar.state.hiddenNearby`
  - `nearbyRadar.state.allNearby`
  - `nearbyRadar.state.showingLowerMatches`
  - `nearbyRadar.state.lowerMatchesSummary`
  - `nearbyRadar.toggleLowerMatches`
- Relevance tiers follow the current design thresholds:
  - verified `>= 0.80`: strong
  - verified `>= 0.55`: good
  - unverified `>= 0.65`: promising
  - unverified `>= 0.35`: moderate
  - no score: nearby only
  - below threshold: low
- Saved, pending, incoming, selected, marked, or chat-ready entities remain visible even if their score is low. This prevents relationship-state dead ends.
- Incoming contact now surfaces as `Accept + exchange`.
- Established contact now surfaces as `Identity saved` with relation/proof wording.
- Entity cards now expose distance, direction confidence, relevance tier, relation badge, and public-preview summary fields.
- Selected entity state now separates:
  - local proximity/relevance fields
  - `OPENLY PUBLISHED` preview fields
  - relation persistence summary
  - chat availability summary
- The Entity Scanner workbench absorbs references for public profiles, chat hub, Vault, EntityAnchor, Perspective, EntityScanner, and the local radar adapter.

## Current skeleton limits

- Skeleton buttons do not currently support a true disabled state. The locked chat affordance is therefore represented as an explanatory action card, not as a semantically disabled button.
- The visual direction ring from the sketches is not a native skeleton element. Current skeletons expose direction-confidence text and state; native SwiftUI components can render the precise/dashed ring.
- A dedicated `PublicProfileCell` lookup is not implemented as a separate contract here. The workbench references the existing public profile directory surface and keeps profile data out of EntityScanner.
- The scanner workbench is still backed by the existing local radar adapter class name. The UX/data contract is now more personal-copilot oriented, but the class itself remains local Binding runtime code.

## Ownership discipline

- Stays local to Binding / CellApple: scanner lifecycle, proximity, direction certainty, contact exchange, relation/proof persistence, relevance filtering, lower-match toggle, and chat handoff trigger.
- Absorbed via references: public profile directory, chat hub, Vault export target, Perspective, EntityAnchor.
- Portable in `CellConfiguration`: hero/status composition, filtered entity list, selected detail, public/persistence sections, and action cards.
- Must not move into EntityScanner: public profile storage, chat state, remote mini-app logic, and private profile inference from proximity.

## Next implementation steps

1. Add native SwiftUI ring rendering for precise, uncertain, and unknown direction states.
2. Add renderer support for disabled skeleton buttons if the app should express locked chat as a real disabled control.
3. Add a selected-entity public-profile lookup adapter once the public profile contract has a stable lookup key from nearby entity identity.
4. Add iPad and desktop layouts as native surfaces if the generic skeleton layout is not expressive enough for multi-pane behavior.

## Handoff context for next agent

Last updated: 2026-04-28.

Treat this document and files on disk as ground truth. Do not re-import the earlier design sketches as a broader redesign brief unless the user explicitly asks for a new direction. The intended scanner direction is already chosen: calm judged proximity, not a radar/game metaphor.

Important code anchors:

- `Binding/BootstrapView.swift`: `ConferenceNearbyRadarLocalCell` is the local adapter that normalizes `EntityScanner` flow/state into the scanner UX contract. Despite the class name, this is currently the practical Binding-local scanner adapter for judged proximity.
- `Binding/Cells/ConfigurationCatalogCell.swift`: `entityScannerWorkbenchConfiguration()` and `entityScannerToolConfiguration(...)` compose the workbench skeleton, references, selected-entity detail, filtered list, and action-card surface.
- `Binding/BindingTests/BindingTests.swift`: scanner/radar behavior is covered by focused tests for filtering, hidden lower matches, selected entity state, and Personal Co-Pilot catalog scope.
- `Binding/Documentation/EntityScanner_JudgedProximityUX.md`: this handoff and UX discipline note.

Known verified checks from the implementation round:

- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/BindingTests/conferenceNearbyRadarSeparatesApproximateSignalsFromFocusedParticipantActions -only-testing:BindingTests/BindingTests/conferenceNearbyRadarSupportsVariableEntityCountsWithDistanceDirectionAndRelevance`
- `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/BindingTests/personalCopilotV1MenuConfigurationsAreScopedAndConferenceFree -only-testing:BindingTests/BindingTests/entityScannerWorkbenchConfigurationsStayLocalToBinding`
- `git diff --check -- Binding/BootstrapView.swift Cells/ConfigurationCatalogCell.swift BindingTests/BindingTests.swift Documentation/README.md`

Do not blur these layers:

- `EntityScanner` owns discovery, proximity, contact exchange, encounter proofs, and exported encounter data.
- Binding's local adapter owns relevance filtering, selected entity presentation, lower-match visibility, and scanner UX state.
- Public profile data must come from a public profile/directory reference.
- Chat must come from a chat hub/reference after signed identity exchange; scanner must not store chat state.
- Vault export is a handoff/reference, not scanner-owned durable content storage.

Current behavior to preserve:

- `nearbyRadar.state.nearby` is the primary visible list, not the raw feed.
- `nearbyRadar.state.hiddenNearby` and `nearbyRadar.state.allNearby` exist for audit/debug and lower-match reveal.
- Low or nearby-only entities are hidden by default, but relationship-state entities remain visible to avoid dead ends.
- Direction must not be faked. If direction is absent or only BT/MPC precision is available, UI must show uncertain/unknown direction rather than a fabricated bearing.
- `Accept + exchange` means signed identity exchange. `Identity saved` means relation persistence and encounter proof storage have completed locally.

Smallest sensible next step:

Add native SwiftUI rendering for the direction/distance indicator before broadening the scanner architecture. The data contract already exposes enough state for this: distance, direction confidence, precision/capability mode, and relation/relevance fields. Avoid a new `PublicProfileCell` contract or iPad/desktop-specific native layout until the ring/indicator communicates precision honestly.
