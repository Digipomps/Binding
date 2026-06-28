# Chat Workbench Binding Parity

Dette notatet er Binding sin ground-truth for paritet med CellScaffold
`PersonalChatHubCell` / `Co-Pilot Chat`.

Primær kilde: CellScaffold
`Documentation/PersonalCopilotV1_ChatAssistant.md` og
`PersonalCopilotConfigurationFactory.chatHubSkeleton()`.

Relatert protokollkilde: `../CellProtocolDocuments/Book/19_Chat_Workbench_Central_Interface.md`
og `../CellProtocolDocuments/Book/21_Contact_Endpoint_Cell.md`. Den lokale
repoen heter `CellProtocolDocuments`; jeg fant ikke et separat
`CellProtocolDocumentation`-repo under `HAVEN`.

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
- `entityExtension` bruker CellScaffold sin snapshot-shape:
  `schema=haven.personal.entity-extension.v1`, `extensions`,
  `extensionCount`, `counts`, `assistantProviders`,
  `providerRecommendation`, `privacyBoundary` og
  `sideEffectsRequireClick`.
- Direkte Co-Pilot keypaths `assistantState.intentCandidates`,
  `assistantState.priorityIntent`, `assistantState.assistantProviders`,
  `assistantState.providerRecommendation` og `assistantState.whySummary`
  mappes til chat-cellens interne `assistant`-state.
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
- Kjor `entityExtension.scan` for endpoint-prompt og verifiser
  `contact_endpoint` uten sideeffekt, samt CellScaffold-lignende
  `entityExtension.extensions`/`counts`.
- Les direkte `assistantState.*` keypaths etter analyse.
- Kjor `drop.receive` med public-safe person payload og verifiser invite draft
  uten thread/invite-sideeffekt.
- Kjor `voice.acceptTranscriptAndAnalyze` med test-transcript og verifiser at
  composer fylles, analyse er sideeffektfri, og ingen melding sendes.
- Publiser lokal `ContactEndpoint`, send signert `contact.request`, verifiser
  replay-reject, `ticket.resolve` og `ticket.respond`.

Siste lokale verifikasjon:

```bash
xcodebuild test -project Binding.xcodeproj -scheme Binding \
  -only-testing:BindingTests/ChatWorkbenchParityTests
```

Resultat 2026-05-15: 12 ChatWorkbench-paritytester passerte. I tillegg
passerte 5 `AgentConversationClientTests`, inkludert test av `postPrompt` mot en
annen entitets `AgentConversationInbox`-endpoint.
