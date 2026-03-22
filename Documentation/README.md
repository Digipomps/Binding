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
- Cross-vault identity enrollment: [Documentation/CrossVaultIdentityEnrollment.md](Documentation/CrossVaultIdentityEnrollment.md)
- VC profile for identity linking: [Documentation/IdentityLinkVCProfile.md](Documentation/IdentityLinkVCProfile.md)
- Key handling and content crypto assessment: [Documentation/KeyHandlingAndContentCryptoAssessment.md](Documentation/KeyHandlingAndContentCryptoAssessment.md)
- Vault hardening progress: [Documentation/VaultHardeningProgress.md](Documentation/VaultHardeningProgress.md)
- Chat crypto recipient side: [Documentation/ChatCryptoRecipientSide.md](Documentation/ChatCryptoRecipientSide.md)
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
