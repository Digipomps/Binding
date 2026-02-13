# Architecture

Dette dokumentet skisserer hovedprinsippene for arkitekturen i prosjektet og er den autoritative lokasjonen for arkitekturregler (flyttet fra rot til Prompts/Architecture.md).

## Lagdeling
- Presentasjon (SwiftUI-visninger): Ren visning og interaksjon. Minimal forretningslogikk.
- ViewModel(er): Eierskap til tilstand, koordinering av dataflyt, asynkrone kall og sideeffekter.
- Domenemodeller og tjenester: Rent, testbart domene; tjenester for IO, nettverk, persistens osv.

## Mønstre
- Data inn – hendelser ut: Visninger mottar data via bindings/observables og sender hendelser oppover via closures eller observables.
- Preferer dependency injection (init/Environment) fremfor singletons, men tillat singletons for delte systemtjenester når hensiktsmessig.
- Unngå tett kobling mot tredjepartskomponenter i visninger; kapsle i adaptere hvor mulig.

## UI-retningslinjer
- Behold visuell konsistens (spacing, typografi, animasjoner). Dokumentér avvik.
- Bruk `withAnimation` for tilstandsoppdateringer som påvirker layout/overganger.
- Sørg for tilgjengelighet (VoiceOver, Dynamic Type, kontrast).

## Dokumentasjon
- Hver nye komponent bør ha en kort forklaring i `Prompts/`, og koden bør linke til relevant dokumentasjon.
- Se også `Prompts/EdgeMenusOverlay.md` for et eksempel på komponentdokumentasjon og regler.

## Access Control Policy
This project enforces access control through CellProtocol, with state access mediated exclusively by the Meddle interface:
- All state access and mutation must go through `Meddle.get/set(keypath:value:requester:)`.
- Authorization is enforced per keypath by the cell itself.

## Agreement Evolution Policy (authoritative)
- Do not model authorization as static role labels (for example, `level2`). Authorization is capability-based and derived only from grants issued to a concrete `Identity`.
- When editing an agreement template, support explicit rollout mode:
  - apply to new connections only, or
  - apply and re-evaluate currently connected identities.
- Re-evaluation may revoke existing access and force a new `signContract` flow, but only if this does not violate active contract conditions/terms.
- `agreementTemplate.access.manage` is delegable, but delegation remains capability-based and identity-scoped.
- Agreement workflows should support signatures from all involved parties and retrieval for storage in each party-controlled entity context.
- `Entity` means digital presence/resources/functionality controlled by a person, not the person directly.
- If a user marks a contract change as non-compliant, emit an explicit event and apply configured policy (manual/escalation/automatic handling) instead of silently overriding state.
- Any proposed implementation that could conflict with CellProtocol concepts in `Prompts/` or `CellProtocolDocuments/` must be discussed with the user before code changes are made.

## Interceptor policy (authoritative)
We only use `addInterceptForGet` and `addInterceptForSet` to expose behavior and state externally. Do not use `registerAction`/`registerSetter` or ad‑hoc side channels.

Rationale:
- Keeps the external interface minimal and consistent for all Cells and CellConfigurations.
- Ensures that access control is enforced inside the cell itself.

Guidelines:
- GET interceptors: implement computed reads or snapshots (e.g., `ai.state`).
- SET interceptors: implement commands/actions with structured `ValueType` payloads (e.g., `ai.send`, `ai.sendPrompt`, `ai.discover`).
- Events/Intents: publish via `Emit.flow` as `FlowElement` with `.object` payloads; consumers listen and react.

## Perspective Matching Policy
When a `GeneralCell` subclass provides Perspective-aware matching (`Purpose` and `Interest`):

- Use explicit, local weights only; never infer behavior from hidden profiling.
- Expose parameterized matching queries through `SET` intercepts (not ad-hoc APIs).
- Return enough data for downstream matching and ranking:
  - direct purpose hits with source/target purpose weights
  - via-interest hits with source/target purpose weights and source/target interest weights
- Keep scoring deterministic and transparent so identical inputs produce identical ordering.

Canonical shared contract lives in:
- `CellProtocolDocuments/Book/14_Perspective_Runtime_Matching.md`
- `CellProtocolDocuments/Book/13_Agent_Instructions.md`

Use `Binding` docs only for app-specific integration details.

## Moduler og ansvar
- CellBase: Plattform-agnostisk kjerne (protokoller som CellProtocol, verdityper som ValueType, domenemodeller som Perspective og CellConfiguration, og annen logikk uten OS-avhengighet).
- CellApple: OS-spesifikke integrasjoner og visninger (SwiftUI, UI-komponenter, EdgeMenus, SkeletonView, Apple Intelligence-komponenter ligger her under `CellApple/Intelligence`).
- CellVapor: Server-/web-relatert funksjonalitet (Vapor-integrasjoner og tjenester).

Apple Intelligence-komponenter som krever OS-funksjonalitet (f.eks. visninger, runtime-integrasjoner, Flow-abonnement i UI) ligger i `CellApple/Intelligence`. Plattform-agnostisk logikk kan ekstrakteres til CellBase ved behov.

## Prosjektstrukturkrav
Prosjekter som importerer CellProtocol skal inneholde:
- `Documentation/`: Overordnet arkitektur og utviklerdokumentasjon.
- `Prompts/`: Operativ dokumentasjon, system-/LLM-prompter, komponentbeskrivelser (for eksempel `EdgeMenusOverlay.md`, `AppleIntelligenceCell.md`, `ExplainToAnotherLLM.md`).

## Scope og relaterte prosjekter
- Binding: Fokus-appen i dette repoet.
- CellProtocol: Delt rammeverk som brukes på tvers av prosjekter.
- Andre prosjekter i økosystemet: `CellScaffold`, `CellUtility`, `HAVEN_MVP`. Disse følger de samme arkitekturprinsippene og bør ha egne promper i sine respektive `Prompts/`-mapper for å beskrive rolle, ansvar og integrasjonspunkter.

## Apple Intelligence – plassering og flyt (kort)
- State kun via `Meddle.get/set` (med `requester: Identity`).
- Oppdateringer og intent meldinger sendes som `FlowElement` (Emit/flow) med `.object`-payload.
- Porthole (eller andre konsumenter) henter state ved behov via `get` og reagerer på `FlowElement`-oppdateringer.
- Utforskning (explore) bruker standardiserte nøkkelnavn over Flow (se `Prompts/AppleIntelligenceCell.md`).
