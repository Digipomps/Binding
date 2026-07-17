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

## Implementation status - 2026-05-18

Implemented in Binding:

- `ConferenceNearbyRadarLocalCell.state.radarLayout.surface` now exposes an explicit native radar contract:
  - `preciseNodes` contain `xNormalized`, `yNormalized`, `azimuthRadians`, distance, freshness, selection, relation, and follow-up metadata.
  - `approximateNodes` keep distance/status metadata but leave `xNormalized` and `yNormalized` as `null` so MPC-only peers are not shown with invented direction.
  - the selected participant is represented as `selectedNode` and remains the functional focus for follow-up actions.
- `Binding/Binding/ConferenceNearbyRadarSurfaceView.swift` renders a Binding-local SwiftUI radar surface:
  - full mode for `Conference Nearby Radar · Full oversikt`
  - compact mode for `Conference Participant Portal Dashboard`
  - animated sweep and node movement are local SwiftUI work, not per-frame Skeleton or bridge updates.
  - node taps dispatch `selectEntity`; visible actions dispatch profile, contact, follow-up, and chat mutations through `nearbyRadar.dispatchAction`.
- `PortholeCanvas` injects the native surface above the existing Skeleton workbench only for the nearby radar and participant portal configurations. The surrounding Skeleton contract still owns summaries, cards, navigation, and portable layout.

Verified on 2026-05-18:

- `xcodebuild build -quiet -project Binding.xcodeproj -scheme HAVEN -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/BindingNearbyDerivedData CODE_SIGNING_ALLOWED=NO`
- `xcodebuild build-for-testing -quiet -project Binding.xcodeproj -scheme HAVEN -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/BindingNearbyDerivedData CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO`
- `xcodebuild test-without-building -quiet -project Binding.xcodeproj -scheme HAVEN -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/BindingNearbyDerivedData -parallel-testing-enabled NO -only-testing:BindingTests/BindingTests/conferenceNearbyRadarSeparatesApproximateSignalsFromFocusedParticipantActions -only-testing:BindingTests/BindingTests/conferenceNearbyRadarSupportsVariableEntityCountsWithDistanceDirectionAndRelevance`
- `xcodebuild test-without-building -quiet -project Binding.xcodeproj -scheme HAVEN -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/BindingNearbyDerivedData -parallel-testing-enabled NO -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyRadarContract`
- `xcodebuild test-without-building -quiet -project Binding.xcodeproj -scheme HAVEN -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/BindingNearbyDerivedData -parallel-testing-enabled NO -only-testing:BindingTests/CellConfigurationVerifierXCTest/testConferenceNearbyParticipantProfileContract`
- `swift test --filter EntityScannerCellContractTests` in `../CellProtocol`

Not verified in this environment:

- live two-device UWB acceptance. This still requires two physical UWB-capable iOS devices running the app build, with `NearbyInteraction` available, to confirm that rotating one device moves the node and changing distance changes the radius in real hardware conditions.

## Production readiness status - 2026-07-17

Goal for this pass:

- treat Nearby Scanner as a first-class HAVEN app surface, not only a conference-demo stretch
- keep the UI honest about precision, transport, and permission boundaries
- make the scanner directly reachable by users and GUI automation
- document the remaining hardware-only acceptance gap without overstating readiness

Now in place:

- Personal Co-Pilot metadata marks `Entity Scanner` as a primary `upperLeft` and secondary `lowerLeft` surface with `hardware-scanner` policy metadata.
- The non-conference app menu seeds include `Entity Scanner` in the first personal menu group so it is visible with Home, Co-Pilot, and Matches.
- Conference demo menus include `Conference Nearby Radar · Full oversikt` near the main launch path and keep the local Entity Scanner workbench/checklist for QA.
- macOS/debug automation now has direct hooks for `open-nearby-scanner` and `open-conference-nearby-radar`, so GUI tests can open the surfaces without click-hunting through menus.
- `Info.plist` declares the platform permission copy needed for Nearby Interaction, local network discovery, Bluetooth, and the `_haven-radar._tcp` Bonjour service.
- The launcher readiness copy no longer describes nearby radar as a stretch. It says what is local-first and explicitly keeps two-device UWB acceptance open.

Production-ready criteria:

- App entry: Nearby Scanner is reachable from the primary personal surface navigation and through direct automation/deep-link hooks.
- Platform readiness: privacy usage descriptions exist for Nearby Interaction, local network, Bluetooth, and the expected Bonjour service.
- Truthfulness: precise UWB peers carry direction/distance; MPC-only peers stay approximate and never get invented direction.
- Interaction: start/stop, candidate selection, request contact, verified contact, follow-up/chat handoff, and portal/radar navigation mutate visible state.
- Design: empty, scanning, approximate, precise, stale, selected, and action feedback states are legible without debug knowledge.
- Verification: deterministic macOS contract/renderer/action tests pass, and two physical UWB-capable devices pass the live acceptance checklist below.

Remaining before calling the hardware path production-verified:

- Run the live two-device UWB checklist on iOS hardware.
- Capture fresh screenshots/video for empty, MPC-only, UWB precise, selected participant, and follow-up-chat states.
- Confirm App Store/privacy review wording against the final sensor implementation if the underlying scanner transport changes.
- Decide whether multicast entitlement is needed. Current implementation declares Bonjour service discovery; do not add the entitlement unless the code path actually uses multicast/broadcast APIs that require it.

## Definition of done

The nearby radar is done for this phase when:

- full radar renders live device-relative direction and distance for UWB peers
- embedded radar works as a clear overview
- selected participant is visually and functionally central
- approximate peers are honest about uncertainty
- follow-up actions remain visible and stable
- deterministic tests and live two-device checks both pass
