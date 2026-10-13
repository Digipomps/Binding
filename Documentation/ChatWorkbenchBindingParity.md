# Chat Workbench Binding Parity

Dette notatet er Binding sin ground-truth for paritet med CellScaffold
`PersonalChatHubCell` / `Co-Pilot Chat`.

Primær kilde: CellScaffold
`Documentation/PersonalCopilotV1_ChatAssistant.md` og
`PersonalCopilotConfigurationFactory.chatHubSkeleton()`.

Relatert protokollkilde: `../../CellProtocolDocuments/Book/19_Chat_Workbench_Central_Interface.md`
og `../../CellProtocolDocuments/Book/21_Contact_Endpoint_Cell.md`. Søskenrepoet
heter `CellProtocolDocuments`; jeg fant ikke et separat
`CellProtocolDocumentation`-repo under `HAVEN`.

## Last two app failures (inv12, 2026-10-13)

The host run on Binding `b075a2d4` reported two failures: external invitation
preparation returned no link, and failed shared sends returned no `ok` field.
The candidate changes below have not yet passed a new iOS app run.

- `GeneralCell.storedOwnerIdentity` returns a public identity snapshot without a
  vault. Calling `sign` on it fails with `noVaultIdentity`. Invitation preparation
  now obtains `verifiedRuntimeOwnerIdentity()` before signing the ticket and its
  optional publication. This API verifies the attached runtime owner's key; there
  is no default-vault lookup or UUID-only substitution. Existing access validation
  remains in place. Explicit later publication/revocation paths are outside this
  two-test repair and still require a separate signing audit.
- `InvitationCell` returns HavenValue's `status: "ok"`, not HTTP's `ok: true`.
  The Butler adapter now reads that actual status contract. Previously even a
  successfully prepared ticket would have been presented as blocked.
- Shared-chat local failures now include `ok: false`, preserving the existing
  blocked message/state response. Server responses without affirmative `ok` are
  normalized to false. The transport failure does not clear the draft or append a
  local message. Both the base cell with injected transport and the registered
  connected subclass use this handler.

Bounded local evidence: a standalone macOS probe compiled the original and
changed `Cells/InvitationCell.swift` with the real relation model/presenter and
invitation transport source. It used an ephemeral signed owner, a synthetic
Relations read/write fixture, and `autoPublish: false`. UI configuration and URL
opening were fatal-error stubs, neither invoked. The original prepare result was:

```json
{"status":"error","code":"signing_failed","sideEffect":false,"message":"Kunne ikke signere invitasjonen. Uten signatur sender jeg den ikke."}
```

The changed prepare returned `status: "ok"`, a successfully verified signed link,
`published: false`, and `requiresUserToPressSend: true`. Both probe executions
exited 0. The probe reused compiled macOS CellProtocol `b4100f5734bb0b3781600845a267e424e55c0989`;
the actual iOS app dependency is `79497e85ef2f3fb02db0d6df5b601c5f1bc76391`.
Both inspected sources expose the public-snapshot/runtime-owner boundary. This
probe is not a run of either Butler entry action or of the iOS XCTest suite.
The changed invitation sources also compiled and ran with `-default-isolation
MainActor -strict-concurrency=complete -swift-version 5` (the checked-in app
target selects Swift 5 language mode); both exits were 0. Existing warnings in
the included sources remain, so this is not a warning-free full-target build.

The existing app assertions are retained and strengthened with full synthetic
result diagnostics, both success statuses, issuer key/identity checks and blocked
send status. Run both named failing tests and the full existing inv10 script on
the host before marking them green. CoreSimulator access is denied in the agent
sandbox; Swift syntax parsing is not app compilation.

Reusable lesson: trace the actual response contract and signing identity at the
failing boundary before changing fixture isolation. A public identity descriptor
can verify a ticket but cannot sign one. Fixture separation remains useful for
duplicate-invite tests; it did not repair this failure. Learning routing was run;
this worktree document carries the findings because global capture/sync would
write primary checkouts, prohibited by the task.

## Shared native chat candidate (inv11, 2026-10-13)

The registered `PersonalChatHub` now uses `BindingConnectedPersonalChatHubCell`,
which installs `BindingNativeChatTransport` before actions or reads. The legacy
persisted coding name decodes to that connected type. A restored local message
projection is discarded. The isolated base class remains the local helper/contact
contract harness used by older unit tests; it is not the registered app sender.
There is no local fallback in the connected runtime when authentication or HTTP fails.

Both surfaces expose a separate human-message composer, shared thread selection,
explicit refresh/accept/decline and external identity approval/rejection/revocation.
Butler prompts still use `prompt.submit`. Reads of state/threads/messages and
explicit refresh obtain server state; push selection hydrates before selecting.
There is no background polling or websocket subscription in this candidate.

The transport uses the already completed person-link ceremony, not notification
registration as authority. It requires a saved active receipt with
`personEvidenceReference`, the matching private identity in its actual home vault,
and one unambiguous person/origin context. Renewals for that same context use the
latest saved receipt. A DeviceIngress-only receipt is insufficient; use the existing
person-link flow. No synthetic chat identity is created and no web password is needed
in the app. Server-side owner resolution still requires the existing person account
that approved the link. See the server candidate's `Documentation/NativeChatAuthentication.md`.

Known verification boundary: Binding build-for-testing stopped before compilation
with exit 74 (SwiftPM manifest diagnostics cache permission). Syntax parsing and
`git diff --check` pass. The 19 inv10 tests are retained; the six shared-chat tests
now inject a per-test server through the real cell transport boundary and compare
all participants' messages. `Inv11ChatTransportTests` adds wire shape, signing
resource, decode/runtime and offline failure tests. GUI and real two-device delivery
are not yet measured. Full host test commands and commit IDs belong in the inv11
handoff result; do not call this release-ready on syntax evidence.

Reusable lessons from this change:

- Independent UI-entry tests need independent recipients/InvitationCell fixtures.
  Reusing the same address tests duplicate-invitation denial on the second pass.
- Bind native proofs to the evidence reference and link ID as well as origin,
  method, path, body digest and one-shot server nonce. One key can have more than
  one approved person context; signing only the HTTP operation does not select it.
- Account migration must include persisted coding names; changing only the factory
  leaves existing decoded cells on their previous runtime behavior.
- A local contract suite and a shared transport suite prove different paths. Keep
  both explicit and use server-shaped JSON at the injected transport boundary.

The following inv10 audit is historical and describes the pre-inv11 implementation.

## Invitation/chat audit (inv10, 2026-10-13)

Source audit of `47cbd937` found two different paths: Butler and the embedded
`ComponentPaletteCatalog.embeddedChatCard` both use the identity-local
`BindingPersonalChatHubCell`. `prompt.submit` talks to Butler;
`sendComposedMessage` appends to local state. A local “accepted” status or a
signed ContactEndpoint receipt is **not proof of a shared conversation**.
`ContentView.openChatNotificationThread` selects a cached thread and does not
hydrate a remote conversation. The staging REST smoke tests exercise another
implementation, `/personal-copilot-v1/chat/api/`, and cannot certify these native
surfaces. The older `/i` InvitationCell link is an onboarding/contact ticket,
not evidence of membership in the collaboration API's shared thread.

The inv10 working change routes the visible invitation action through the
selected Butler relation, performs candidate-query lookups, invalidates stale
recipient endpoints and prepared links, exposes invitation controls/receipts in
the component, and makes surface accept/decline buttons require a real ticket.
Legacy direct empty `acceptInvite` calls remain for the existing local contract;
new user surfaces pass `requireTicket: true`. No shared message transport or
remote thread hydration has been added. `chat.started` is no longer recorded
when only an undelivered bootstrap draft was produced.

Verification status: syntax parse and diff checks passed; build and XCTest
attempts stopped at SwiftPM manifest-cache permission denial (exit 74), before
compilation/tests. The new `Inv10InvitationChatTests` cover the local fixes.
`Inv10ChatEndToEndTests` are ordinary, unskipped acceptance tests for two/three
participants and push before the first local message; source inspection predicts
failures until shared transport is wired. The contact fixtures use distinct
signing vaults/UUIDs and explicit owner grants with access validation enabled;
they do not prove first-contact grant acquisition, bridge delivery or UI rendering.
The new embedded layout still requires native GUI verification.

For future audits: derive actions from the actual skeleton, use separate
participant identities, assert messages at every participant, and test push
before any local send. Do not replace these checks with local counters or a
server-only smoke run. Never run default InvitationCell preparation in a
no-production test: configure `autoPublish: false` and a synthetic/staging landing
base before preparing any ticket.

## Contract

- Default Porthole-flate i Personal Co-Pilot mode er `Co-Pilot Chat`.
- Chat-hub endpoint i Binding er `cell:///PersonalChatHub`.
- Binding registrerer `PersonalChatHub`, `AppleIntelligence`, `LocalLLM` og
  `ContactEndpoint` som `identityUnique` celler. Dette er cell-scope, ikke en
  global AI-provider eller global endpoint-registry.
- `assistant.analyzeDraft` leser bare aktivt chat-utkast, Perspective-summary og
  descriptors for celler/tools requesteren har tilgang til.
- `ui.openSuggestedHelper` og `ui.openComponentSurface` apner bare UI-flater og
  returnerer `sideEffect=false`.
- `assistant.acceptSuggestion` og de konkrete helper-actionene er de eneste
  stedene som oppretter invite, poll, workbench-module, capability request eller
  agent-review draft.
- `ui.setCapabilityDiscoveryEnabled` maa vaere aktivert for at chatten skal
  foreslaa `capability_request`; `capabilityRequest.submit` er fortsatt et
  eksplisitt innsendingstrykk.
- `sendComposedMessage` er sperret til invite-only status er akseptert, og
  blokkering stopper videre sending. `meetingBridge` er bare placeholder-metadata
  (`v1RenderMode=placeholder`) og ber ikke om kamera/mikrofon.
- `entityExtension.scan` og ContactEndpoint resource matching er sideeffektfri
  discovery. Selve `contact.request` krever eksplisitt signert foresporsel.
- `help.openContextual` er Binding-shellens sideeffektfrie hjelpeseam. Den kan
  aapne Co-Pilot Chat med aktiv GUI-flate, editor-modus, bruker-/scope-summary
  og kilde/RAG-policy som kontekst, men spoer ikke RAG eller provider foer
  brukeren klikker eksplisitt.
- `entityExtension` bruker CellScaffold sin snapshot-shape:
  `schema=haven.personal.entity-extension.v1`, `extensions`,
  `extensionCount`, `counts`, `assistantProviders`,
  `providerRecommendation`, `privacyBoundary` og
  `sideEffectsRequireClick`.
- Direkte Co-Pilot keypaths `assistantState.intentCandidates`,
  `assistantState.priorityIntent`, `assistantState.assistantProviders`,
  `assistantState.providerRecommendation` og `assistantState.whySummary`
  mappes til chat-cellens interne `assistant`-state.
- Binding normaliserer resource matches til CellScaffold-lignende åpne-kontrakt:
  `kindLabel`, `openLabel`, `openHint`, `openActionKeypath`, `openPayload`,
  `riskLevel`, `requiresUserApproval=true` og
  `sideEffectUntilExplicitRequest=false`. Standard UI viser menneskelige felt,
  ikke rå action-keypaths.
- `assistant.analyzeDraft` og composer-fallbacken produserer
  `groundedActionPlan`, `groundingVerification`, `groundingDryRun`,
  `groundingSchemas` og `groundingAlternatives`. Disse er sideeffektfrie
  forhåndsvisninger av hva neste eksplisitte brukerklikk kan gjøre.
- `ui.openSuggestedHelper` restager hvis composer-draften er endret siden siste
  analyse. Dette hindrer stale helper-state, for eksempel at en gammel
  `invite`-suggestion forblir aktiv når ny prompt matcher Mermaid, Graph eller
  Arendalsuka resource-flate.
- Drag/drop-paritet bruker cell-keypath `drop.receive` (skeleton alias
  `chatHub.drop.receive`). Den fyller kun `inviteDraft` og `drop`, returnerer
  `sideEffect=invite_draft_only`, og sender ikke invitasjon.
- Tale-til-tekst er Binding-lokal diktering inn i chat-komponisten:
  `voice.requestPermission`, `voice.startListening`, `voice.stopListening`,
  `voice.acceptTranscript`, `voice.acceptTranscriptAndAnalyze` og
  `voice.clearTranscript`. Mikrofon/speech kan bare startes etter eksplisitt
  brukertrykk, transcript blir lokal draft, `acceptTranscriptAndAnalyze`
  kjører fortsatt sideeffektfri analyse, og ingen voice-flow sender melding
  eller trigger wake phrase/autosend i denne skiven.

## Provider Routing

Binding matcher CellScaffold-policyen:

1. Deterministiske lokale chat-regler naar intenten er sikker.
2. Apple Intelligence naar `ai.state` er synlig i requesterens scope og
   availability er klar.
3. Lokal liten LLM via `cell:///LocalLLM` naar Apple Intelligence mangler eller
   ikke er god nok.
4. Dedikert RAG bare naar utkastet matcher en tilgjengelig RAG-case.
5. API/subscription-provider bare naar owner/user har deklarert den i chat-scope.
6. Agent bridge bare som review/signert intent, aldri direkte script-kjoring.

ContactEndpoint-ruten er en resource/provider-recommendation, ikke en global
meny. Naar utkastet handler om aa sende en melding eller foresporsel til en
annen entitets endpoint-cell, returnerer Binding `resourceMatches.kind =
contact_endpoint` og anbefaler `cell:///ContactEndpoint` med action
`contact.request`. Chatten sender ikke requesten under analyze/open; den kan
bare apne en hjelperflate eller stage review.

Provider state eksponeres gjennom cellene:

- `cell:///AppleIntelligence` GET `ai.state`
- `cell:///LocalLLM` GET `state`
- `cell:///ContactEndpoint` GET `state`, SET `publishEndpoint`,
  SET `contact.request`, SET `ticket.resolve`, SET `ticket.respond`
- `cell:///PersonalChatHub` SET `help.openContextual` for aa stage
  bruker-/GUI-kontekst i chatten og preutfylle docs/RAG-sporsmal uten
  sideeffekt.

Apple provider bruker Foundation Models availability-check foer generering. Naar
frameworket eller modellen ikke er tilgjengelig, returnerer state
`status=unavailable` med grunn og faller tilbake til lokale regler.

## Perspective

Foer provider-kall bygger Binding et context-pack med:

- aktiv chat-draft
- `cell:///Perspective/activePurpose`
- `cell:///Perspective/perspective.state`
- `perspective.query.activePurposes` med `referenceMode = "both"`
- `perspective.query.interestsFromActivePurposes`
- granted descriptors for celler/tools i scope

Prompten matches med direct purpose hit over interest hit over lexical fallback.
Utilgjengelige celler tas ikke med i context-pack eller UI.

Binding bruker samme mentale modell som CellScaffold sin `chatPurposeContext`:
`activePurpose` og `perspective.state` blir normalisert til et lite
`purposeRefs`/`interests`/`weights`-context. Dette contextet kan booste
tvetydige oppfoelgingsprompt som "legg dette inn" naar Perspective allerede
peker paa prosjekt, todo, ide eller graf/vault. Contextet gir ikke nye grants,
leser ikke skjulte celler og muterer ikke Perspective under analyze/open.

Kvalitetsregel for nye Co-Pilot-endringer: legg til en foer/etter-test der en
tvetydig prompt uten Perspective er `low_confidence`, men samme prompt med
aktivt relevant Perspective-formaal gir riktig hjelper og fortsatt
`sideEffect=false`.

## Local LLM Strategy For iPhone/iPad

`BindingLocalLLMCell` er en kontrakt og en trygg fallback, ikke en hardkodet tung
modell. iPhone/iPad-strategien er:

- Runtime: embedded llama.cpp/ggml-kompatibel runtime eller annen lokal
  inference som kan pakkes og profilers separat.
- Modellstørrelse: start med en liten quantized modell. Stor modell skal gjennom
  review for nedlastingsstorrelse, RAM, batteri, termikk og UX-latens.
- Lisens: modellen maa ha tydelig kommersiell/App Store-kompatibel lisens, og
  lisensnotat maa ligge ved runtime-bundlingen.
- App Store-risiko: ikke last ned skjulte store modeller, ikke kjør bakgrunns-AI
  uten brukerinitiert handling, og ikke presenter lokal inference som Apple
  Intelligence.
- Fallback: naar modell ikke er installert eller runtime ikke er frisk, state
  skal vaere `unavailable`/`not_configured`, og chat skal bruke lokale regler
  eller Apple Intelligence hvis tilgjengelig.

## Test Matrix

Binding speiler CellScaffold-fixturen:

- `Tests/fixtures/personal_chat_prompt_evaluation.json`

Runner:

- `BindingChatPromptEvaluationRunner`

Dekning:

- deterministic/local rules
- `binding.apple-intelligence`
- `binding.local-llm`

Smoke:

- Start `Co-Pilot Chat` i Porthole.
- Skriv prompt.
- Kjor `assistant.analyzeDraft`.
- Apne helper via `ui.openSuggestedHelper`.
- Verifiser at analyze/open-helper ikke endrer thread-, poll- eller
  workbench-module-tellere.
- Verifiser at `groundingVerification.allowed=true` bare når target action,
  synlig ressurs/grant og cell-scoped provider-policy er oppfylt, og at
  `groundingDryRun.wouldMutateEntity=false` under analyze/open.
- Verifiser stale-case: gammel invite-helper + ny resource-prompt skal restage
  til riktig helper/resource og fjerne upinnet invite fra aktiv helper-liste.
- Kjor `entityExtension.scan` for endpoint-prompt og verifiser
  `contact_endpoint` uten sideeffekt, samt CellScaffold-lignende
  `entityExtension.extensions`/`counts`.
- Les direkte `assistantState.*` keypaths etter analyse.
- Kjor `drop.receive` med public-safe person payload og verifiser invite draft
  uten thread/invite-sideeffekt.
- Kjor `help.openContextual` fra en ikke-chat-flate og verifiser at composer,
  `help.context` og `docsRAG.query` faar aktiv GUI-kontekst uten aa opprette
  thread, poll eller workbench-modul.
- Kjor `voice.acceptTranscriptAndAnalyze` med test-transcript og verifiser at
  composer fylles, analyse er sideeffektfri, og ingen melding sendes.
- Publiser lokal `ContactEndpoint`, send signert `contact.request`, verifiser
  replay-reject, `ticket.resolve` og `ticket.respond`.

Siste lokale verifikasjon:

```bash
Scripts/test_binding.sh CODE_SIGNING_ALLOWED=NO \
  -only-testing:BindingTests/ChatWorkbenchParityTests
```

Resultat 2026-07-07: 37 `ChatWorkbenchParityTests` passerte, inkludert
resource open-payload, grounded verification/dry-run, Perspective-quality
matrix, stale invite -> Mermaid/resource restaging, helper-open sideeffektfrihet
og CellScaffold-fixture provider-evaluering.
