# Transport og offentlig katalog — 30. september 2026

Arbeidseier: transport_repair. Opprinnelig avgrenset CellScaffold-arbeidstre:
`workspaces/CellScaffold`, fra main `a8f03c2a02b32deb6a87a0da53b753f82e2d1382`.
Denne rapporten dokumenterer kildearbeid og lokal teststatus; ingen deploy er gjort.

**Sluttstatus 02:37:** CellScaffold-kandidat `816be7ce` er kompilert med
publisert CellProtocol og består alle fire avgrensede Swift-regresjoner.
Web-regresjoner for host-alias (6), List (26) og korrigert Image-fixture (10)
er også grønne. Den generelle sikre native-brokjeden er fortsatt avhengig av
det separate CP53/AP5/AP7-arbeidet beskrevet nedenfor.

**Senere utvidelse, lokal ComponentSurface-adapter:** Root har autorisert en
avgrenset lokal adapter i Binding- og CellProtocol-arbeidstrærne. Koden er
kompilert i integrert Xcode-bygg og **alle seks adaptertester bestod** som
del av `integrated-visual.xcresult`: 30/30 totalt, ingen feil eller skips.
Se siste avsnitt for den eksakte lokale grensen.

## Katalogfeilen og rettingen

`GET /personal-copilot-v1/api/catalog` og de tre underrutene gikk via
`VaporPersonalCopilot.requesterIdentity`, som forsøkte å opprette
`personal-copilot-v1:<session>` i den sentrale IdentityVault. CellProtocols
`VaporIdentityVault.identity(for:makeNewIfNotFound:)` avviser nyopprettelse i
strict runtime (`Sources/CellVapor/VaporIdentityVault.swift:2246`). Dette passer
presist med den tidligere observerte 500-feilen. Ingen private identitetsfiler,
nøkler eller persisterte brukerdata er lest for diagnosen.

De fire HTTP-rutene bruker nå den allerede eksisterende, Resolver-baserte
`PersonalCopilotPublicConfigurationCell` og dens dedikerte ephemeral leser.
Eksakte tillatte keypaths er `catalog`, `catalog.entries.allowed`,
`catalog.entries.unavailable` og `catalog.policySummary`, bare `r---`.
Svarene er statiske factory-konfigurasjoner og katalogmetadata. Ingen
requester-valgt celle, privat tilstand, sentral identitetsbinding eller ny
brukersesjon opprettes. Resolver mangler fortsatt → eksplisitt feil, ikke
HTTP-fallback direkte til fabrikk. Private flater og skrivehandlinger er uendret.

`PersonalCopilotCatalogReadModel` deler eksisterende `state`/`policySummary`
mellom privat katalogcelle og offentlig lesemodell, slik at beskrivelsene ikke
driver fra hverandre.

Endrede kildefiler i CellScaffold:

- `Sources/App/Cells/PersonalCopilot/PersonalCopilotCells.swift`
- `Sources/App/Controllers/VaporPersonalCopilot.swift`
- `Tests/AppTests/PersonalCopilotV1Tests.swift`
- `Documentation/PersonalCopilotV1_CloudCells.md` (offentlig discovery og
  strict-vault-grensen, med eksplisitt unntak fra persona-resolution)

Nye meningsfulle regresjoner:

1. `testAnonymousCatalogGETsStayPublicWhenCentralIdentityCreationIsUnavailable`:
   alle fire ruter gir 200 selv når sentral vault nekter opprettelse; ingen
   sentrale mutationer, ingen identity-scoped registryvekst eller session-cookie;
   forfalskede persona-/user-/header-hint endrer ikke offentlige data; også
   sentral vault=nil fungerer; Resolver=nil feiler eksplisitt.
2. `testPublicCatalogPolicyAllowsOnlyExactStaticReadPaths`: eksakte offentlige
   lesestier tillates; write/execute/storage og private/prefiks-lignende stier
   avvises; faktisk get med annen signert identitet gir bare de fire forventede
   katalogfeltene; tilstandsmetadata samsvarer med eierens private katalog.

Katalogens genererte `CellConfiguration.uuid` og Skeleton-id varierer mellom
factory-kall. HTTP-sammenligningen normaliserer kun UUID-formede `id`/`uuid`
før sammenligning, ikke innholdsverdier eller endepunkter.

## Lokal validering — faktisk status

- `HAVEN_PYTHON=/usr/bin/python3 ci/check-value-literals.sh`: bestått,
  seks selvtester + ingen nye ValueType-literaler over grensen.
  Logg `logs/cellscaffold-value-literals.log`.
- `git diff --check`: bestått.
- Første Swift-forsøk feilet før kompilering med
  `sandbox-exec: sandbox_apply: Operation not permitted`.
  Logg: `logs/cellscaffold-catalog-tests.log`.
- Samme isolerte bounded testkjøring ble automatisk godkjent utenfor
  Codex-sandkassen. Første kompilering fanget `.unavailable`, som ikke
  finnes i låst ValueType 2026.9.3. Den uoppnåelige default-grenen ble
  rettet til eksplisitt `denied`. Logg:
  `logs/cellscaffold-catalog-tests-escalated.log`.
- Round2 ventet på eksisterende cachelease, holdt av en annen HAVEN-økt
  (PID6656). Ingen prosess ble stoppet og ingen cache ryddet manuelt.
  Vår runner fikk deretter lease (PID19439). **Kildene og testene kompilerte.**
  To nye tester kjørt: **1 bestått, 1 testassert-feil**.
  Logg: `logs/cellscaffold-catalog-tests-round2.log`.
- `testPublicCatalogPolicyAllowsOnlyExactStaticReadPaths` bestod.
  HTTP-testens fire ruter, strict-create-nekt, ingen sentrale mutationer,
  ingen cookie/identity-celler og falske persona-hint bestod. Siste
  assertion forventet in-memory `.cellConfiguration` etter HTTP-dekoding;
  wire-codec gir et ordinært JSON-objekt. Assertion er rettet til faktisk
  `JSONDecoder<CellConfiguration>` og sammenligning av alle 20 navn.
  Ingen produktendring var nødvendig for denne testfeilen.
- Ny kjøring med begge nye og de to nærmeste eksisterende katalog/config-
  testene ble **stoppet før bygg av diskvakten**: 55,6 GiB ledig, 45,6 GiB/
  4 % etter 10 GiB reserve; kravet er 40 GiB og 5 %. Vakten er ikke omgått.
  Logg: `logs/cellscaffold-catalog-tests-final.log`.
- Kontroll av runnerens støttede valg fant ingen separat test-only-/inkrementell
  kapasitetsprofil. `scripts/run_swift_bounded.sh:81` kjører
  `check_build_capacity.sh` før cachelease og Swift uansett videresendte argumenter.
  `--skip-build` går derfor gjennom samme vakt og ville dessuten kjørt den gamle
  testbinæren med feil assertion. Ingen reserve-/prosentgrense er senket, ingen
  cache er slettet og ingen ad-hoc Swift-kjøring er brukt som omvei. Per siste
  forsøk finnes ingen aktiv test-PID for denne deloppgaven.

Tidligere diskblokkering ble løst ved at normal ledig kapasitet steg,
uten terskelendring eller cleanup i denne deloppgaven. **Den endelige
korrigerte HTTP-regresjonen og alle tre øvrige målrettede tester er nå grønne.**

Sluttkjøring ved HEAD `816be7ce`, 30.09 kl. 02:37:

- Standardpreflight: 56,8 GiB ledig, 46,8 GiB / 5 % etter 10 GiB reserve.
- Samme isolerte bounded runner og cache `28516ddea851…`, to jobber,
  `CELLPROTOCOL_PUBLISHED_API=1` og `--disable-automatic-resolution`.
- **Build complete, 10,49 sekunder.** Den korrigerte assertion er kompilert.
- **4 tester, 0 feil, 3,018 sekunder**: de to nye katalog-/policytestene og
  de to eksisterende public-configuration/personal-catalog-regresjonene.
- Logg `logs/cellscaffold-catalog-tests-delivery.log:189–226`; exec-session
  29186 avsluttet med exit 0, AppTests-prosess 54722. Øvrige testprodukter
  hadde null matchende tester; AppTests kjørte faktisk alle fire.
- Runnerens sluttstatus 0; cache-delta +1716 KiB, available-delta −600 KiB.
  `Package.resolved` og kilde-worktree var uendret/rent etter kjøringen.

Eksisterende lease-beskyttet cache `28516ddea851…` ble brukt; ingen ad-hoc
buildrot. Initial kapasitetsport hadde 62,9 GiB ledig/52,9 GiB etter reserve.
Kommando (fra CellScaffold-arbeidstreet):

```sh
CELLPROTOCOL_PUBLISHED_API=1 HAVEN_SWIFTPM_JOBS=2 \
  zsh scripts/run_tests_isolated.sh --disable-automatic-resolution \
  --filter 'PersonalCopilotV1Tests.testAnonymousCatalogGETsStayPublicWhenCentralIdentityCreationIsUnavailable|PersonalCopilotV1Tests.testPublicCatalogPolicyAllowsOnlyExactStaticReadPaths|PersonalCopilotV1Tests.testAnonymousConfigurationGETsDoNotCreateCentralBindingsOrIdentityScopedCellsAndRequireResolver|PersonalCopilotV1Tests.testPersonalCatalogOnlyReturnsPersonalCopilotConfigurations'
```

`CELLPROTOCOL_PUBLISHED_API=1` beholder konsumentens publiserte
CellProtocol 2026.9.3 (`9c60001a…`) fremfor å plukke opp søskenarbeidstreet.
`Package.resolved` er uendret. Testene bruker egne midlertidige
HOME/CellsContainer gjennom repoets script.

Miljøfallgruve: `ci/check-value-literals.sh` valgte automatisk
`/usr/local/bin/python3.12`, som ga `Bad CPU type in executable`.
Det støttede `HAVEN_PYTHON=/usr/bin/python3` gjorde kontrollen kjørbar.

## Ekstra bekreftet web-feil: to labels for samme celle

Root ga denne avgrensede tilleggsoppgaven under testen. Den fryste
`corpus-staging-original/nested-reference-wide/configuration.json` har
`primaryFixture` og `secondaryFixture`, begge med det eksakt samme endepunktet
`cell:///SkeletonParityNestedReferenceFixture` og `state`-subscription.
Original `composedRendererData()` i `Public/js/conference-mvp.js` la bare ut
første label. Dermed manglet `Secondary projection` og `Shared row` selv om
den originale state-responsen faktisk inneholdt verdiene.

Host-komposisjonen eksponerer nå flere labels bare for eksakt samme ikke-tomme
endpoint som første label. Den kopierer ingen data til en annen celle, host,
pathvariant eller manglende endpoint. Begge JSON-navn (`references` og
`cellReferences`), eksisterende root-fallback og senere state-oppdatering
bevares. `Object.fromEntries` gjør også `__proto__` til en ordinær egen
dataegenskap fremfor å endre objektets prototype. Verken rå configuration,
state, Skeleton eller action-routing er skrevet om.

Filer: `Public/js/conference-mvp.js`,
`scripts/conference-renderer-data.test.js`, npm-kommando i `package.json`.

Regresjonsbevis med selve produksjonsscriptet kjørt i Node VM:

- `node --test scripts/conference-renderer-data.test.js` **mot original kode**:
  6 tester, 4 feil og 2 bestått. Logg `logs/conference-renderer-data-original.log`.
- Samme kommando **etter retting**: **6/6 bestått**, ingen skips.
  Logg `logs/conference-renderer-data-fixed.log`.
- `node scripts/conference-public-runtime-navigation-test.js`: **bestått**.
  Logg `logs/conference-public-navigation.log`.
- SHA-256 for de fire uendrede originale nested-reference-filene:
  `logs/nested-reference-original-sha256.json`.

Testene dekker begge referanseformer, synliggjøring av original sekundær
tekst/rad, ulike celler/hosts/paths, manglende endpoint, oppdatering av state,
uforandret råpayload og prototype-lignende labels. Dette er et testet
host-data-komposisjonsbevis, ikke alene en browser-/native-screenshotattest.
Root lager separat originalpayload + korrigert host-root-scenario.

## Web List: statiske og bundne rader

Den utvidede canonical-26-matrisen avdekket at `renderList()` aldri beholdt
`List.elements`. Swift-kilden `CellProtocol/Sources/CellApple/Cells/Porthole/Utility Views/CellListView.swift:113`
viser at contextualRows/valueTypeList kommer først, fulgt av statiske
`skeletonList.elements`. Ingen deduplisering skjer i denne grenen; flow-rader
behandles separat etterpå. JSON-feltet er `ValueTypeList`, ikke Skeleton-elementer.

`Public/js/skeleton-runtime.js` beholder nå `elements` som `staticItems` på
list-bindingen. `updateCollectionBindings` setter sammen bound+static før
signaturberegning, rendering og valgindekser, kun for `kind === "list"`.
Grid, Reference og Picker er uendret. Testfixture og originalt corpus er uendret.

Ny testfil `playwright/skeleton-list-static-elements.spec.js` har fire
regresjoner på både 1180 px og 390 px: statiske scalar-rader uten keypath/mal;
blandede template-rader med eksplisitt bevaring av duplikat-ID; state replacement,
empty/missing/null/non-list der statiske rader består; samt korrekt ID+indeks i
selection-payload før/etter state refresh. Render og refresh sender ingen actions.

Originalkode feilet første regresjon med null rader mot forventet to
(`--max-failures=1`; øvrige syv ikke kjørt). Bevis:
`logs/web-list-static-original.log` og `web-list-static-original/`.
En mellomkjøring ble avbrutt under diffkontroll og teller ikke som validering
(`logs/web-list-static-fixed.log`, exit 130).
Endelig kjøring mot rettet kandidat: **26/26 bestått**, 8,3 sekunder, exit 0.
Dette inkluderer de åtte nye testene samt tree (4), followTail (3),
elementkatalog med Grid/Reference (10) og workbench auto-scroll (1).
Logg: `logs/web-list-static-final.log`; avsluttet session 35829, worker-PID 42734.
`node --check Public/js/skeleton-runtime.js` og `git diff --check` bestod.

Kommando fra CellScaffold-arbeidstreet (eksisterende Playwright 1.55.1 installasjon,
ingen npm-install, Swift eller live serverhandlinger):

```sh
env NODE_PATH=/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/node_modules \
  node /Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/node_modules/@playwright/test/cli.js \
  test --config=playwright.config.js \
  playwright/skeleton-list-static-elements.spec.js \
  playwright/skeleton-list-tree.spec.js playwright/skeleton-list-follow-tail.spec.js \
  playwright/skeleton-element-catalog.spec.js playwright/skeleton-workbench-autoscroll.spec.js \
  --output=../../web-list-static-final > ../../logs/web-list-static-final.log 2>&1
```

Root kjører den separate 52-bilders web/native-matrisen etter denne rettingen;
26/26-resultatet er nettleserregresjoner, ikke det nye screenshot-resultatet.
Patch: `logs/cellscaffold-list-static.patch`; kilde- og testhashes er oppdatert i
`logs/cellscaffold-candidate-sha256.json`.

## Image-fixture: korrupt PNG og utilstrekkelig web-assertion

Root oppdaget at canonical `image-data-url` ikke ga et meningsfullt bildebevis.
`Tests/fixtures/SkeletonElementParityMatrix.v1.json` inneholdt en 68-bytes PNG
med gyldig signatur/IHDR/IEND, men **ugyldig IDAT CRC** og zlib-feilen
`Error -3 while decompressing data: incorrect data check`.
Original SHA-256: `dd6a56333521da0ae07ff2611707e49b2107c2298616f11b9ba950d116d71143`.
Originale bytes og fixture er bevart som `logs/skeleton-image-original.png`
og `logs/skeleton-image-original-fixture.json`. Strukturell kontroll står i
`logs/skeleton-image-validation.json`.

Chromium tolererte den korrupte PNG-en: `decode()` fullførte, og canvas leste
én opaque hvit piksel (RGBA 255/255/255/255). Det er derfor feil å hevde at
browser-dekoderen avviste bildet. Den skjerpede testen mot originalen feilet
på reelle dimensjoner/farger: `logs/web-image-original-pixels.log` og
`web-image-original-pixels/`. Eldre `complete === true` var ikke et bevis på
forventet bildeflate. Første prøve brukte faste samplekoordinater utenfor
originalens 1×1-raster (`logs/web-image-original.log`); den er erstattet av
kontrollen med proporsjonale koordinater innenfor rasteret.

Bare testfixture og test er endret i denne deloppgaven:

- `Tests/fixtures/SkeletonElementParityMatrix.v1.json`: samme case-id/navn,
  nå gyldig 32×32 RGBA8 PNG, fire opaque 16×16-kvadranter og eksplisitte
  `modifiers.width=32`, `modifiers.height=32`.
- `playwright/skeleton-element-catalog.spec.js`: på både 1180 px og 390 px
  kreves `decode()`, naturalWidth/naturalHeight 32, synlig visning minst
  32×32 og faktiske pixelverdier fra hver kvadrant. Ingen produksjonskode
  ble endret for Image.

Kvadranter i rekkefølge øvre venstre, øvre høyre, nedre venstre, nedre høyre:
RGBA `(220,40,40,255)`, `(20,170,70,255)`, `(30,90,220,255)`, `(245,195,20,255)`.
Korrigert PNG er 124 bytes med SHA-256
`3c5d121d012f4fa54846b5fdac94dd08a5cc3d93bac8b1032acdf64d4edd0f0e`;
alle chunks har gyldig CRC og zlib inflates til forventet 4128-byte raster.
Korrigerte bytes finnes også i `logs/skeleton-image-corrected.png`.

Kjøring: samme Node/NODE_PATH/Playwright-launcher som over, med
`test --config=playwright.config.js playwright/skeleton-element-catalog.spec.js
--output=../../web-image-fixed > ../../logs/web-image-fixed.log 2>&1`.
**10/10 bestått**, 5,0 sekunder, exit 0; session 8024, worker-PID 47061 avsluttet.
`git diff --check` bestod. Root regenererer canonical corpus separat og
merker korrigert fixture tydelig; opprinnelig corpus er ikke overskrevet her.

Ved Image-deloppgaven ble normal diskpreflight kontrollert på nytt, uten variabeloverstyringer:
`zsh scripts/check_build_capacity.sh "$PWD"` ga exit 75, 56,1 GiB ledig og
46,1 GiB/4 % etter 10 GiB reserve. Swift ble da ikke startet på nytt;
ingen kapasitetsgrense eller cleanup er brukt. Logg:
`logs/cellscaffold-capacity-image-followup.log`.
Den senere grønne sluttkjøringen er dokumentert under lokal validering over.

## Hvilken native-transport eksisterer faktisk?

### Generell bridgehead

`Sources/App/Controllers/VaporBridgehead.swift:15` sier og koden bekrefter at
den gamle uautentiserte ruten er fjernet. Den registrerer ingen rute.
404 på `/bridgehead/<Cell>/<uuid>` er derfor ikke en tilfeldig manglende
alias som trygt kan gjenopprettes. Serveren er ikke endret for å åpne den.

### Eksisterende, smal Sprout native-porthole

Kilder i CellScaffold main:

- `Sources/App/Controllers/VaporSproutResolver.swift:48`: POST
  `/v1/resolver/portholes/access`.
- Samme fil `:60`: WebSocket
  `/v1/resolver/native-porthole/:pubId/:bridgeId`.
- `Sources/App/Services/SproutResolverCompatibility.swift:490`:
  `SproutPortholeAccessRequest`; `:510`: svarkontrakt.
- Samme fil `:755`: utstedelse; `:839`: validering ved native upgrade.
- `Tests/AppTests/SproutResolverRoutesTests.swift:102`:
  `testResolveEntityAndIssueNativeContract` tester utstedelse, ikke en full
  Binding-over-WS-surface.

Kontrakten krever scaffold-domain/admin-public-key, requester-public-key,
oppløst entity-id, bridge-descriptor, `client_kind=native`,
`porthole_protocol=cellprotocol`, eksplisitt purpose/goal/interests og
capability-grants. Native-utstedelsen setter publisher til **Porthole**.
Klienten må bruke kontraktens `bridge_endpoint`, tilføye `/bridgeId` og sende:

- `contract_payload_b64url`: Base64URL av hele kontraktens JSON-bytes,
- `contract_sha256_b64url`: Base64URL(SHA256 av akkurat disse bytes),
- valgfritt `contract_id`, som må stemme dersom sendt.

Validator sjekker publisher-allowlist, payload-hash, ID, native/cellprotocol,
utløp, Ed25519-kontraktsignatur, eksakt aktiv resolver-issuer og forventet
bridge-endepunkt fra Host/Forwarded-Proto. Dette er ikke generell sikker
adgang for Binding til alle navn i `cell://` og er ikke en erstatning for
kanalbundet klientproof. Transportkontrakt alene gir heller ikke
Cell/Resolver-rettigheter. Ruten er ikke endret, og denne økten har ikke
kjørt en brukerautentisert live Sprout-flyt.

### AdminScaffold

`Sources/ScaffoldKit/AdminScaffoldBridgeRoutes.swift:317` (dedicated) og `:433`
(mux `/session`) bruker `AdminBridgeHandshakeAuthentication` før upgrade,
med HMAC-klientcredential, originbinding og publisert celleallowlist.
Dette er admin-kontrollplanet, ikke en generell personlig Binding-inngang.
`RemoteBridgeheadAccess` er utgående token/host-konfigurasjon; den
registrerer ikke den manglende generelle inbound-ruten.

## Koordinering med eksisterende broarbeid — ikke oppfunnet ny mekanisme

Kanonisk arbeid er
`CellProtocolDocuments/Deliverables/PDD_bro-paa-i-prod_2026-09-26/`.
`PLAN.md` AP5 sier at CellScaffold skal registrere generell bridgehead med
CellProtocols nye gate; AP7 omfatter Binding-klienten. AP5 sier eksplisitt
at native-porthole ikke røres. Avhengighetsgrafen krever CP-review og
Kjetils mergebeslutning før CellScaffold-integrasjon/pin.

[CellProtocol PR #53](https://github.com/Digipomps/CellProtocol/pull/53)
ble kontrollert live med GitHub-connector 30.09: **OPEN**, `merged=false`,
head `3824cf84b58903f900a49b0987ee660085f3d875`. Lokal origin-ref samsvarte.
Ingen merge/pin/CP53-endring er gjort av denne økten.

`handoff/ASTRA-ETTER-CP53-8.md` på denne headen anbefaler ikke merge:
syv gjenstående blokkerende funn etter Kjetils vedtatte samlede mergeport.
For denne oppgaven er to grenser særlig relevante:

- **N35:** holdt celleoperasjon på én logisk mux-kanal blokkerer søskenkanal
  og close gjennom Vapor-socketens ytre ordningskø. Dette er eksplisitt
  teknisk produksjonsblokkering for WS/mux i kontroll 8.
- **N05:** Binding sin lokal-vault-fallback/consumer-inngress er separat
  konsumentarbeid; CP-kontrollen erklærer den ikke lukket. Før en ny pin
  må klienten bruke faktisk lokal owner, riktig proof-scope og den nye
  gate-kjeden uten default-vault-fallback for fjern identitet. Opprinnelig
  AP9a `handoff/ASTRA-ETTER-CP53.md:88` peker presist på
  `Binding/Binding/PersonEntityReadTransport.swift:84–97,127–145` ved det
  daværende Binding-main: kopiert UUID/fingerprint/home-vault ga dekodet
  wire-identitet lokal vault før delegate. Kravet er BridgeIdentityVault
  for alle incoming command/response-deskriptorer, ekte signer kun i lokalt
  startet klientoperasjon, auth-delegatens predecode-validator og tester
  med kopiert lokalt eid identitet samt fravær av delegate. CPs øvrige
  signeringsvern betyr at dette ikke alene beviser nøkkelutlevering.

CP53 inneholder en konkret testbar integrasjonsoppskrift:
`Tests/CellBaseTests/BridgeChannelWebSocketTests.swift:44–112` setter opp
`BridgeChannelTransport` over en ekte loopback Vapor-WS, avviser get før
proof og gjennomfører beskyttet get etter proof med null server-signer-kall.
Den dekker dedicated og én mux-kanal; ikke N35s to samtidige kanaler.
Dette er eksisterende tester lest fra Git-objektet, **ikke kjørt her**.

På PR53 wrapper CellResolver utgående dedicated/mux med gate automatisk.
Direkte klient kan konstruere klientvarianten av `BridgeChannelTransport`,
knytte `BridgeBase` til faktisk lokal requester/forventede proof-scopes,
og kalle setup. Server må installere gate synkront før meldinger mottas,
bruke kanonisk WSS origin/path/domain og delt bounded limits, og først
opprette publisher-bridge etter identitetsproof. `Docs/BridgeIdentitySecurity.md`
på PR53 beskriver dette. Det finnes ingen ferdig tilsvarende generell
CellScaffold/Binding-kjede i de undersøkte main-kildene.

## Neste konkrete steg

1. Katalogregresjonene er kompilert og bestått under samme pins ved
   `816be7ce`. Vurder kode og testdiff før eventuell PR.
2. Root kan integrere offentlig HTTP-katalog/config og native-renderer
   uavhengig av gjenåpning av generell transport.
3. Avklar samlet AP5/AP7-eierskap med den allerede pågående brorekken;
   ikke importer CP53 eller gjenåpne generell anonym bro som snarvei.
4. Etter broporten: test faktisk WSS proof → beskyttet surface read/action,
   manglende/feil proof, source rejection, disconnect/expiry og sibling-mux,
   med origin-filer og identitetsgrenser intakte, før man hevder at alle
   eksterne flater kjører i HAVEN.

## Lokal ComponentSurface-adapter — implementert og 6/6 tester bestått

Den eksisterende native request-kontrakten i
`CellProtocol/Sources/CellApple/Cells/Porthole/Utility Views/Skeleton/Suggestion/SkeletonNativeRuntime.swift`
har keypath, urørt payload, sourceCellEndpoint og separat mount metadata.
Tidligere hadde Binding ingen installert handler. Å installere den generelle
handleren på hele flaten ville også fanget ordinære Button.url-handlinger før
rendererens navigasjonsgren. Derfor er det lagt til en separat miljøverdi,
`skeletonMountedActionHandler`, i nye `SkeletonMountedActionAdapter.swift`.
Bare `CellComponentSurfaceView` installerer den som generell handler inni
sin mounted SkeletonView. Eksisterende diagnostikk vises fortsatt uten noen
tilgjengelig adapter; øvrige elementer beholder ordinær navigasjon.

Binding-filen `Binding/BindingSkeletonMountedActionSupport.swift` gir
`handler(viewModel:onDispatchAttempt:)`. Hver handling bruker nåværende
`PortholeViewModel.executionRequesterIdentity()` og vanlig
`CellResolverProtocol.get/set` med eksplisitt requester. Ingen identitet
opprettes, ingen lokal vault brukes som reserve, ingen bro opprettes og ingen
private tjenester kontaktes av adapteren. Den godtar kun én lokal celle i
`cell:///CellName` og relativ, punktdelt keypath; remote host, query,
fragment, path traversal og absolutte handlingstargets avvises.

`payload == nil` bruker GET; `.null` og alle andre eksplisitte verdier bruker
SET. Payload sendes uendret. Mountens instanceID/componentID/revision holdes
som separat vertskontekst i dispatch-observasjonen og endrer verken payload,
autorisasjon, kildecelle eller Agreement. Det er ikke oppfunnet et nytt
Meddle-metadataparameter. Manglende requester/resolver, ikke-Meddle-kilde,
autorisasjonsnekt og uløst svar blir feil. Nil fra SET betyr manglende
skrivebekreftelse og uavklart utfall; adapteren fabrikkerer ikke `.null` som
bekreftelse og prøver aldri automatisk på nytt.

Nye `BindingTests/BindingSkeletonMountedActionSupportTests.swift` har seks
regresjoner for faktisk ephemeral GeneralCell, registrert CellResolver og
signert Agreement: tillatt og nektet requester, manglende requester selv med
eier i standardvault, GET kontra eksplisitt null SET, avviste remote/ugyldige
targets, ingen automatisk retry ved nil-svar og NSHosting-klikk på mount A/B
med payload/metadata-kollisjon samt ordinær URL-navigasjon som søsken. Siste
test bytter aktiv requester til den nektede identiteten og krever propagert
autorisasjonsfeil uten ny kildeinvokasjon.

Root eier BindingSkeletonView-wiring og det integrerte Xcode-bygget;
rendereragent eier samlet CellApple Skeleton-testkjøring. `git diff --check`
bestod i begge kandidater ved kodefrys. Integrert kjøring ferdig 03:00:45
bestod alle seks `BindingSkeletonMountedActionSupportTests`, inkludert
NSHosting-klikk gjennom den reelle source-handleren og Resolver/Agreement,
mount A/B, vanlig URL-navigasjon og endret aktiv requester som blir nektet.
Resultatet er lest direkte med
`xcrun xcresulttool get test-results tests --path integrated-visual.xcresult`.
`integrated-visual-summary.json` dokumenterer 30/30 tester, null feil,
null skips og ingen runtime warnings. `integrated-visual.log` viser
resultatbunten og Xcode-PID 62862; root kjørte i den delte integrerte
DerivedData-roten. Ingen egen byggrot eller kapasitetsomgåelse er brukt.
Denne lokale adapteren gir ikke remote
ComponentSurface-action-paritet og lukker ingen av CP53/AP5/AP7-portene.
