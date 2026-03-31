# Conference Nearby Radar Implementation Plan

## Goal

Deliver a conference nearby radar that:

- shows truthful direction and distance when UWB / Nearby Interaction is available
- updates correctly when the device is rotated or moved
- stays honest when only MPC-based proximity is available
- preserves the current conference participant flow instead of replacing it

## Core decision

Do not introduce a general `SpatialCanvas` Skeleton primitive first.

Build the moving radar as a Binding-local native SwiftUI surface, while keeping Skeleton responsible for:

- surrounding structure
- summaries
- selected-participant details
- action cards
- workbench navigation

This keeps the high-frequency spatial rendering local and avoids pushing per-frame layout concerns into Skeleton or bridge resolution.

## Truth model

The radar should be treated as device-relative, not room-fixed.

That means:

- UWB direction from `NearbyInteraction` should drive node placement directly
- rotating the device should rotate the radar picture because the measured direction changes
- moving the device should update node radius because distance changes
- MPC-only peers must never be rendered as if they have precise direction

We support three precision modes:

1. `precise`
   Nearby Interaction provides live direction and distance.
2. `approximate`
   MPC gives proximity or contact-state hints, but not trustworthy direction.
3. `unknown`
   No current spatial signal is trustworthy enough to place.

## Non-goals for the first implementation

- no AR overlay
- no room-fixed map
- no compass-heading world lock
- no general-purpose Skeleton absolute-positioning primitive
- no 60 fps bridge-driven feed

## Commit plan

### Commit 1: Honest spatial contract

Scope:

- make the nearby state explicit about precision and freshness
- remove any visually precise fallback that could mislead users

Files:

- `CellProtocol/Sources/CellApple/EntityRadar/RadarModels.swift`
- `Binding/Binding/BootstrapView.swift`
- `Binding/BindingTests/BindingTests.swift`
- `Binding/BindingTests/CellConfigurationVerifierXCTest.swift`

Changes:

- add explicit position precision metadata per entity
- expose `azimuthRadians`, `distanceMeters`, `xNormalized`, `yNormalized`, and freshness
- keep MPC-only peers in an approximate or uncertain bucket
- ensure selected-entity summaries distinguish between precise and approximate signals

Acceptance:

- no peer with `direction == nil` is rendered as if it has a precise angle
- focused participant copy distinguishes precise vs approximate
- deterministic tests cover mapping and truth handling

Rollback boundary:

- if anything feels ambiguous, stop here and keep the old UI until the contract reads clearly

### Commit 2: Native full radar surface

Scope:

- add the first real moving radar for the dedicated nearby workbench

Files:

- new file `Binding/Binding/ConferenceNearbyRadarSurfaceView.swift`
- `Binding/Binding/BootstrapView.swift`
- `Binding/Cells/ConfigurationCatalogCell.swift`
- `Binding/BindingTests/BindingTests.swift`
- `Binding/BindingTests/CellConfigurationVerifierXCTest.swift`

Changes:

- create a native SwiftUI radar surface for conference nearby use
- render nodes with true XY placement from normalized position
- tap on a node focuses that participant
- keep distance rings and clear center marker
- show stale or approximate peers differently from precise peers

Acceptance:

- full nearby radar workbench shows moving nodes when state changes
- tapping a node updates selected participant state and actions
- no bridge roundtrip is needed per frame

Performance target:

- snapshot/state updates can remain moderate frequency, for example 5-10 Hz
- animation and interpolation stay local in SwiftUI
- no repeated `get` calls for every visual frame

Rollback boundary:

- if the surface is visually good but selection is unstable, keep the surface behind the full workbench only

### Commit 3: Embedded compact radar

Scope:

- turn the participant-page radar into a true compact overview that points into the full radar

Files:

- `Binding/Cells/ConfigurationCatalogCell.swift`
- `Binding/Binding/BootstrapView.swift`
- `Binding/BindingTests/BindingTests.swift`
- `Binding/BindingTests/CellConfigurationVerifierXCTest.swift`

Changes:

- keep the embedded view smaller and simpler than the full radar
- let it show a compact live picture plus the currently selected participant
- make `Åpne full radar` the clear transition into the deeper experience
- visually de-emphasize recommendation cards relative to the selected nearby participant

Acceptance:

- the selected participant is more prominent than surrounding recommendation cards
- the embedded radar feels like an overview, not a cramped duplicate of full radar
- nearby selection can still be done inline

Rollback boundary:

- if embedding adds instability, keep the compact nearby surface read-only and route action work to the full radar

### Commit 4: Inspect card and actions

Scope:

- make the radar useful for real conference actions, not just spatial awareness

Files:

- `Binding/Binding/BootstrapView.swift`
- `Binding/Cells/ConfigurationCatalogCell.swift`
- `Binding/BindingTests/BindingTests.swift`
- `Binding/BindingTests/CellConfigurationVerifierXCTest.swift`

Changes:

- strengthen the selected participant card with richer profile content
- keep `Be om kontakt`, `Start chat`, and `Marker for oppfølging` visible and explicit
- show status feedback after actions so the UI does not feel inert
- ensure chat handoff still uses the existing conference chat flow

Acceptance:

- selecting a node makes the next step obvious
- actions change visible state in the GUI
- selected participant remains the focal point after an action

Rollback boundary:

- if chat handoff becomes noisy, keep inspect-card actions but defer direct chat launch until the next pass

### Commit 5: Motion and quality pass

Scope:

- smooth movement and add regression coverage only after the interaction model is sound

Files:

- `Binding/Binding/ConferenceNearbyRadarSurfaceView.swift`
- `Binding/BindingTests/BindingTests.swift`
- `Binding/Documentation/ConferenceConfigurationVerifier.md`

Changes:

- add local interpolation or spring smoothing if needed
- add targeted timing checks
- document the live acceptance path for two-device UWB testing

Acceptance:

- movement feels stable rather than jittery
- stale data is visibly stale
- tests cover truth contract, renderer presence, and action handoff

Rollback boundary:

- if smoothing hides truth or adds lag, remove it and prefer raw but honest motion

## Test strategy

### Deterministic tests

- mapping from direction vector to azimuth and XY
- approximate peers never rendered as precise directional nodes
- selected participant state updates from node tap
- participant portal can still open full radar
- chat and follow-up actions still route through the existing conference flow

### Live acceptance

Use two UWB-capable devices when available.

Checklist:

1. Start scanner on both devices.
2. Verify a peer appears in the full radar.
3. Rotate one device and confirm the node moves accordingly.
4. Move closer and farther away and confirm radius changes.
5. Tap the node and confirm the inspect card updates.
6. Start chat or request contact and confirm visible state feedback.

Fallback acceptance:

- on MPC-only devices, the peer should still appear as nearby
- it should not be shown with precise direction

## Risk controls

- keep high-frequency radar rendering local, not bridge-driven
- keep the current skeleton workbench contract intact around the radar
- do not introduce room-fixed positioning until device-relative radar is solid
- preserve existing participant portal, chat, and verifier paths while adding the native radar incrementally

## Definition of done

The nearby radar is done for this phase when:

- full radar renders live device-relative direction and distance for UWB peers
- embedded radar works as a clear overview
- selected participant is visually and functionally central
- approximate peers are honest about uncertainty
- follow-up actions remain visible and stable
- deterministic tests and live two-device checks both pass
