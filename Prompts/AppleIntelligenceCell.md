# AppleIntelligenceCell – Intercepts og Flow-dokumentasjon

Denne siden beskriver hvordan AppleIntelligenceCell eksponerer funksjonalitet via Meddle-intercepts (get/set) og hva som publiseres på Flow. Dokumentet er oppdatert i tråd med implementasjonen der selve cellen ikke bruker Meddle internt for å manipulere egen tilstand; intercepts fungerer som et eksternt API som kaller interne metoder på assistenten.

## Oversikt
- Basetype: `GeneralCell`
- All ekstern interaksjon skjer via Meddle-intercepts (get/set)
- Intern logikk kaller direkte Apple Intelligence-API (AIAssistant) og bruker ikke `Meddle.get/set`
- Publisering skjer via `pushFlowElement` til relevante topics

## Co-Pilot context-policy
Når AppleIntelligenceCell brukes fra Co-Pilot Chat, skal modellen bare få et
minimalt context-pack fra chat-scope:

- aktiv chat-draft
- kompakt Perspective-summary fra `cell:///Perspective/activePurpose` og
  `cell:///Perspective/perspective.state`
- granted cell/tool descriptors som requesteren faktisk kan se

Perspective er et kvalitetssignal for intent og ranking, ikke en capability i
seg selv. Det kan forklare og booste et forslag for tvetydige oppfoelgingsprompt
som "legg dette inn", men det skal ikke gi tilgang til andre drafts, vault,
native kontakter, kalender, mikrofon, kamera eller andre traader. `analyze` og
`open helper` maa forbli sideeffektfrie; enhver effektfull handling maa skje
etter eksplisitt brukerbekreftelse.

## State (AI-subtree)
Følgende nøkler eksisterer logisk under `ai.*` (tilstand forvaltes av AIAssistant):
- `ai.status` – `"idle" | "discovering" | "ready" | "error"`
- `ai.currentPurposeRef` – `String?`
- `ai.purposeClusterRefs` – `[String]?`
- `ai.candidates` – `[CellConfiguration]` (serialisert som `ValueType.list(.cellConfiguration)`)
- `ai.outbox` – Liste med meldinger (`ValueType.object`) som kan dreneres av en egen Emit-implementasjon

Snapshot av gjeldende state kan hentes via GET-interceptet `ai.state` (se under).

## Intercepts
Nedenfor er alle get/set-intercepts AppleIntelligenceCell registrerer, med input, returverdi og Flow-effekter.

### GET: `ai.state`
- Beskrivelse: Returnerer et snapshot av AI-state.
- Input: Ingen (kun keypath)
- Returnerer: `ValueType.object` med felter som status, currentPurposeRef, purposeClusterRefs, candidates.
- Flow: Ingen direkte push (du kan selv lytte på andre topics eller drene `ai.outbox`).

Eksempel retur (forenklet):
```json
{
  "status": "ready",
  "currentPurposeRef": "purpose://running",
  "purposeClusterRefs": ["purpose://running"],
  "candidates": [ /* .cellConfiguration ... */ ]
}
