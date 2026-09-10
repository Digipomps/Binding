# Perspective-entiteter og invitasjonslanding — implementasjon 2026-08-21

Skrevet av Claude etter en runde med rådgiverpanelet (`plan-advisors`-rollene
fra `HavenAgentD/Sources/HavenAgentRuntime/AdvisorPanelSpawnService.swift`).
**Kompilert og testet** — se «Bygg og verifiser» nederst for kommandoene og
det som fortsatt er rødt (og hvorfor det ikke er vårt).

Forrige runde (`HAVEN_Relations_Invite_and_Residency_2026-08-20.md`) etterlot
tre ting til godkjenning. Alle tre er nå bygget, og panelet fant fire feil til
underveis som også er rettet.

---

## Det panelet fant, og som endret planen

**1. Projeksjonen ville stille feilet.** `entityRepresentationDrafts()` la noden
under nøkkelen `"object"`, mens `Weight` bruker `"value"`. En projeksjon ville
blitt akseptert og så tømt for alle personer. Påstanden om «én linje å koble
opp» var feil.

**2. Entitetsgrafen var nøklet på visningsnavn.** `PerspectiveNodeImpl.reference`
returnerte `name`. To personer med samme navn smeltet sammen, og
`Perspective.json` ble en klartekstliste over alle du kjenner — i en fil hvis
hele formål er å sammenlignes med andre parter.

**3. Billetten var ~1424 tegn, ikke 500.** Med æøå blir SMS-en UCS-2:
~25 segmenter. Kortlenken fantes i koden, men ble aldri brukt, og `humanCode`
ble aldri registrert noe sted — så `GET /i/<kode>` var umulig slik det stod.

**4. `send_contact_request_to_issuer` hadde ingen mottaker.** Den ene av
billettens to capabilities var død tekst.

Og fire mindre, men ekte: `SkeletonButton` mangler `urlKeypath` så
`handoffURL` ikke kunne åpnes; importflaten hadde ingen `Picker` så
kolonnekartleggingen ikke kunne rettes; `Perspective.addEntityRepresentation`
fylte aldri oppslagsordboken; og det fantes ingen slettemetode for entiteter i
det hele tatt.

---

## CellProtocol

### Opak referanse

`PerspectiveNodeImpl` har fått `nodeIdentifier: String?`. `reference` bruker den
når den finnes, ellers `name` — så formål og interesser oppfører seg nøyaktig
som før, mens noe som representerer et menneske får en saltet, lokal id.
`EntityRepresentation` koder og dekoder feltet, sammen med `projectionSource`.

`person`, `fulfilled` og `identities` kodes **ikke** lenger. For en projisert
relasjon ville de båret et annet menneskes kontaktopplysninger inn i grafen.

### Entitets-CRUD og projeksjon

Ny fil: `Sources/CellBase/PurposeAndInterest/PerspectiveEntityProjection.swift`.

- `upsertEntityRepresentation` — idempotent
- `removeEntityRepresentation(reference:)` — rydder ordbok, navneindeks,
  container og aktiv vekt
- `upsertActiveEntity` / `removeActiveEntity` — speiler purpose-varianten
- `applyEntityProjection(_:)` — **hel-sett-erstatning per kilde med epoke**
- `clearEntityProjection(source:)`

Hel-sett er poenget: det er det som gjør at en sletting i Relations når fram til
grafen. Inkrementelle tillegg kunne aldri det, og perspektivet ville bare vokse.
Epoken hindrer at en forsinket skriving gjenoppliver noe en nyere fjernet. En
kilde eier bare sin egen skive — manuelt innlagte noder og andre kilders noder
røres aldri.

Rettet i `Perspective.swift`: `addEntityRepresentation` leste fra
`purposeNameReferences`, muterte en forkastet kopi, og fylte aldri
`entityRepresentationReferencesDict` — så et oppslag én linje etter et tillegg
kom tomt tilbake. `updateEntityRepresentation` kastet
`noEntityForReference` på første innsetting, altså behandlet enhver vellykket
innsetting som en feil.

### Intercepts

Ny fil: `Sources/CellApple/PurposeAndInterest/Cells/PerspectiveCell+Entities.swift`.

| Keypath | Type | Hva |
|---|---|---|
| `entities` | get | Aktive entiteter, vekter og interesser |
| `addEntity` | set | Én eller flere vektede entiteter |
| `removeEntity` | set | Én eller flere referanser |
| `projectEntities` | set | `{source, epoch, entities}` — hel-sett |
| `perspective.query.activeEntities` | set | Filtrert spørring |

Get ligger på **rotnøkkelen** `entities`, fordi en lesning løses ved å gå ned
fra roten — nøyaktig lærdommen fra `perspective.perspective: notFound`. Set
matcher eksakt, så de beholder full sti.

`perspective.state` har fått `activeEntityCount` og `activeEntities`.

### Invitasjonsmodulen flyttet hit

`Sources/CellBase/Invitation/`:

- `HavenInviteTicket.swift` — `HavenSignatureProof`, `HavenInviteTicket`,
  `HavenInviteLink`, `HavenInviteVerifier`
- `HavenInvitePublication.swift` — `HavenInviteCopy`, `HavenInvitePublication`,
  `HavenInviteRevocationNotice`, `HavenInviteStatusReport`,
  `HavenInviteContactRequest`, `HavenInvitePublicationVerifier`

De måtte flytte fordi mottakerens side ikke kjører i appen. To implementasjoner
av «er denne invitasjonen gyldig» driver fra hverandre; én delt type kan ikke.
`HavenInviteVerifier.payload(for:ticket:)` er den ene serialiseringen både
Binding og landingssiden bruker.

Billetten er komprimert: korte kodenøkler, epoch-sekunder i stedet for
ISO-strenger, `landingBase` fjernet (lenken bærer verten selv),
capabilities kodes bare når de avviker fra standardsettet. Fortsatt for lang
for SMS — derfor kortlenke.

---

## Binding

### Ekte projeksjon

`relations.projectToPerspective` bygger `Weight`-objekter i **kanonisk form**
(`{weight, value}`), med:

- **opak, saltet referanse** — `e-<sha256(salt|relationID)>`. Saltet er 32
  tilfeldige byte som ligger i cellen. Samme person beholder referansen sin;
  to med samme navn kolliderer ikke; to entiteter kan ikke koble sammen sine
  perspektiver på den.
- **interesser fra `contextTags`** — en entitet uten interesser matcher
  ingenting, så en projeksjon av bare navn ville gjort grafen større uten å
  gjøre den smartere.
- **vekt = relasjonens salience, ikke `confidence`.** Confidence måler om vi
  slo sammen to regnearkrader riktig. Brukt som grafvekt ville en ren
  CSV-import rangert over noen du faktisk kjenner.
- **ingen endepunkter, ingen `endpointTokens`, ingen opprinnelse.**

`relations.setProjectionEnabled` styrer det, og står **av** som standard —
projeksjon er en reell avsløring. Å slå den av sender et tomt sett, som fjerner
det som ble projisert.

### Publisering, kortlenke og ekte statussignal

`invite.prepare` registrerer billetten hos scaffoldet (`autoPublish`, på som
standard når `landingBase` er satt). Det gir kortlenke, en mottaker for svar, og
et ekte åpnet/joined-signal i stedet for selvrapportering.

Nye keypaths: `invite.publish`, `invite.refreshStatus`,
`invite.pullContactRequests`, `invite.acceptContactRequest`,
`invite.openPreparedMessage`.

SMS **nektes** når billetten ikke kan publiseres — å sende 25 SMS-segmenter er
verre enn å si nei. Nytt: døgnkvote (25 som standard) og dedupe på
`audienceToken`, så 400 importerte kontakter ikke blir et spam-rykte på én
kveld.

`invite.openPreparedMessage` åpner `mailto:`/`sms:` gjennom
`BindingExternalURLOpener`, som bare tillater de to skjemaene. Det er den siste
centimeteren som manglet: før dette stod brukeren med en ferdig melding hen
ikke kunne åpne. Det er en sideeffekt, så den skjer bare fra et eksplisitt
trykk, og den åpner en komposisjonsvindu — den sender ikke.

### Kontaktforespørselen er ekte nå

`HavenInviteContactRequest` signeres av mottakerens **ferske** identitet og
bærer nøkkelen, så avsenderen verifiserer den selv når den kommer inn — uten å
stole på scaffoldet, som bare formidlet. Den mapper til
`cellprotocol.contact.request.v1`, altså inn i `ContactEndpoint`-cellen som
allerede eier førstekontaktspolitikk. Én innboks, ikke to.

Billetten lover bare `send_contact_request_to_issuer` når `contactEndpointID`
faktisk er satt. Ellers droppes capability-en, og grensesetningen endres
tilsvarende.

### Én flate

`Cells/RelationsWorkbenchConfiguration.swift`. Fire menyvalg ble til ett.
Seksjonene vises via `SkeletonModifiers.visibility` først når de har noe å si:

1. **Noen har svart** — øverst, fordi et menneske som venter slår alt annet
2. **Kom i gang** — bare ved null relasjoner: én setning, grensen, to knapper
3. **Se over importen** — når en fil venter: `Picker` per kolonne, usikre
   kolonner først, kolonneindeksen aldri synlig
4. **Klar til å sendes** — den ferdige meldingen og knappen som åpner den
5. **Hverdagen** — søkefelt, treff, «Inviter» på hver person
6. **Invitasjoner** — status, og to knapper som henter, ikke sender

Ingen faste listehøyder. Ingen rå keypaths som etiketter.

**Rettet i alle konfigurasjoner:** lesninger skal være `<label>.state.…`, ikke
`<label>.<celleRot>.state.…`. Den doblede formen ber cellen om en rotnøkkel
ingen serverer — samme feilform som `perspective.perspective: notFound`.
Skrivinger matcher eksakt og beholder full sti.

---

## CellScaffold

- `Sources/App/Models/InviteLandingRecords.swift` — `InviteTicketRecord`,
  `InviteContactRequestRecord` og `CreateInviteLandingTables`
- `Sources/App/Controllers/VaporInviteLanding.swift` — rutene
- `Sources/App/Controllers/InviteLandingHTML.swift` — siden
- Registrert i `routes.swift` og `configure.swift`

| Rute | Hvem | Hva |
|---|---|---|
| `GET /i/:token` | hvem som helst | Serverrendret side, ingen JS |
| `POST /i/api/publish` | utsteder, signert | Registrer billett |
| `POST /i/api/revoke` | utsteder, signert | Trekk tilbake |
| `POST /i/api/status` | utsteder, `statusKey` | Åpnet/joined |
| `POST /i/api/requests` | utsteder, `statusKey` | Hent svar |
| `POST /i/:token/reply` | mottaker | Signert kontaktforespørsel |

Mønsteret er hentet fra `PersonalCopilotCollaborationInviteHTML.swift`, som
panelet pekte på som nesten identisk spec.

**Ikke et orakel.** En sekstegns kode er gjettbar, så kortkode-stien svarer
identisk for ukjent, utløpt og tilbakekalt, og er rate limited. En
selvbærende billett er annerledes: den som holder den har allerede alle
fakta i den, så presis beskjed røper ingenting.

**Ingen autoritet.** Verdikten kommer fra `HavenInviteVerifier` i CellBase —
samme kode Binding kjører. Scaffoldet kan ikke lage, endre eller godkjenne en
invitasjon. Det lagrer det en utsteder signerte, og teller hva som skjedde.

Grenser: `maxContactRequests` per billett (3 som standard), så en videresendt
lenke ikke blir en åpen innboks. Svar leveres én gang og markeres hentet.

---

## Hva som ærlig talt ikke er ferdig

**Svar fra nettleseren returnerer 501.** En person i en nettleser har ingen
signeringsidentitet før hen har opprettet en konto. Form-stien redirecter til
`/login?next=/i/<token>`, og etter innlogging svarer den fortsatt 501 fordi
scaffoldet må signere på vegne av brukeren — det er ikke koblet opp.
JSON-stien fra en app virker fullt ut. Dette er den ene store gjenstående
tingen, og den avgjør om Vegar kan svare uten å installere noe.

**Flaten er ikke previewet i Porthole.** `SkeletonModifiers.visibility` finnes i
skjemaet, men om rendereren respekterer den vet jeg ikke. Om den ignoreres,
vises alle seksjonene samtidig — degraderingen er stygg, ikke ødelagt. Kjør
`npm run skeleton:iterate -- --mode preview` før dette vises til noen.

**`invite.pullContactRequests` og `refreshStatus` er manuelle.** Det finnes
ingen push. To knapper, som henter når du trykker.

**Chattens invite-helper peker fortsatt på hardkodede personer**
(`ChatWorkbenchParityCells.swift`, «Anna Kollega»). Den må peke på
`cell:///Relations` før noe av dette vises til en bruker. Ikke rørt i denne
runden.

**Identitet per oppstart er fortsatt åpen.** Skeptikeren har rett i at det
blokkerer alt: en invitert bruker møter en ødelagt skjerm. Det er egen sak.

---

## Bygg og verifiser

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/CellProtocol && swift build && swift test
cd ../CellScaffold && swift build && swift test
cd ../Binding && ./Scripts/build_binding.sh && ./Scripts/test_binding.sh
```

Rekkefølgen er ikke tilfeldig: Binding og CellScaffold avhenger begge av de nye
typene i CellBase.

`swift build` i CellScaffold krever `--only-use-versions-from-resolved-file`.
Uten det prøver SwiftPM å reresolve, og `swift-nio-extras` ber om et trait
(`FoundationURL`) som `swift-http-types` ikke deklarerer. `Package.resolved` er
ikke rørt.

Binding bygges mot tre destinasjoner:

```bash
xcodebuild -project Binding.xcodeproj -scheme HAVEN \
  -destination 'platform=macOS,arch=arm64' build
xcodebuild -project Binding.xcodeproj -scheme HAVEN \
  -destination 'generic/platform=iOS Simulator' build
xcodebuild -project Binding.xcodeproj -scheme HAVEN \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

### Det som faktisk var galt

Ni ting, alle rettet:

1. `InviteLandingRecords.swift` manglet `import CellBase`, så
   `HavenInviteLifecycle` fantes ikke i scope.
2. `.prefix(3).map(String.init)` på `[String]` — `String.init` er tvetydig når
   elementet allerede er en `String`. Erstattet med `Array(...prefix(3))`.
3. `current?.jobTitle = current?.jobTitle ?? …` i vCard-parseren er overlappende
   tilgang til `current`. Lest ut i en lokal først.
4. `stateQueue.sync({ … })` i parentes krever `execute:`-etiketten. 17 steder.
5. `request["requesterIdentity"] = .identity(…)` — venstresiden er
   `ValueType?`, og Swift slår ikke opp medlemmer gjennom `Optional`. Skrevet
   `ValueType.identity(…)`.
6. `planObject`-literalen i `EntityResidencyCell` var for stor for
   typesjekkeren. Bygges nøkkel for nøkkel nå.
7. De tre nye katalogflatene manglet `appStoreScope`-interessen, så
   `isAllowedInPersonalCopilotV1` avviste dem. Kjører gjennom
   `BindingPersonalCopilotV1Policy.discoveryInterests(_:policyCategory:)` nå,
   og forventet antall i `BindingTests` er 16 → 19.
8. **Ekte defekt:** `HavenRelationNormalizer.normalizePhone` godtok datoer.
   «2026-01-01» strippes til åtte siffer og leses som et norsk fastnett­nummer,
   så en datokolonne i et regneark ble til telefonnumre. Ny `looksLikeCalendarDate`
   avviser ISO-datoer og de to europeiske skriveformene på *form*, ikke lengde
   — `415-555-1234` treffer ikke.
9. **Ekte regresjon fra denne runden:** get-interceptet for `perspective.state`
   ble flyttet til rotnøkkelen `perspective`. Rotnøkkelen *må* være der, ellers
   feiler rotbinding-probene, men `perspective.state` er nøkkelen
   `CellRuntimeReadinessContractTests` og forbrukerne faktisk navngir. Begge er
   registrert nå; eksakt treff vinner, og begge returnerer samme snapshot.

10. **Ekte defekt:** `HavenInviteLink.encode` brukte `JSONEncoder()` uten
    `.sortedKeys`. `JSONEncoder` lover ingen nøkkelrekkefølge, så samme billett
    kodet to ganger ga *to forskjellige tokens* — og tokenet er lenken. En
    publisert invitasjon sluttet å matche den utstederen satt med. Nå sortert.

To testfeil var feil i testene, ikke i koden:

- `EphemeralIdentityVault` nummererer identiteter fra 1 *per vault*, så to
  vaults gir utsteder og invitert samme UUID — og kontaktforespørselen ble
  avvist for å utgi seg for utstederen. Suitene deler ett vault nå.
- `JSONEncoder` skriver `cell:\/\/\/Relations`. Testen sammenligner mot
  uescapet tekst.

### Fortsatt rødt, og ikke vårt

`CellConfigurationVerifierXCTest.testEveryOfferedCatalogConfigurationHasReadableRoots`
melder 4 av 16 scaffold-formål som ikke lastbare. Alle fire er eldre enn denne
runden:

| Flate | Årsak |
| --- | --- |
| Butterpop Studio | `staging.haven.digipomps.org` svarer 1011 på websocket-håndtrykket |
| Calendar Store | rot `calendar` → `notFound` |
| Apple Intelligence | rot `matching` → `notFound` |
| Entity Scanner | rot `scanner` → `notFound` (var `cell:///ConferenceNearbyRadar` ikke registrert; EntityRadar-arbeidet flyttet den ett hakk) |

De to UI-testene `testArendalsukaPromptOpensParticipantProgram` og
`testButterpopStudioLaunchesFromHAVEN` feiler mot samme staging-vert.

### Siste kjøring, 2026-08-22

| | |
| --- | --- |
| CellProtocol `swift test` | 994 tester, 0 feil |
| CellScaffold `swift build` | OK |
| Binding macOS / iOS-sim / iOS-enhet | BUILD SUCCEEDED |
| Binding Swift Testing | 426 tester i 29 suiter, alle grønne |
| Binding XCTest | kun `testEveryOfferedCatalogConfigurationHasReadableRoots`, med de fire flatene over |
