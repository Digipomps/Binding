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
