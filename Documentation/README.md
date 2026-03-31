# Binding + CellProtocol

This repository hosts the Binding app and integrates the CellProtocol ecosystem.

## Overview
- Binding (app): Hosts a porthole canvas and edge menus to quickly load `CellConfiguration`s.
- CellProtocol: A modular ecosystem comprising:
  - CellBase: platform-agnostic core (protocols, ValueType, CellConfiguration, Perspective, etc.).
  - CellApple: platform-specific integrations and views (SwiftUI, SkeletonView, EdgeMenus, Apple Intelligence under `CellApple/Intelligence`).
  - CellVapor: server-side (Vapor) integrations.

## Latest successful changes (February 16, 2026)
- Added a local `ConfigurationCatalogCell` in Binding at `Cells/ConfigurationCatalogCell.swift`, modeled after the scaffold catalog contract (`upperLeftMenu`, `upperMidMenu`, `upperRightMenu`, `lowerLeftMenu`, `lowerMidMenu`, `lowerRightMenu`, `syncScaffoldPurposeGoals`).
- Registered `ConfigurationCatalog` resolve in `Binding/BootstrapView.swift` so Binding can instantiate and serve catalog data locally.
- Updated `Binding/ContentView.swift` to fetch menu configurations directly from `cell:///ConfigurationCatalog` after `connectIfNeeded()`, and to trigger `syncScaffoldPurposeGoals` before reading menus.
- Enhanced menu examples/configurations to more polished card-style skeletons (title, subtitle, chip/badge, border/shadow styling), while still supporting imports from scaffold cells when available.
- Added interactive Skeleton editing:
  - Select elements from canvas/tree.
  - Add/delete elements.
  - Add/edit/delete modifiers.
  - Add/edit/delete element parameters (for example `endpoint`, `name`, `text`, `keypath`, `topic`, `label`).
- Added macOS floating editor tool windows (`NSPanel`) for `Elements` and `Inspector`, while keeping mode switching (`view`/`edit`) in the main window.
- Validation status: `xcodebuild` succeeded for Binding after these editor changes.

## Latest successful changes (February 23, 2026)
- `ConfigurationCatalogCell` now exposes purpose-aware library query endpoints:
  - `query` (ranked retrieval with deterministic score breakdown and explainability)
  - `facetCounts` (facet aggregation for Full Library filters)
  - `query.state` (latest query snapshot for UI status/debug)
- Catalog entries now carry richer metadata for large-scale discovery:
  - display metadata (`displayName`, `summary`, `categoryPath`, `tags`)
  - purpose/interest refs (`portableRefs-v1`)
  - compatibility hints (`supportedInsertionModes`, `supportedTargetKinds`)
  - IO/auth hints (`ioSignature`, `authRequired`, `policyHints`, `flowDriven`, `editable`)
- Existing persisted catalog entries are migrated on load through metadata enrichment defaults.
- Added Binding tests for:
  - ranked query response contract
  - facet bucket contract for `supportedInsertionModes`.
- Added Full Library UI in Binding:
  - New `FullLibraryView` sheet with tabs (`All configs`, `For my purposes`, `Sources`, `Templates`)
  - Search-as-you-type + token input (`purpose:`, `interest:`, `category:`, `source:`, `compatibility:`)
  - Facet panel backed by `facetCounts` and result list backed by `query`
  - Preview pane with score breakdown, badges and skeleton preview
  - Offline fallback surface for cached favorites/templates when catalog is unavailable
- Edge menu behavior update:
  - `upperMid` main action now opens Full Library directly (search-first role)
  - Added a `Library` button in mode panel for explicit access
- Build verification:
  - `xcodebuild ... build` succeeded for Binding.
  - `xcodebuild ... build-for-testing` succeeded for Binding + BindingTests.

## Latest successful changes (March 14, 2026)
- Added [AgentProvisioningCell](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/AgentProvisioningCell.swift) as a local `GeneralCell` that models install/start/connect/stop for `haven-agentd` through CellProtocol actions rather than direct UI-only orchestration.
- Added [AgentEnrollmentCell](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/AgentEnrollmentCell.swift) so Binding can verify a stable agent identity attestation over the loopback CellProtocol bridge, establish a normal CellProtocol agreement on that bridge, write a purpose-bound pairing artifact, materialize a verified `starter-auth.json` signed by the agent identity for `sprout`, and emit a mutually signed `agent-operator-entity-link.json` for `sprout bootstrap join`.
- Added an `Agent Setup Workbench` to [ConfigurationCatalogCell](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/ConfigurationCatalogCell.swift) with a purpose-driven skeleton for draft purpose, install/runtime/bridge stages, Binding<->agent pairing, live review queue + audit visibility, topology guidance, and activity/audit-oriented feedback.
- Registered both `cell:///AgentProvisioning` and `cell:///AgentEnrollment` in [BootstrapView](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/BootstrapView.swift) and surfaced the workbench in curated menus from [ContentView](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/ContentView.swift).
- Added a live localhost CellProtocol control bridge in `HavenAgentD` so Binding can read supervisor/inbox/review state and submit review decisions over actual CellProtocol instead of only polling persisted files.
- The local control bridge is loopback-only and token-gated from the agent config; Binding reuses that token for live operator calls, performs an explicit CellProtocol `addAgreement` before live `get/set`, and keeps the CLI review commands as fallback.
- The current operator topology is explicit: use one local control porthole when a human needs setup/review UX, but keep remote peers headless over CellProtocol instead of creating a porthole per connection.
- The current identity topology is also explicit: Binding keeps an operator identity, HavenAgentD keeps a separate stable device identity, and pairing happens over CellProtocol instead of by sharing one vault.
- The bootstrap identity path is now explicit too: the agent signs `starter-auth` over CellProtocol, Binding verifies it locally, and `sprout` consumes that artifact instead of minting a separate starter identity for the same flow.
- There is now an explicit staging/dev bootstrap test path too: `haven-agentd bootstrap-probe` verifies the local pairing artifacts and can then run a real `sprout bootstrap`, while `Scripts/test_haven_agentd_bootstrap.sh` gives the Binding workspace a one-command entrypoint for that probe.
- The remaining secure scaffold-admission step is also explicit: `sprout-admin entity-anchor accept-entity-link` can now re-sign an existing anchor snapshot with the paired contract ID, instead of relying on manual snapshot edits when staging must admit a newly paired agent key.
- Validation status:
  - `./Scripts/build_binding.sh` succeeded.
  - `swift test` in `HavenAgentD` now passes again after the identity/pairing + bridge-agreement work, including the reconnect/renewal, local control bridge and bootstrap-probe suites.
  - `./Scripts/test_binding.sh -only-testing:BindingTests` succeeded with the pairing workbench included.

## Latest successful changes (March 22, 2026)
- `CellProtocol` now models explicit signing vs key-agreement roles through `IdentityKeyRoleProviderProtocol` in [IdentityKeyRoleProviderProtocol.swift](/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/Sources/CellBase/Crypto/IdentityKeyRoleProviderProtocol.swift).
- `Identity` now carries `publicKeyAgreementSecureKey`, and Apple/Vapor/local runtime vault paths populate and preserve that metadata through add/save flows.
- Apple and Vapor vaults were corrected to write updated `VaultIdentity` values back into storage instead of mutating discarded copies.
- `ChatCell` now exposes first real content-crypto preparation endpoints in [ChatCell.swift](/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/Sources/CellBase/Cells/Chat/ChatCell.swift):
  - `crypto.recipients`
  - `crypto.prepareDraftEnvelope`
- Envelope preparation is implemented through [ContentCryptoEnvelopeUtility.swift](/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/Sources/CellBase/Crypto/ContentCryptoEnvelopeUtility.swift) and [CryptoAgilityModels.swift](/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/Sources/CellBase/Crypto/CryptoAgilityModels.swift), with recipient key wrapping, authenticated ciphertext, and sender signature.
- Recipient-side opening is now implemented too:
  - `ContentCryptoEnvelopeUtility.open(...)`
  - `OpenedContentEnvelope`
  - `ChatCell.crypto.openEnvelope`
- `ChatCell` now models recipient resolution explicitly through audience strategy endpoints:
  - `audience`
  - `audience.mode`
  - `audience.inheritedRecipients`
  - `audience.invitedRecipients`
  - `audience.resolvedRecipients`
  - `audience.invitations`
  - `audience.inviteIdentities`
  - `audience.acceptInvites`
  - `audience.declineInvites`
  - `audience.revokeInvites`
  - `audience.clearInvites`
- `ChatCell` now keeps invitation lifecycle state separate from explicit accepted recipients, so pending invites stay visible without silently becoming encryption recipients.
- `ChatCell` now supports proof-backed explicit invite flow:
  - `audience.invitationArtifacts`
  - `audience.invitationLedger`
  - `audience.inspectInvitationArtifact`
  - `audience.generateInvitationArtifacts`
  - `audience.generateInvitationAcceptance`
  - `audience.acceptInvitationArtifact`
- invitation records now retain generated artifacts and accepted invitee proofs, so explicit invites can move between runtimes without bypassing signature verification.
- `ChatCell` now enforces in-cell replay protection for proof-backed invite acceptance:
  - identical retries are idempotent
  - a second distinct acceptance for the same consumed artifact is rejected
  - superseded artifacts are rejected against the current invitation record
- `ChatCell` now makes invitation artifact issue-state more explicit:
  - `audience.invitationArtifacts` returns only currently issued artifacts
  - `audience.generateInvitationArtifacts` reuses an already-issued active artifact instead of rotating it
  - `audience.inspectInvitationArtifact` reports `issued`, `expired`, `consumed`, `revoked`, `declined`, `superseded`, `notIssued`, or `notFound`
  - if an invite is truly reissued, a fresh `invitationID` is minted
- `ChatCell` now keeps a durable invitation artifact ledger:
  - `audience.invitationLedger` exposes persisted inspection records keyed by `invitationID`
  - encode/decode roundtrip preserves `consumed`, `superseded`, and `revoked` artifact inspection
  - `clearInvites` removes active invite records but keeps durable inspection history
- `ChatCell` now keeps a requester-scoped prepared-envelope cache through:
  - `crypto.draftEnvelope`
  - `crypto.clearDraftEnvelope`
  - automatic invalidation when compose, audience mode, or invitation state changes
- `ChatCell` now exposes explicit encrypted persistence policy and archive endpoints:
  - `crypto.persistencePolicy`
  - `crypto.persistenceMode`
  - `crypto.encryptedMessages`
  - `crypto.clearEncryptedMessages`
- Default encrypted persistence remains conservative with `draftCacheOnly`, while opt-in `draftAndSentArchive` stores encrypted companion-envelopes for `sendComposedMessage`.
- Message payloads now carry crypto rendering metadata, and `crypto.openEnvelope(messageID: ...)` writes open/verify status back into both the encrypted archive and message-facing metadata.
- Current product default for embedded chat is documented as `hybrid`: inherit context where it is useful, support explicit invitees, and keep invitations as an explicit user-confirmed step.
- `ValueType` equality now correctly supports `.integer` and `.float`, which removed a false negative in crypto-related tests.
- Validation status:
  - `swift test --filter ChatCellTests` succeeded
  - `swift test --filter AppleIdentityVaultKeyStorageTests` succeeded
- `xcodebuild -quiet -workspace Binding.xcworkspace -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution build` succeeded
- `xcodebuild -quiet -workspace Binding.xcworkspace -scheme Binding -destination 'generic/platform=iOS' -disableAutomaticPackageResolution build` succeeded

## Latest successful changes (March 23, 2026)
- `ChatCell` now exposes explicit membership/rekey surfaces in [ChatCell.swift](/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/Sources/CellBase/Cells/Chat/ChatCell.swift):
  - `crypto.membership`
  - `crypto.rekeyStatus`
  - `crypto.requestRekey`
- Membership drift is now modeled as durable product state instead of an implicit side effect:
  - `membershipVersion`
  - current membership fingerprint derived from resolved recipients + audience mode + preferred suite + persistence mode
  - last membership-change timestamp/reason
  - last acknowledged rekey checkpoint
- Membership-affecting changes now mark `rekeyRequired`, while `crypto.requestRekey` acknowledges the current resolved audience as the new checkpoint without changing admission/auth semantics.
- Rekey behavior is now explicit and forward-only:
  - `EncryptedContentEnvelopeHeader` carries `envelopeGeneration`
  - `crypto.requestRekey` advances the generation only for future prepared/sent encrypted envelopes
  - historical archived envelopes keep their original generation and are not rewritten
- `ChatCell` now exposes `audience.removeContextMembers` so non-owner context members can be removed from inherited recipient resolution without touching explicit invitation history.
- Prepared, opened, and persisted encrypted envelope payloads now expose `envelopeGeneration`, making rotation/debug state visible in UI and diagnostics.
- Added targeted regression coverage in [ChatCellTests.swift](/Users/kjetil/Build/Digipomps/HAVEN/CellProtocol/Tests/CellBaseTests/ChatCellTests.swift):
  - membership change marks `rekeyRequired` until checkpoint acknowledgment
  - rekey checkpoint survives encode/decode roundtrip and flips back after a later membership mutation
  - forward-only envelope generation advances only after explicit `crypto.requestRekey`
  - removing a context member forces a fresh rekey and excludes that member from future envelopes
  - archived encrypted companions preserve their historical generation across later rekey events
- Documentation updated:
  - [Documentation/ChatCryptoRecipientSide.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/ChatCryptoRecipientSide.md)
  - [Documentation/VaultHardeningProgress.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/VaultHardeningProgress.md)
- Validation status:
  - `swift test --filter ChatCellTests` succeeded
- `xcodebuild -quiet -workspace Binding.xcworkspace -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution build` succeeded
- `xcodebuild -quiet -workspace Binding.xcworkspace -scheme Binding -destination 'generic/platform=iOS' -disableAutomaticPackageResolution build` succeeded

## Latest successful changes (March 27, 2026)
- Binding now has a deterministic conference configuration verifier with two layers:
  - `contract`: validates references, root probes, selected actions, and timing
  - `render`: renders the actual SwiftUI/AppKit surface and records render timing
- The verifier currently covers both:
  - `Conference Participant Portal`
  - `Conference Participant Nearby Follow-Up`
  - `Conference Control Tower`
- Added a dedicated XCTest wrapper in [BindingTests/CellConfigurationVerifierXCTest.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/BindingTests/CellConfigurationVerifierXCTest.swift) so the checks run more reliably than the current Swift Testing filter path.
- Added a runnable helper in [Scripts/run_conference_configuration_verifier.sh](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Scripts/run_conference_configuration_verifier.sh).
- Direct conference action routing was tightened so the verifier now catches and prevents regressions around:
  - participant actions like `Vis timeline`, `Oppdater treff`, `Oppdater discovery`, `Start scanner`, `Stop scanner`
  - nearby verified-contact follow-up and chat handoff
  - organizer actions like `Publish content` and `Discard draft`
- The verifier now runs each conference test in a fresh `xcodebuild` process, which makes it deterministic even when local Porthole/runtime singletons would otherwise leak state between tests.
- Nearby follow-up verification is now strong enough to inject a deterministic verified contact, route the same Porthole action the UI uses, and assert that participant preview state actually advances.
- The verifier now times out individual operations explicitly instead of hanging indefinitely on broken resolution or action paths.
- The diagnostics validator now understands direct `dispatchAction` buttons with explicit `url`, which removed a class of false negatives in conference workbenches.
- The macOS render verifier was stabilized by rendering inside a constrained container view instead of relying on a temporary `NSWindow`.
- Validation status:
  - `./Scripts/run_conference_configuration_verifier.sh all contract` succeeded
  - `./Scripts/run_conference_configuration_verifier.sh all render` succeeded

## Latest successful changes (March 28, 2026)
- `Conference Participant Portal` now has a clearer path into a dedicated local `Conference Nearby Radar` workbench in [ConfigurationCatalogCell.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/ConfigurationCatalogCell.swift).
- The nearby radar workbench is wired through the local `ConferenceNearbyRadar` runtime in [BootstrapView.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/BootstrapView.swift), including:
  - `Start scanner`
  - `Stop scanner`
  - `Tilbake til deltagerportal`
- The nearby radar now keeps a focused participant model instead of mixing all follow-up actions into loose nearby cards:
  - `Vis i siden` focuses one participant inline on the current page
  - the focused participant is rendered in a dedicated `Valgt deltager` area
  - follow-up actions (`Request contact`, `Start chat` / `Open chat`, `Marker for oppfølging`) are derived from the focused participant
- `Conference Participant Portal` recommendations now use a dedicated local `ConferenceParticipantMatchmakingSnapshot` in [BootstrapView.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/BootstrapView.swift), so the portal can:
  - keep recommendation focus inline on the current page
  - expose explicit next steps for the focused participant
  - survive local refresh without snapping tilbake til rå preview-state
- The participant recommendation flow is now explicit in GUI:
  - `Vis i siden` focuses one participant inline
  - `Åpne chat` / `Marker for oppfølging` / `Be om møte` live in the focused participant action surface
  - separate workbenches remain explicit secondary steps instead of hidden side effects
- The nearby radar is now more honest about spatial truth:
  - hard direction is only shown when the scanner actually has direction data
  - MPC-only peers are grouped under `Retning usikker` instead of being presented as a fake direction
- Participant conference cards now surface more explicit actions for sessions, recommendations, discovery, and nearby follow-up instead of reading like passive text-only cards.
- `ConferenceRecommendationCell` in `CellScaffold` now emits direct participant-shell chat actions for recommendation and search rows, so Binding can surface an honest `Start chat` path.
- The deterministic verifier now also covers `Conference Nearby Radar`:
  - contract verification in [CellConfigurationVerifierXCTest.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/BindingTests/CellConfigurationVerifierXCTest.swift)
  - render verification in [CellConfigurationVerifierXCTest.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/BindingTests/CellConfigurationVerifierXCTest.swift)
  - runner support in [run_conference_configuration_verifier.sh](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Scripts/run_conference_configuration_verifier.sh)
- Added a focused nearby-radar state test in [BindingTests.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/BindingTests/BindingTests.swift) that asserts:
  - `selectionSummary`
  - `selectedEntity`
  - `selectedEntityActions`
  - `spatialTruthSummary`
  - `Retning usikker` for approximate peers

## Current implementation plan (March 31, 2026)

- The next nearby-radar pass is documented in [ConferenceNearbyRadarImplementationPlan.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/ConferenceNearbyRadarImplementationPlan.md).
- The next organizer/dashboard uplift pass is documented in [ConferenceControlTowerUpliftPlan.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/ConferenceControlTowerUpliftPlan.md).
- The plan keeps Skeleton responsible for structure and actions, while the moving nearby radar itself is intended to become a Binding-local native SwiftUI surface.
- The plan is explicitly device-relative:
  - UWB direction and distance should update as the device rotates or moves
  - MPC-only peers must stay in an honest approximate or uncertain presentation
- The work is intentionally phased so we stabilize truth and test coverage before adding richer motion or visual polish.
- Staging admin preview improved materially on March 31, 2026:
  - access, audience discovery, insights, sponsor, session polling, session thread, and simulation now return meaningful organizer data
  - the main remaining organizer preview gaps are `content` and `system` / `AdminOverview`
  - see [CellScaffoldConferenceAdminPreviewStagingHandoff.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/CellScaffoldConferenceAdminPreviewStagingHandoff.md)

## Latest successful changes (March 29, 2026)
- `Conference Participant Portal` now routes agenda state through a local `ConferenceParticipantAgendaSnapshot` in [BootstrapView.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/BootstrapView.swift), so:
  - `Vis for deg`, `Vis timeline`, `Vis lagret` og `Fokuser governance` update the visible page immediately
  - local agenda selection survives bridge or preview refresh glitches instead of snapping tilbake til stale summary fields
  - sync trouble is surfaced as `storageSummary` / `persistenceStatus` instead of wiping out the visible mode and track focus
  - the portal now surfaces explicit agenda choice cards for active mode and active track focus, so the GUI shows `AKTIV NÅ` / `FOKUS NÅ` instead of forcing the user to infer state from passive summaries
- `Conference Participant Portal` now gives `Entity Discovery` the same inline-first treatment as nearby and recommendations:
  - a local `ConferenceParticipantDiscoverySnapshot` in [BootstrapView.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/BootstrapView.swift)
  - explicit discovery summaries (`statusSummary`, `selectionSummary`, `navigationSummary`, `nextStepSummary`)
  - an inline focused participant block with explicit next actions in [ConfigurationCatalogCell.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/ConfigurationCatalogCell.swift)
- Discovery no longer depends on hidden Porthole internals to decide whether it can refresh. The local discovery snapshot now uses the local preview shell directly, which makes the refresh path both simpler and more deterministic.
- Repair of persisted conference participant workbenches now recognizes the richer discovery snapshot wiring in:
  - [ConferenceConfigurationRepair.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/ConferenceConfigurationRepair.swift)
  - [ContentView.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/ContentView.swift)
- The deterministic verifier now also treats discovery as a first-class participant contract:
  - [CellConfigurationVerifierXCTest.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/BindingTests/CellConfigurationVerifierXCTest.swift)
  - [BindingTests.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/BindingTests/BindingTests.swift)
  - [run_conference_configuration_verifier.sh](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Scripts/run_conference_configuration_verifier.sh)
- The verifier now also treats the agenda snapshot as a first-class participant contract:
  - focused-action contract coverage for mode switching and track focus
  - render expectation that the local participant portal path no longer emits `Innholdet er ikke tilgjengelig akkurat nå.`
  - composition-oriented participant portal probing so the verifier reads `agendaSnapshot`, `matchmakingSnapshot`, `discoverySnapshot`, and `nearbyRadar` directly instead of stalling on the whole page
- `Conference Participant Portal` now treats nearby radar as an explicit embedded surface instead of just a loose list:
  - `Radar i siden` makes the inline spatial view visible in the page itself
  - `Åpne full radar` is now the explicit step into the larger nearby workbench
  - the large workbench is now named `Conference Nearby Radar · Full oversikt`
- Nearby radar now carries explicit local match and follow-up semantics in [BootstrapView.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/BootstrapView.swift):
  - `matchSummary`
  - `relevanceBadge` / `relevanceSummary` on focused and nearby participants
  - explicit `followUpSummary` and `chatSummary` for the selected participant
  - sector-level relevance badges so spatial direction and match strength can be read together
- Latest green targeted run on March 29, 2026:
  - `./Scripts/run_conference_configuration_verifier.sh participant contract`
  - `testConferenceParticipantAgendaSnapshotSupportsInlineSelectionAndActions`
  - `testConferenceParticipantDiscoverySnapshotSupportsInlineSelectionAndActions`
  - `testConferenceParticipantPortalContract`
  - `testConferenceParticipantPortalRenderer`
  - `conferenceNearbyRadarSeparatesApproximateSignalsFromFocusedParticipantActions`
  - `testConferenceNearbyRadarRenderer`

## Latest successful changes (March 30, 2026)
- `Conference Participant Portal` now exposes an explicit handoff to a dedicated `Conference Participant Chat` workbench in [ConfigurationCatalogCell.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/ConfigurationCatalogCell.swift).
- The dedicated chat surface is backed by a local `ConferenceParticipantChatSnapshot` in [BootstrapView.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/BootstrapView.swift), so we can:
  - keep chat state visible in the participant page
  - open a dedicated chat workbench only when the user explicitly chooses `Åpne chatflate`
  - preserve the existing participant preview shell as the underlying source of truth
- Nearby, discovery, and recommendation flows now upgrade from `Start chat` to `Åpne chatflate` instead of leaving chat hidden as shared-thread state only.
- Persisted participant configurations are now repaired forward to include the new `chatSnapshot` wiring in [ConferenceConfigurationRepair.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Binding/ConferenceConfigurationRepair.swift).
- The deterministic verifier now also covers the dedicated participant chat surface:
  - contract verification in [CellConfigurationVerifierXCTest.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/BindingTests/CellConfigurationVerifierXCTest.swift)
  - render verification in [CellConfigurationVerifierXCTest.swift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/BindingTests/CellConfigurationVerifierXCTest.swift)
  - runner support in [run_conference_configuration_verifier.sh](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Scripts/run_conference_configuration_verifier.sh)
- Latest green targeted run on March 30, 2026:
  - `./Scripts/run_conference_configuration_verifier.sh chat contract`
  - `testConferenceParticipantPortalContract`
  - `testConferenceParticipantPortalRenderer`
  - `testConferenceParticipantMatchmakingSnapshotSupportsInlineSelectionAndActions`
  - `testConferenceParticipantDiscoverySnapshotSupportsInlineSelectionAndActions`
  - `testConferenceParticipantChatContract`
  - `testConferenceParticipantChatRenderer`
  - `testConferenceNearbyParticipantProfileRenderer`
- Latest green targeted checks on March 28, 2026:
  - `testConferenceParticipantMatchmakingSnapshotSupportsInlineSelectionAndActions`
  - `testConferenceNearbyRadarContract`
  - `testConferenceNearbyRadarRenderer`
  - `conferenceNearbyRadarSeparatesApproximateSignalsFromFocusedParticipantActions`
  - `xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build`

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

## Canonical doc placement
- Core protocol/runtime documentation needed for CellProtocol/HAVEN interoperability belongs in:
  - `CellProtocolDocuments` (submodule), for example:
    - `CellProtocolDocuments/Book/13_Agent_Instructions.md`
    - `CellProtocolDocuments/Book/14_Perspective_Runtime_Matching.md`
- Binding `Documentation/` should primarily contain Binding-specific integration notes.
- Product/commercial behavior built on top of CellProtocol/HAVEN should stay in product repositories (for example DiMy repos), including their product docs.

### Quick links
- Architecture overview: [Prompts/Architecture.md](../Prompts/Architecture.md)
- Contributing guidelines: [Prompts/CONTRIBUTING.md](../Prompts/CONTRIBUTING.md)
- Edge menus overlay: [Prompts/EdgeMenusOverlay.md](../Prompts/EdgeMenusOverlay.md)
- Apple Intelligence cell: [Prompts/AppleIntelligenceCell.md](../Prompts/AppleIntelligenceCell.md)
- Explainer for LLMs: [Prompts/ExplainToAnotherLLM.md](../Prompts/ExplainToAnotherLLM.md)
- Documentation index (folder): [Documentation/](./)
- Prompts index (folder): [Prompts/](../Prompts/)
- Skeleton editor: [Documentation/SkeletonEditor.md](Documentation/SkeletonEditor.md)
- Skeleton modifiers and new elements: [Documentation/SkeletonModifiers.md](Documentation/SkeletonModifiers.md)
- Skeleton elements reference: [Documentation/SkeletonElements_Detailed.md](Documentation/SkeletonElements_Detailed.md)
- Full Library UX/UI: [Documentation/FullLibraryView.md](Documentation/FullLibraryView.md)
- Conference debug playbook: [Documentation/ConferenceDebugPlaybook.md](Documentation/ConferenceDebugPlaybook.md)
- Conference configuration verifier: [Documentation/ConferenceConfigurationVerifier.md](Documentation/ConferenceConfigurationVerifier.md)
- Conference demo story: [Documentation/ConferenceDemoStory.md](Documentation/ConferenceDemoStory.md)
- CellScaffold prompt for staged conference demo personas: [Documentation/CellScaffoldConferenceDemoPersonasPrompt.md](Documentation/CellScaffoldConferenceDemoPersonasPrompt.md)
- CellScaffold parity prompt for conference demo flows: [Documentation/CellScaffoldConferenceParityPrompt.md](Documentation/CellScaffoldConferenceParityPrompt.md)
- CellScaffold Playwright prompt for conference demo smoke tests: [Documentation/CellScaffoldPlaywrightPrompt.md](Documentation/CellScaffoldPlaywrightPrompt.md)
- Cross-vault identity enrollment: [Documentation/CrossVaultIdentityEnrollment.md](Documentation/CrossVaultIdentityEnrollment.md)
- VC profile for identity linking: [Documentation/IdentityLinkVCProfile.md](Documentation/IdentityLinkVCProfile.md)
- Conference organizer access protocol: [Documentation/ConferenceOrganizerAccessProtocol.md](Documentation/ConferenceOrganizerAccessProtocol.md)
- Key handling and content crypto assessment: [Documentation/KeyHandlingAndContentCryptoAssessment.md](Documentation/KeyHandlingAndContentCryptoAssessment.md)
- Vault hardening progress: [Documentation/VaultHardeningProgress.md](Documentation/VaultHardeningProgress.md)
- Chat crypto recipient side: [Documentation/ChatCryptoRecipientSide.md](Documentation/ChatCryptoRecipientSide.md)
- Next step prompt: [Documentation/NextStepPrompt.md](Documentation/NextStepPrompt.md)
- Component drag/drop plan: [Documentation/ComponentDragDropPlan.md](Documentation/ComponentDragDropPlan.md)
- HavenAgentD integration note: [Documentation/HavenAgentD.md](Documentation/HavenAgentD.md)
- Agent Setup Workbench UI review: [Documentation/AgentSetupWorkbench_UI_Review.md](Documentation/AgentSetupWorkbench_UI_Review.md)
- HavenAgentD setup/test runbook: [Documentation/HavenAgentD_Setup_Test_Runbook.md](Documentation/HavenAgentD_Setup_Test_Runbook.md)
- How to create a Cell: [Documentation/HowTo_CreateCell.md](Documentation/HowTo_CreateCell.md)
- Perspective runtime matching (canonical): [CellProtocolDocuments/Book/14_Perspective_Runtime_Matching.md](../CellProtocolDocuments/Book/14_Perspective_Runtime_Matching.md)
- Perspective local stubs: [Documentation/PerspectiveCell_WeightedMatching_Proposal.md](Documentation/PerspectiveCell_WeightedMatching_Proposal.md), [Documentation/Perspective_Signal_Network_Implementation.md](Documentation/Perspective_Signal_Network_Implementation.md)

See also:
- `Prompts/EdgeMenusOverlay.md`
- `Prompts/AppleIntelligenceCell.md`
- `Prompts/ExplainToAnotherLLM.md`
- `Prompts/Architecture.md`
