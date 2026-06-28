# Binding GUI, functionality and CellProtocol access review - 2026-06-27

## Scope

This report reviews Binding as it stands in the local repo, with emphasis on the
Personal Co-Pilot / Co-Pilot Chat experience and the CellProtocol ownership and
access model behind it.

Evidence used:

- `Binding/ContentView.swift` Personal Co-Pilot navigation and menu seeding.
- `Cells/ConfigurationCatalogCell.swift` Personal Co-Pilot policy, catalog
  entries and skeletons.
- `Binding/ChatWorkbenchParityCells.swift` local Co-Pilot, provider,
  ContactEndpoint and GraphIndex cells.
- `Binding/BootstrapView.swift` local cell registration.
- `BindingTests/BindingTests.swift`,
  `BindingTests/ChatWorkbenchParityTests.swift` and
  `BindingTests/CellConfigurationVerifierXCTest.swift`.
- Existing reports and product docs in `Documentation/`, especially
  `BindingSkeletonSurfaceAudit_2026-06-26.md`,
  `ChatWorkbenchBindingParity.md`,
  `PersonalCopilotDesignSystem.md`,
  `PersonalCopilotV1_DataAndPermissionMap.md`,
  `PersonalCopilotV1_CellContracts.md` and
  `AppStoreReviewNotes_PersonalCopilotV1.md`.
- CellProtocol identity/access docs:
  `../CellProtocolDocuments/Book/03_Identity_Model.md`,
  `../CellProtocolDocuments/Book/04_Agreements_Contracts.md`,
  `../CellProtocolDocuments/Book/06_CellResolver.md` and
  `../CellProtocol/SECURITY.md`.

Advisor note: I asked two local explorer advisors for independent UX and
CellProtocol/access review. The UX advisor agreed with the main direction,
while adding two important repo-grounded nuances: Binding's default demo/start
configuration points at `Co-Pilot`, but the native Personal navigation still
starts naturally from `Personal Home`; and Library/JSON/Debug controls are too
close to the ordinary Personal UX. The CellProtocol/access advisor confirmed
the owner/requester/provider/side-effect shape, and sharpened one important
distinction: owner-affordance diagnostics help the user recover context, but
they are not themselves authorization. The prior
`BindingSkeletonSurfaceAudit_2026-06-26.md` includes useful Claude input, but
GLM/NanoGPT is still not counted as verified input here.

## Executive assessment

Binding is moving in the right direction conceptually: the default product is
now framed as a curated Personal Co-Pilot rather than a general app/plugin
host, and Co-Pilot Chat is treated as the central Porthole surface. The
CellProtocol shape is also mostly right: local cells are owner/requester scoped,
provider cells are not global, native permissions are mediated locally, and
analyze/open-helper paths are explicitly tested as side-effect free.

The GUI is not yet consistently good as a user product across all available
surfaces. The Co-Pilot Chat model is strong, but the app still exposes a mix of
polished product surfaces, utility workbenches and developer/control surfaces.
Some of those surfaces render and pass contract checks, but they still feel like
diagnostic panels. On iPhone especially, the experience must be simpler: one
prompt area, one primary action, fewer visible parallel tools, and more of the
technical state hidden under `Mer -> Avansert`.

Security/access verdict: the implementation is on the CellProtocol path, but
not fully proven end-to-end for every surface. The strongest tests run with
`debugValidateAccessForEverything = false` for the important Co-Pilot
side-effect and helper-routing flows. Some broader/local resolver and graph
tests still use debug access, so they prove contract shape and rendering, not
complete policy enforcement.

## What Binding exposes today

### App Store / Personal Co-Pilot default

The Personal Co-Pilot destination enum lists these visible destinations:

- `Personal Home`
- `My Profile`
- `Publish Public Profile`
- `Public Profile Directory`
- `Matches`
- `Co-Pilot`
- `Agenda Context`
- `Vault / Ideas`
- `Meeting Intent`
- `Privacy Audit`
- `Personal Co-Pilot Catalog`
- `Apple Intelligence`
- `Entity Scanner`
- `Workflow Studio`

`personalCopilotV1MenuConfigurations()` seeds 15 skeleton configurations,
including `Calendar Store`. The original static audit from 2026-06-26 found:

- 15 configs
- 0 structural errors
- 16 warnings
- 1131 skeleton elements
- 122 buttons
- 47 inputs
- 1 visualization

After the same-day hardening pass below, the local static audit is improved to
15 configs, 0 structural errors and 4 warnings. That means the default catalog
is renderable and materially cleaner, not that all GUI flows are finished as a
product.

### Navigation model

Phone tabs are:

- `Home`
- `Matches`
- `Chat`
- `Vault`
- `Profile`

macOS/iPad sidebar sections are:

- `Personal`
- `Network`
- `Workspace`

This model is understandable for a native app shell. The mismatch to watch is
that the product idea is "Co-Pilot as central surface", while navigation still
invites the user to think in separate app sections. That is acceptable if Chat
is default and other sections are "supporting surfaces", but it becomes noisy
if Library, Workflow Studio, Entity Scanner and advanced tools compete with the
prompt as first-class user choices.

Advisor nuance: the codebase currently supports both a Co-Pilot default start
configuration and a Home-first navigation model. That can be intentional, but
the product decision must be explicit:

- If Binding is "chat as the front door", first launch should land in Co-Pilot
  and Home becomes status/overview.
- If Binding is "personal workspace with chat helper", Home can be first, but
  it must route the user into Co-Pilot as the main action rather than making
  them choose among many surfaces.

### Full Library

Full Library is a search/facet/catalog browser with:

- all configs
- purpose-based matches
- sources
- templates
- token filters
- facet counts
- skeleton preview

It is useful as a power surface and for Binding-as-Porthole work. For a normal
Co-Pilot user it should stay clearly secondary, ideally opened from Co-Pilot
resource matches or `Mer`, not treated as another primary way to "use the app".
Controls such as JSON copy, Debug, source/policy metadata and raw preview
diagnostics should not sit next to the ordinary Personal task flow.

### Co-Pilot Chat

Co-Pilot Chat is the most important surface. It should solve this user problem:

> I write what I want to accomplish, Binding understands the purpose/interests,
> finds the allowed cells/tools/providers in my scope, explains the next step,
> and only performs side effects after I explicitly confirm.

Current implementation:

- endpoint: `cell:///PersonalChatHub`
- skeleton name: `Co-Pilot`
- source cell name: `PersonalChatHubCell`
- top-level tabs: `Samtale`, `Aktivt`, `Mer`
- `Mer` tabs: `Verktøy`, `Hjelp`, `AI`, `Moderering`, `Personvern`,
  `Avansert`
- prompt composer writes to `chatHub.setComposer`
- primary prompt action is now icon-based:
  - `↑` for `chatHub.assistant.analyzeDraft`
  - `↗` for `chatHub.ui.openSuggestedHelper`
  - visibility switches on `chatHub.state.ui.hasActionableSuggestion`
- `Aktivt` shows open helpers, invites, polls, created modules and submitted
  needs.
- advanced state such as provider kind, execution scope, prompt understanding
  and purpose/interest excerpts is moved to `Mer -> Avansert`.

Quality:

- Good: this is the right product model. The prompt is central, helper opening
  is separate from accepting side effects, and technical details are mostly
  out of the default `Samtale` view.
- Good: tests assert that old "Start her" / duplicate "Co-Pilot Chat" help
  card copy no longer appears in the `Samtale` panel, and that help text lives
  under `Mer -> Hjelp`.
- Good: tests cover iOS-style prompts for idea capture, todo, project and
  Vault/Graph routing.
- Still weak: the surface contains many helper modes and action paths. Even if
  hidden by tabs, the underlying skeleton is large enough that mobile visual
  regressions are likely unless screenshot tests are added.
- Still weak: `Aktivt` has useful but abstract sections. A user may not know
  why "open helpers", "created from chat" and "reported needs" are distinct.
- Still weak: the primary icon action uses arrows, but there is no verified
  screenshot evidence here that the affordance reads clearly on iPhone.

### Profile, publish, directory, matches and privacy

Purpose:

- let the user draft profile data locally;
- publish only after explicit consent;
- search/discover public profiles;
- handle consent-based matching;
- audit privacy-sensitive actions.

Quality:

- The data/permission model is well documented: drafts stay local until
  publish/share, remote configurations get no native permissions by default,
  and denied permissions must leave an honest reduced-capability state.
- The App Store notes correctly position these as curated Personal Co-Pilot
  surfaces, not a general marketplace or conference demo.
- The UI still needs more live backend/staging evidence before it can be called
  production-complete. Several cloud cells are documented as CellScaffold
  responsibilities rather than fully local Binding implementations.

### Agenda Context, Calendar Store and Meeting Intent

Purpose:

- provide local agenda/reminder context to Co-Pilot after explicit user action;
- build meeting intent metadata without assuming Calendar, camera or mic
  capability.

Quality:

- The permission map is right: Calendar/Reminders are mediated by local Binding
  cells, and remote configurations never receive native permission directly.
- Meeting/Jitsi is correctly framed as metadata/placeholder in V1; it must not
  request camera/microphone merely because a meeting bridge exists.
- The UI is functionally useful but not as central as Co-Pilot. It should feel
  like a helper/resource that Chat can open, not a separate product lane the
  user must understand first.

### Vault / Ideas and Graph Index

Purpose:

- capture local notes, ideas and projects;
- support Obsidian-like wiki-link graph indexing;
- expose knowledge graph functions to Co-Pilot/resource routing.

Current implementation:

- `cell:///Vault` is registered identity-unique and persistent.
- `cell:///GraphIndex` is registered identity-unique and persistent.
- `BindingGraphIndexCell` supports:
  - `graph.state`
  - `graph.reindex`
  - `graph.outgoing`
  - `graph.incoming`
  - `graph.neighbors`
- Co-Pilot tests route prompts such as "vis ideer og prosjektstyring i vault"
  to `configuration:vault-ideas` and graph/Obsidian prompts to
  `configuration:graph-index`.
- The Personal catalog now preserves the richer `Vault / Ideas` surface instead
  of downgrading `cell:///vault` to the generic Vault control surface during
  catalog sync.
- The `Vault / Ideas` surface includes explicit local seed actions, a local
  notes/project list, and a small Obsidian-like graph preview with graph
  reindex/query actions.

Quality:

- Good contract foundation. Vault and graph resolve locally, the graph reindex
  test verifies nodes/edges from wiki links, and the Personal catalog now keeps
  a graph visualization available in the `Vault / Ideas` surface.
- The GUI is still not an Obsidian-class graph product. It is now a better local
  product seed with idea/project/list/graph pieces, but the next UX step is a
  richer integrated loop: prompt -> capture/structure -> linked notes/projects
  -> graph visualization -> next action.
- The graph should remain local/private by default. Any folder/file-backed
  vault must require explicit picker/folder consent.

### Apple Intelligence and Local LLM

Purpose:

- provide local, private prompt classification inside chat scope;
- prefer deterministic rules first, then Apple Intelligence, then local LLM,
  then RAG/API/agent only when allowed by context and grants.

Current implementation:

- `BindingAppleIntelligenceProviderCell`:
  - `cell:///AppleIntelligence`
  - GET `ai.state`
  - SET `ai.classifyIntent`
  - SET `ai.sendPrompt`
  - owner-scoped grants per keypath
  - state includes `providerID=binding.apple-intelligence`,
    `kind=apple_intelligence`, local privacy, no network, user approval
    required, purpose refs and interests.
  - uses Foundation Models availability checks when the SDK/runtime supports
    it; otherwise returns `unavailable` and falls back.
  - context pack explicitly includes only chat draft, perspective summary and
    granted descriptors, and excludes contacts, calendar, mic/camera, vault and
    other threads.
- `BindingLocalLLMCell`:
  - `cell:///LocalLLM`
  - GET `state`
  - SET `llm.generate`
  - SET `llm.classifyIntent`
  - SET `llm.health`
  - state is `unavailable` when no local endpoint is configured.

Quality:

- Good privacy shape: providers are cells in scope, not global providers.
- Good availability behavior: "unavailable" is a state, not a crash.
- Current Local LLM generation/classification is still deterministic fallback
  shaped like a local provider unless an endpoint/runtime is configured. That
  is acceptable for contract tests, but not enough to claim real local LLM
  inference quality.
- Apple Foundation Models availability is SDK/runtime dependent. Do not present
  it as active on devices where state says unavailable.

### Entity Scanner

Purpose:

- local Apple-framework-mediated entity/contact/proximity discovery;
- never give remote configurations native camera/nearby permissions directly.

Quality:

- Good boundary in documentation and policy.
- Static audit warns that Entity Scanner has several unused references. This
  may reflect future whole-surface intent, but it is currently a product and
  audit smell: either expose those references in clear user sections or remove
  them from the default surface.

### Workflow Studio

Purpose:

- build/test personal workflows within approved Personal Co-Pilot scope.

Quality:

- Useful for power users and development.
- It still leaks technical text such as condition keypaths/parser text in the
  normal UI according to the latest skeleton audit. It should be split into a
  user-facing "build flow" experience and an advanced/parser diagnostics panel.
- For App Store/default Personal Co-Pilot, Workflow Studio should not compete
  with the chat-first path unless it is clearly framed as an advanced tool.

### Porthole, skeleton editor and control/developer surfaces

Purpose:

- host CellConfigurations;
- inspect and edit skeletons;
- load cells and control renderer/runtime behavior;
- support Binding as a CellProtocol workbench.

Quality:

- Valuable for development and parity work.
- Not suitable as a normal user default. Examples such as Porthole Control,
  Graph Index Control, raw connected emitters and JSON/status panels should be
  in advanced/debug contexts.

### HavenAgentD, APNS, phone approval and remote entity endpoints

Purpose:

- route signed/reviewed agent intents;
- notify phone/device;
- handle device approval loops and entity endpoint messages.

Quality:

- The repo contains significant HavenAgentD/APNS-related work and docs, but
  this report did not live-test a phone/push/HAVENAgentD round.
- Co-Pilot correctly treats agent actions as review/signing flows, not direct
  script execution from chat.
- The HavenAgentD security model is aligned with the Co-Pilot side-effect
  model: cloud/HAVEN entities may request structured intent, but the user-owned
  Mac decides whether that intent maps to a local side effect. The daemon must
  not expose a general scripting channel.
- Live staging/device verification remains a separate gate before this can be
  described as end-to-end working.

## CellProtocol ownership and access review

### Ground truth from CellProtocol

CellProtocol's identity model says:

- entities are never exposed directly;
- identities are domain-scoped operational handles;
- there is no global identifier and no automatic cross-domain linkage;
- every Absorb/Meddle call includes identity/signature/domain/purpose/evidence;
- resolver checks signature, domain compatibility, contract existence,
  capability permissions and required conditions.

Agreement/contract docs say:

- nothing is implicit;
- agreements express desired capabilities but do not grant access;
- contracts grant concrete capabilities to identities under conditions;
- resolver enforces all contracts for Meddle and Absorb;
- no authority exists without explicit contract.

Resolver docs say:

- nothing bypasses the resolver;
- it enforces identity validation, contract/capability enforcement, condition
  evaluation, flow ordering, replay and transport policy;
- remote `cell://host/...` routing requires explicit host registration.

Core CellProtocol implementation details reinforce this:

- `CellUsageScope` includes `identityUnique`, which is the right scope for
  owner/private personal cells.
- `CellAuthorizationPolicy` has explicit paths for owner proof, signed
  contract, cell-specific grants and debug bypass.
- UUID equality alone is not enough when the public signing key/proof does not
  match the stored owner identity.
- `debugValidateAccessForEverything` is a real bypass and must not be counted
  as production authorization evidence.

### What Binding does well

- Local Personal Co-Pilot cells are registered as `identityUnique` with
  `identityDomain: "private"`:
  - `PersonalChatHub`
  - `AppleIntelligence`
  - `LocalLLM`
  - `ContactEndpoint`
  - `Vault`
  - `GraphIndex`
- `BindingPersonalChatHubCell` grants readable and writable keypaths through
  `agreementTemplate.addGrant` and validates `requester` with `validateAccess`
  on get/set.
- Provider discovery is requester-scoped: Co-Pilot resolves
  `cell:///AppleIntelligence` and `cell:///LocalLLM` through the resolver using
  the current requester, then reads only the provider state visible in that
  scope.
- Apple Intelligence and Local LLM are real cell-scoped providers:
  - no global provider registry is needed for chat to discover them;
  - provider states are read through `cell:///AppleIntelligence` and
    `cell:///LocalLLM`;
  - providers require user approval and cannot be invoked directly from chat as
    silent side effects.
- Chat analyze/open helper is non-mutating:
  - `assistant.analyzeDraft` returns `sideEffect=false`;
  - `ui.openSuggestedHelper` opens UI and returns `sideEffect=false`;
  - explicit helper actions such as `workItem.capture` are the mutating step.
- `sendComposedMessage` is blocked until the invite status is accepted and also
  blocked when participants are blocked.
- `ContactEndpoint` has a scoped descriptor/state and supports signed
  `contact.request`; the request path validates endpoint status, allowed topic,
  action, purpose, requester domain, expiry/skew, payload size, signature and
  replay nonce before creating a ticket.
- App Store policy gates require Personal Co-Pilot scope and approved
  endpoints/hosts. Conference/demo/admin/sponsor surfaces are excluded unless
  debug flags enable them.
- Native permission boundaries are documented correctly: remote configs do not
  get camera, mic, calendar, reminders, contacts, nearby/Bluetooth, vault/files
  or Apple Intelligence access directly.

### Remaining access risks and gaps

- Some tests still use `CellBase.debugValidateAccessForEverything = true`.
  Those prove shape and renderer behavior, but not final resolver enforcement.
  The critical Co-Pilot no-side-effect tests do run with debug access off, which
  is good.
- Static skeleton audit still warns that several production skeletons lack a
  visible owner-entity/Co-Pilot access affordance. This is a real UX/security
  context issue, but not an authorization primitive by itself: users must be
  able to understand which identity/cell scope they are operating in without
  seeing raw protocol internals, while actual access must still be enforced by
  owner proof, signed contract or explicit cell-specific grant.
- `Co-Pilot` still has an unused `perspective` reference in the static audit.
  That should either become a visible/contractual context source or be
  documented as runtime-only context.
- Entity Scanner has unused references. Unused references increase the chance
  that future UI or prompts include descriptors the user did not actually need
  for the current task.
- The report did not prove that every Full Library or debug surface filters
  hidden/unavailable cell names from prompt/context packs. The policy exists,
  but this needs broader negative tests.
- APNS/device-token privacy was not live-verified here. The desired design is
  right: device token should live only in a user-owned APNS cell and be used by
  endpoint cells through scoped grants. Current status needs a separate live
  test against staging.
- HavenAgentD pairing/local-control paths deserve a dedicated forged/stale
  pairing negative test. The intended boundary is local policy and signed
  intent, but cross-scaffold `capabilityRefs` should never be treated as
  authority without proof/contract.

## UX quality by goal

| Goal | Current quality | Notes |
| --- | --- | --- |
| Make chat the central Porthole surface | Good but not fully polished | Default start config and tests point at Co-Pilot; other surfaces still compete in navigation/library. |
| Resolve Home vs Chat first-run model | Medium | Repo supports both Home-first navigation and Co-Pilot default start; product decision should be explicit. |
| Let user prompt naturally | Good foundation | Prompt-to-helper tests cover idea, todo, project, docs RAG, Vault/Graph and work item cases. |
| Explain what happens next | Medium | `primaryActionHint`, `whySummary`, prompt log and help tab exist, but mobile affordance needs visual proof. |
| Avoid side effects during analyze/open | Strong for Co-Pilot | Tests check counters and `sideEffect=false` with access debug off. |
| Open helpers from prompt | Good foundation | Recent tests verify helper opening and staying on `Samtale`; must still be visually checked on iPhone. |
| Support ideas/projects/graph | Medium | Routing and local graph contract work; GUI is not yet a rich Obsidian-like workspace. |
| Keep default UI non-technical | Medium | Chat improved; Workflow Studio, Porthole/Graph controls and some catalog surfaces remain technical. |
| Use local/private AI first | Good contract, partial runtime | Apple/LocalLLM provider contracts exist; real Apple/local model availability varies by device/runtime. |
| Respect CellProtocol ownership | Good structure | IdentityUnique/private registrations and grants exist; some tests still rely on debug access. |
| Hide unavailable/unauthorized resources | Medium | App Store policy gates exist; broader no-leak prompt/context tests are still needed. |
| Support live APNS/HavenAgent chain | Unknown in this report | Docs and code exist, but no live phone/push round was run here. |

## Priority recommendations

1. Keep Co-Pilot Chat as the only default first-run work surface on phone.
   Home, Vault, Profile and Library can remain reachable, but the app should
   clearly teach: write prompt -> get explanation -> open helper -> confirm.

   If the team chooses Home-first instead, Home must make Co-Pilot the obvious
   primary action and avoid becoming a second command center.

2. Finish the mobile presentation pass:
   - one composer;
   - one primary icon action;
   - no duplicate Co-Pilot title cards;
   - no helper/help card in `Samtale`;
   - active helper appears inline without jumping the user away from chat;
   - visual screenshot tests for iPhone widths.

3. Add a reusable owner/scope affordance for Personal Co-Pilot production
   surfaces. It should say, in user language, which private workspace/cell scope
   is active and where to manage access, without showing raw keypaths.

4. Move all raw/protocol/debug detail out of default product surfaces:
   provider kind, execution scope, keypaths, raw JSON, parser keys and connected
   emitter lists belong under `Mer -> Avansert` or developer mode.

5. Turn Vault/Ideas/Graph into a coherent product loop:
   prompt -> draft idea/project -> confirm capture -> show local note/project ->
   show graph links -> suggest next step. The graph contract is there; the GUI
   needs the integrated experience.

6. Add enforcement tests with debug access off for each high-value cell class:
   Profile publish, Matches, Vault, GraphIndex, Entity Scanner, Agenda,
   Meeting Intent, Workflow Studio and Full Library context generation.

7. Add no-leak tests for prompt/provider context packs:
   unavailable cells, unauthorized cells, native contacts/calendar/vault and
   other threads must not appear in provider prompts or default UI.

8. Add a visual/functional catalog smoke runner:
   iterate every Personal Co-Pilot V1 configuration, render at iPhone and mac
   widths, type into fields, click safe buttons, capture screenshots and record
   whether the result is user-readable or only technically valid.

9. Separate product and developer catalogs more sharply. Binding can be both a
   Personal Co-Pilot app and a CellProtocol workbench, but those modes should
   not blur in the user-facing default.

10. Run a separate live chain verification for APNS/device token/HavenAgentD:
    device token registration in a user-owned APNS cell, endpoint-cell initiated
    notification, phone receipt, HAVENAgentD completion notification, and
    Co-Pilot prompt for next step.

## Bottom line

Binding is not "done", but it is now close to the right architecture. The
largest remaining work is not more raw capability. It is consolidation:
Co-Pilot must become the calm front door to the available cells, while Library,
Workflow Studio, raw graph controls, provider diagnostics and agent machinery
move behind progressive disclosure.

CellProtocol-wise, the core invariant is mostly respected: owner-scoped cells,
requester validation, explicit grants and side-effect boundaries are present.
The next hardening step is proving that invariant across every visible surface
with debug access off and with negative no-leak tests.

## Verification update, same day

After the first report pass, two additional hardening iterations added targeted
ChatWorkbench access/context tests, removed stale/dangling catalog references,
added reusable Personal Co-Pilot recovery actions, preserved the richer
Vault/Ideas graph surface during catalog sync, and reran the most relevant
local gates through an unsigned `build-for-testing` plus
`test-without-building` path.

Implementation changes verified here:

- `PersonalCopilotNavigator` now handles `navigator.openCopilot`.
- Non-chat Personal surfaces get a compact `Assistent` recovery action that
  opens `cell:///PersonalCopilotNavigator` with `dispatchAction`; the Co-Pilot
  page suppresses this action to avoid another duplicate Co-Pilot affordance.
- `Agenda Context`, `Calendar Store` and `Workflow Studio` now also get that
  recovery action even though their core skeletons come from existing factory
  surfaces rather than `personalSurfacePage`.
- `Personal Home` no longer carries the unused top-level
  `personalNavigator`/`cell:///PersonalCopilotNavigator` reference. Its visible
  buttons use direct endpoint dispatch instead.
- The Personal `Vault / Ideas` descriptor now resolves to
  `personalVaultIdeasMenuConfiguration()` and is force-refreshed when catalog
  entries already exist, so the catalog keeps the local graph/list experience.

New/confirmed checks:

- `ChatWorkbenchParityTests`: 30 tests passed.
  - verifies Co-Pilot helper routing for idea, todo, project and
    Vault/Obsidian graph prompts;
  - verifies analyze/open-helper remain side-effect-free;
  - verifies negative poll prompts do not open a poll helper;
  - verifies local provider evaluation fixture still runs for deterministic
    rules, Apple Intelligence and LocalLLM contracts;
  - adds a strict no-global-provider/no-private-scope context-pack check;
  - adds a foreign-requester denial check for ChatHub, Apple Intelligence and
    LocalLLM cells with debug access disabled.

- Fresh `build-for-testing` in `/private/tmp/binding-codex-dd`: passed with
  `CODE_SIGNING_ALLOWED=NO`.

- `CellConfigurationVerifierXCTest/testConfigurationCatalogSkeletonsPassStaticStructureAudit`:
  passed with 15 configs, 0 errors and 4 warnings.
  - `Agenda Context`: 0 warnings after adding the assistant recovery action.
  - `Calendar Store`: 0 warnings after adding the assistant recovery action.
  - `Workflow Studio`: owner/Co-Pilot warning removed; 2 technical-copy
    warnings remain.
  - `Personal Home`: 0 warnings after removing the dangling navigator
    reference.
  - `Vault / Ideas`: 2 references, 50 elements, 5 buttons, 1 visualization and
    0 warnings after preserving the graph-enabled Personal surface.
  - remaining warnings are concentrated in `Co-Pilot`, `Entity Scanner` and
    `Workflow Studio`.

- `CellConfigurationVerifierXCTest/testPersonalCopilotLocalSurfacesLoadWithoutReferenceFailures`:
  passed.

- `CellConfigurationVerifierXCTest/testPersonalHomeNavigatorCanOpenProfileAuditAndPublishSurfaces`:
  passed and now verifies direct navigator dispatch for Co-Pilot, My Profile,
  Privacy Audit and Publish Public Profile.

- `CellConfigurationVerifierXCTest/testConferenceShowcaseButtonsCanExecuteWithoutBrokenBindings`:
  passed.

- `NotificationEnrollmentManagerTests` and `NotificationCallbackClientTests`:
  5 tests passed. These verify staging callback URL defaults, registration
  payload shape, workflow topic normalization and bridge query items. They do
  not prove live APNS delivery.

Observed environment limitation:

- The unsigned macOS test runner still logs Apple keychain/signing noise such
  as `Got no signed data` and `SecKeyCreateRandomKey_ios ... -34018`. This
  matches the existing verifier note that unsigned/local runner keychain noise
  is not equivalent to a signed app/device failure. Live owner-proof, APNS token
  issuance and phone notification delivery still require a signed device or
  simulator run with matching entitlements and staging APNS sandbox config.

- A targeted Swift Testing filter for
  `BindingTests/personalHomeUsesDirectCopilotNavigatorDispatchActions` compiled
  but executed 0 tests through the current `xcodebuild -only-testing` filter.
  The same direct-navigator behavior is covered by the XCTest smoke above; the
  Swift Testing filter behavior should be cleaned up separately if we want that
  single test to be individually invokable.

Remaining concrete static-audit warnings after the latest run:

- `Co-Pilot` still has an unused `perspective` reference.
- `Entity Scanner` still has unused references to `chatHub`, `entity`,
  `perspective`, `publicProfiles` and `vault`.
- `Workflow Studio` still exposes technical copy around prompt/parser/condition
  keypaths in the normal surface.
