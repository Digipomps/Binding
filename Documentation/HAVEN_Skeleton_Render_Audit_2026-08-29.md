# HAVEN — full skeleton-render-audit mot staging og prod

Dato: 29. august 2026
Kjørt fra: `Binding/_audit-skeleton-render-20260828/run_surface_audit.sh`
(macOS arm64, unsigned, `BindingTests/RemoteSurfaceRenderAuditXCTest`)
Rådata: `_audit-skeleton-render-20260828/reports/surface-audit-20260829T145220Z.{json,md}`

---

## Kortversjonen

**Renderingen er ikke problemet. Transporten finnes ikke.**

Hver eneste `cell://<vert>/<Celle>`-referanse i HAVEN feiler mot **både** staging og
produksjon, fordi websocket-ruten appen kobler seg til ble fjernet fra CellScaffold
13. juli. 40 av 40 celler og 37 av 37 lastestier er røde på begge verter.

Der serveren faktisk svarer — de seks HTTP-publiserte CellConfigurationene — rendrer
skeletonet raskt og korrekt: 150–340 ms totalt, første innhold på ~65 ms, null
`Unsupported`-elementer. Renderen holder mål.

Vi har heller ingen timeouts i praksis. Feilen kommer på 80–210 ms. Det er ikke
tregt — det er dødt.

---

## 1. Hovedfunnet: `/bridgehead` finnes ikke lenger

```
wss://staging.haven.digipomps.org/bridgehead/ConfigurationCatalog/<uuid>  →  HTTP 404
wss://haven.digipomps.org/bridgehead/ConfigurationCatalog/<uuid>          →  HTTP 404
```

404-en kommer fra Vapor (`{"error":true,"reason":"Not Found"}`), ikke fra nginx.
Ruten er altså ikke feilkonfigurert — den er ikke registrert.

Appen ser dette som `NSURLErrorDomain -1011 "There was a bad response from the
server."`, fordi `URLSession` rapporterer enhver mislykket websocket-handshake slik.
Derfor har feilen sett ut som en serverfeil i månedsvis.

**Årsak, i git:** commit `14b50a51` (2026-07-13, «Enforce vault-bound access across
scaffold sessions») fjernet

```swift
let bridgehead = routes.grouped("bridgehead")
bridgehead.webSocket(":pubId", ":bridgeId") { ... }
```

fra `VaporBridgehead.boot`, med begrunnelsen i koden: *«The legacy bridgehead had no
authenticated session/channel binding.»* Det var en bevisst sikkerhetsherding. Men
ingen erstattet ruten for HAVEN-klienten, og
`RemoteEndpointAccessSupport.secureRemoteRoute` peker fortsatt på
`websocketEndpoint: "bridgehead"`.

De eneste inbound-broene som finnes i dag:

| Rute | Hvor | Hvem slipper inn |
|---|---|---|
| `/<endpoint>/:cellName/:bridgeID` | `AdminScaffoldBridgeRoutes` | kun de 13 `Admin*`-cellene, signert handshake, egen vert |
| `/v1/resolver/native-porthole/:pubId/:bridgeId` | `VaporSproutResolver` | krever Sprout porthole-access-kontrakt |
| `/browserhead/wsce/:sessionId` | `VaporBrowserhead` | innlogget nettsesjon |

Ingen av dem er en drop-in for `cell://<vert>/<Celle>`.

**Dette er en beslutning, ikke en bug å fikse i Binding.** Valgene er: (a) gi HAVEN
en autentisert generell bro på hovedscaffoldet, (b) flytte appen over på
`native-porthole` med kontraktflyt, eller (c) erklære at appen ikke lenger snakker
med hovedscaffoldet over celle-broen. Jeg har ikke rørt noe her.

### Følgefunn: appens diagnose peker feil vei

`ContentView.probeFailureMessage` oversetter -1011 til
«Staging svarte med ugyldig websocket-respons for X. **Sjekk bridgehead/nginx.**»
Meldingen er både misvisende (ruten finnes ikke — det er ikke nginx) og lekker
interne begreper ut i brukerflaten. Ikke endret; det er din tekst.

---

## 2. Serveren svarer 500 på egne ruter — begge verter

| Rute | Status | Grunn |
|---|---|---|
| `/personal-copilot-v1/api/catalog` (+`/allowed`, `/unavailable`) | **500** | «Failed to resolve Personal Co-Pilot requester.» |
| `/skeleton-parity/<alle 10>/api/configuration` og `/api/state` | **500** | «Failed to resolve skeleton parity requester.» |

Begge stammer fra samme sted: `vault.identity(for:, makeNewIfNotFound: true)`
returnerer `nil`. Identitetsvaulten lager ikke lenger nye identiteter on demand
etter herdingen. Rutene som *virker* er nettopp de som bruker en egen
`EphemeralIdentityVault` (`readAnonymousConfiguration`).

Konsekvens: hele skeleton-parity-fixturesuiten — vårt eneste renderer-referansesett
mot server — er utilgjengelig på begge verter. `/skeleton-parity/api/catalog`
lister fortsatt alle 10 fixtures, så katalogen lover noe rutene ikke leverer.

---

## 3. Der serveren svarer: renderingen er god

Seks CellConfigurations hentes over HTTP og rendres med appens egen renderer.
Identisk på staging og prod (samme bytes).

| Flate | Hent | Dekode | Render | Første innhold | Subviews | Verdikt |
|---|---:|---:|---:|---:|---:|---|
| Publish Public Profile | 49 ms | 0 ms | 221 ms | 70 ms | 25 | 🟢 |
| Public Profile Directory | 46 ms | 0 ms | 155 ms | 63 ms | 16 | 🟢 |
| Meeting Intent | 47 ms | 0 ms | 159 ms | 66 ms | 18 | 🟢 |
| Personal Co-Pilot Catalog | 85 ms | 0 ms | 338 ms | 68 ms | 8 | 🟢 |
| Matches | 138 ms | 0 ms | 154 ms | 64 ms | 17 | 🟡 valideringsfeil |
| Co-Pilot Chat | 329 ms | 39 ms | 348 ms | — | — | 🔴 `cellNotFound` |

Null `Unsupported`-elementer. Ingen «Innholdet er ikke tilgjengelig akkurat nå.»
Ingen timeouts.

To reelle feil i det serveren publiserer:

- **Matches** binder `profile.id` uten at det finnes en `profile`-referanse i
  konfigurasjonen. Valideringsfeil i skeletonet som publiseres.
- **Co-Pilot Chat** refererer `cell:///AgreementWorkbench`, som bor i CellScaffold og
  ikke finnes i appen → `cellNotFound`, flaten rendrer ikke i det hele tatt.
  Serveren publiserer altså en flate klienten prinsipielt ikke kan vise.
- **Co-Pilot Chat** er dessuten 603 KB pretty-printet JSON (136 KB kompakt).
  Det er 100× de andre flatene og verdt en kompakt-serialisering.

---

## 4. Lokalt: 79 flater gjennom appens egen laste- og rendersti

Dette er det brukeren faktisk ser i dag, siden fjernstien er død.
Alle `cell://staging/...`-endepunkter er skrevet om til lokal fallback slik appen gjør.

**32 🟢 · 7 🟡 · 40 🔴**

De 40 røde fordeler seg på tre klasser:

### 26 — fjernvert nede
Samme rotårsak som §1. Ikke en egen feil.

### 9 — rot-keypath svarer `notFound` (kontraktgap i cellen)

Samme feilklasse som perspective-buggen: cellen registrerer nøkler under et prefiks,
men rotnøkkelen svarer ikke, og `GeneralCell.resolveNestedValue` forutsetter at roten
serveres.

| Rotnøkkel | Rammer |
|---|---|
| `catalog.matching` | Apple Intelligence, Apple Intelligence Cell, Apple Intelligence Purpose Matcher |
| `catalog.query`, `catalog.catalogContracts`, `catalog.errorLog` | Catalog Workbench |
| `catalog.agreementTemplate`, `catalog.agreements` | Agreement Template Workbench |
| `scanner.encounters` | Entity Scanner (×2), Entity Scanner Test Helper, Entity Scanner Pairing Checklist |

Merk: `catalog.matching` **har** allerede en `registerGet` på rotnøkkelen med en
kommentar som beskriver nøyaktig denne feilen (`ConfigurationCatalogCell:1835`).
Den virker likevel ikke. Samtidig leser «Personal Co-Pilot Catalog» andre
`catalog.*`-røtter uten problem, mot samme celle.

Arbeidshypotese verdt å teste før noen skriver kode: `getEmitterWithLabel(label,
requester:)` er **requester-scopet**, og `attachedStatus.connected` bygger på den.
Én tilgangsscoping som feiler for denne requesteren ville forklare begge symptomene
samtidig — både `notFound` på lesing og at labelen aldri blir tilkoblet (§5).
Det er én undersøkelse, ikke sju.

### 5 — `cellNotFound`: flaten tilbys, cellen finnes ikke i appen

| Flate | Endepunkt |
|---|---|
| Skeleton Parity Text Fixture | `cell:///SkeletonParityTextFixture` |
| DiMy Wallet Runtime | `cell:///DiMyWallet` |
| DiMy Access Runtime | `cell:///DiMyAccess` |
| DiMy Pricing Policy | `cell:///DiMyPricingPolicy` |
| Network Sentinel | `cell:///agent/network/sentinel` |

Samme klasse som «Entity Scanner»-scope-bruddet i render-garanti-notatet fra
20. august: katalogen tilbyr noe som ikke kan lastes.

---

## 5. Ytelse: en ubrukt retry som kostet 21 sekunder

Måling før fiks, 79 lokale flater: last-tiden var **bimodal**. 52 flater brukte
1–11 ms. 27 flater brukte ~1440 ms. Ingenting imellom. Det er signaturen til et
retry-budsjett som brennes helt ut, ikke til arbeid som tar tid.

`waitForAttachedReferenceLabels` (12 forsøk × 120 ms = 1440 ms) ventet på
`ConnectionStatus.active`. Men `active` krever at labelen har en abonnert feed, og
`CellResolver.connectToLoadedCell` kaller `absorbFlow` — det eneste som registrerer
en feed — **bare når `reference.subscribeFeed == true`**. For enhver referanse med
`subscribeFeed: false` ventet vi altså på en tilstand som aldri kan inntreffe.

**Fikset** (`BindingTests/BindingTests.swift`): vent på `active` bare for referanser
som faktisk abonnerer, ellers på `connected`.

| | Sum lastetid, 79 flater | Flater ≥900 ms | 🟢 | 🟡 |
|---|---:|---:|---:|---:|
| Før | 38 115 ms | 27 | 18 | 21 |
| Etter | 17 100 ms | 12 | 32 | 7 |

−55 % lastetid. 14 flater gikk fra gul til grønn uten annen endring.

**De 12 som fortsatt brenner budsjettet** har `subscribeFeed: true`, men feeden blir
aldri aktiv: de fire Entity Scanner-flatene, Catalog Workbench, Agreement Template
Workbench, de tre Apple Intelligence-flatene, Trusted Issuers Registry, Identities
Access Control og Cloud Bridge Transport. Overlappet med §4-listen er nesten
fullstendig — se hypotesen der.

### Anbefalt, ikke gjort: den samme retryen i appen

`ContentView.waitForReadableBindingRoots` prøver 5 ganger med 300 ms pause og 900 ms
per probe. På de ni flatene i §4 svarer proben `notFound` på 1–13 ms, deterministisk,
hver gang — så appen sover **1,5 sekunder** for et svar som aldri endrer seg.

Det er ditt eget prinsipp: retry uten aktiv infrastrukturfeil er en bug, ikke et
sikkerhetsnett. Men det er atferd i appen, og skillet mellom «cellen varmer opp» og
«cellen serverer aldri denne nøkkelen» er en produktavgjørelse. Forslag: behold
retry for transportfeil og timeout, gi opp umiddelbart på `notFound`. Sier du ja,
er det en liten endring.

---

### Kontrollkjøring av fiksen

Sammenlignet flate for flate, før mot etter: **0 endrede utfall**, 14 flater
forbedret, ingen forverret funksjonelt. Fiksen endrer bare hvor lenge vi venter,
ikke hva som lykkes.

Én ting som ikke er forklart: `Agent Setup Workbench` brukte 361 ms på render i
første kjøring og 5385 ms i andre, med uendret lastetid (9 ms) og uendret utfall.
Median render var identisk i begge kjøringer (183 ms), og nest største avvik var
+100 ms — så dette ser ut som et engangsutslag, ikke en regresjon. Ikke reprodusert.
Verdt et blikk hvis det dukker opp igjen.

## 6. Verktøyet

`BindingTests/RemoteSurfaceRenderAuditXCTest` — fire faser, JSON- og
Markdown-rapport, ingen assertions på funn (en rød rad skal være synlig, ikke
avbryte kjøringen).

| Fase | Hva den måler |
|---|---|
| `local` | alle 79 katalogflater gjennom `contractReport` + `renderReport`, med lokale fallbacks |
| `bridge` | hver `cell://<vert>/<Celle>` gjennom `resolveEmit` (rute → websocket → admission) |
| `http` | hver CellConfiguration verten publiserer over HTTP, dekodet, validert og rendret |
| `load` | full Porthole-last for hver konfigurasjon som refererer verten |

Kjør: `zsh _audit-skeleton-render-20260828/run_surface_audit.sh`
Innstillinger: `_audit-skeleton-render-20260828/audit-settings.json`
(verter, faser, terskler — 3 s kald / 1,5 s varm, 10 s resolve-frist, 20 s last-frist).
Hele runden tar ~2,5 min på varm DerivedData.

Uten Xcode: `_audit-skeleton-render-20260828/inventory_hosts.sh` (ren curl) gir
HTTP- og websocket-status per vert på 20 sekunder. Den ville avslørt 404-en
umiddelbart.

---

## 7. Hva jeg foreslår at skjer nå

1. **Bestem hva som skal erstatte `/bridgehead`.** Alt annet er kosmetikk til det er
   avgjort. Ingen flate i appen kan nå hovedscaffoldet før dette er på plass.
2. **Fiks identitetsvaulten for de to 500-rutene** — de er blokkerende for
   fixturesuiten og for Personal Co-Pilot-katalogen, og ser ut som én felles årsak.
3. **Undersøk requester-scopingen på `catalog`/`scanner`-labelen** før noen skriver
   sju separate rotnøkkel-fikser. Én sak, ikke sju.
4. **Fjern eller registrer de fem cellene i §4** som tilbys uten å finnes.
5. **Si ja eller nei til `notFound`-retryen i §5.**
