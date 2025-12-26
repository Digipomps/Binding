// Apple Intelligence Cell

// Apple Intelligence-cellen er en GeneralCell som opererer “på innsiden” av brukerens entitet og hjelper brukeren å konfigurere porthole (lerretet) for å oppnå nåværende formål. Cellen bruker Meddle-grensesnittet til å manipulere intern state og publiserer oppdateringer via Flow til celler som abonnerer. Den kan be andre celler om `CellConfiguration`-kandidater for et formål eller en formålsklynge, rangere forslag, og anbefale eller anvende konfigurasjoner.

// Mål
// - Identifisere brukerens primære formål (via `Perspective`) og hjelpe med å oppnå det.
// - Oppdage relevante `CellConfiguration`s ved å be andre celler om forslag (for formål eller formålstre).
// - Rangere og anbefale konfigurasjoner, samt støtte automatisk komposisjon ved manglende treff.
// - Kommunisere utelukkende via CellProtocol-grensesnittene (Meddle, Flow/Emit, Absorb/Explore), uten private snarveier.

// Arkitektur og ansvar
// - Basistype: `GeneralCell` (CellProtocol/Sources/CellBase/Cells/GeneralCell)
// - State endres kun via `Meddle`:
//   - `get(keypath:requester:)` / `set(keypath:value:requester:)`
// - Oppdateringer publiseres via `Flow` (fra `Emit.flow`) til abonnerende celler.
// - Forespørsler om konfigurasjoner sendes via et standard “explore”-grensesnitt (se under).
// - Inngående svar fra andre celler konsumeres (Absorb) og skrives inn i intern state via Meddle.

// State-skjema (AI-subtree i GeneralCell via Meddle)
// Nøkler under roten `"ai"`:

// - `ai.status`: `.string` i { `idle`, `discovering`, `ready`, `error` }
// - `ai.currentPurposeRef`: `.string` (referanse til primært formål)
// - `ai.purposeClusterRefs`: `.list(.string)` (formålsklynge/tre)
// - `ai.candidates`: `.list(.cellConfiguration)` (foreslåtte konfigurasjoner)
// - `ai.scoringWeights`: `.object(String -> .float)` (valgfritt, vekter for rangering)
// - `ai.lastDiscoveryAt`: `.string` (ISO8601, valgfritt)
// - `ai.lastError`: `.string` (valgfritt)

// Eksempel Meddle-operasjoner:
// - set ["ai","status"] = .string("discovering")
// - set ["ai","currentPurposeRef"] = .string("purpose://running")
// - set ["ai","purposeClusterRefs"] = .list([.string("purpose://running"), .string("purpose://fitness")])
// - set ["ai","candidates"] = .list([.cellConfiguration(...), ...])

// Flow-topics
// - `ai.assistant.state`
//   - Snapshot av AI-state ved viktige endringer (status, purposeRef, cluster, candidates)
//   - Payload: `ValueType.object` med relevante felter
// - `ai.assistant.recommendations`
//   - Publiseres når kandidater er oppdatert/rangert
//   - Payload: `ValueType.object` med minst `{ candidates: .list(.cellConfiguration), currentPurposeRef: .string? }`
// - `ai.intent.requestConfigurations`
//   - Forespørsel om konfigurasjoner basert på formål/cluster
//   - Payload:
//     - `{ currentPurposeRef: .string }` eller `{ purposeClusterRefs: .list(.string) }`
//     - Valgfri `context: .object` (interests, entities, constraints, capabilities)
// - `ai.intent.response.configurations`
//   - Forventet respons med konfigurasjoner fra andre celler
//   - Payload:
//     - `.list(.cellConfiguration)` eller
//     - `{ configurations: .list(.cellConfiguration), meta: .object ... }`

// “Explore”-grensesnitt (forslag)
// Standardiserte nøkler/typer for forespørsel og svar, slik at celler kan oppdage og dele konfigurasjoner uten tett kobling.

// - Request (topic: `explore.request`, payload: `.object`):
//   - `purposeRef: .string?`
//   - `purposeClusterRefs: .list(.string)?`
//   - `context: .object?` med nøkler som:
//     - `identityRef: .string?`
//     - `interests: .list(.string)?`
//     - `entities: .list(.string)?`
//     - `constraints: .object?`
//     - `capabilities: .list(.string)?`
//   - `correlationId: .string?` (valgfri korrelasjon)

// - Response (topic: `explore.response`, payload: `.object`):
//   - `configurations: .list(.cellConfiguration)` [påkrevd]
//   - `meta: .object?` (for eksempel):
//     - `score: .float?`
//     - `items: .list(.object)?` med `{ ref: .string?, score: .float?, tags: .list(.string)?, provenance: .string? }`
//   - `purposeRef` / `purposeClusterRefs`: echo av forespørselen (valgfritt)
//   - `correlationId: .string?`

// - Announce (topic: `explore.announce`, payload: `.object`):
//   - `capabilities: .list(.string)` (f.eks. `["providesConfigurations","composesSkeletons"]`)
//   - `supportedPurposes: .list(.string)?`
//   - `constraints: .object?`

// AI-cellen bruker `explore.request` for å be om kandidater, lytter på `explore.response`, og oppdaterer egen state via Meddle.

// Perspektiv-integrasjon
// - `Perspective` inneholder formål, interesser og entiteter (se CellBase/PurposeAndInterest).
// - AI-cellen kan:
//   - Be om primært formål via `getPrimaryPurpose()` når `ai.currentPurposeRef` mangler.
//   - Bygge en enkel formålsklynge når `ai.purposeClusterRefs` mangler (f.eks. `[currentPurposeRef]`).
//   - Rangere kandidater mot formålsnavn/interesser (enkle heuristikker kan utvides).

// Tilgangskontroll (Meddle) – kort
// - All intern state aksesseres via `Meddle.get/set` med `requester: Identity`.
// - Autorisasjon avgjøres per keypath (se “Access Control Policy” i Architecture.md).
// - Eksempelpolicy:
//   - Owner: lese/skriv `ai.*`
//   - Gruppe: lese `ai.status`, `ai.currentPurposeRef`, `ai.purposeClusterRefs`
//   - Offentlig: lese `ai.status`
//   - Skriv til `ai.candidates` og `ai.status`: kun owner/system

// Bruk i appen
// - Opprett AI-cellen (GeneralCell) og seed state:
//   - Sett `ai.status = "idle"`, `ai.candidates = []`, og eventuelt `ai.currentPurposeRef`.
// - Presenter en AppleIntelligenceCellView (CellApple) som:
//   - Viser gjeldende formål
//   - Knapper for “Discover” (sender request, oppdaterer status)
//   - Viser anbefalinger (draggable `CellConfiguration`s, “Apply”)
//   - Abonnerer på `ai.intent.response.configurations` og oppdaterer state via Meddle
// - Når bruker velger en anbefaling:
//   - Kall `viewModel.load(configuration:)` for å laste inn i porthole/canvas.

// Videre arbeid
// - Forbedre rangering (score basert på interesser/entiteter og konfig-metadata).
// - Automatisk komposisjon av skeleton når enkeltkonfig ikke dekker formålet.
// - Støtte for korrelasjon og tidsfrister i explore-forespørsler.
// - Utvidet logging/auditing for Meddle og Flow.

