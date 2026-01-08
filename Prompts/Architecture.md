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

## Interceptor policy (authoritative)
We only use `addInterceptForGet` and `addInterceptForSet` to expose behavior and state externally. Do not use `registerAction`/`registerSetter` or ad‑hoc side channels.

Rationale:
- Keeps the external interface minimal and consistent for all Cells and CellConfigurations.
- Ensures that access control is enforced inside the cell itself.

Guidelines:
- GET interceptors: implement computed reads or snapshots (e.g., `ai.state`).
- SET interceptors: implement commands/actions with structured `ValueType` payloads (e.g., `ai.send`, `ai.sendPrompt`, `ai.discover`).
- Events/Intents: publish via `Emit.flow` as `FlowElement` with `.object` payloads; consumers listen and react.

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

