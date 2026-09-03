# Lokale flater: autentisering, radar og finnbarhet — 2026-09-02

Kjetil åpnet appen og fikk «ikke autentisert mot remote» og «lokale flater
kunne ikke autentiseres». Relasjoner var ikke å finne. EntityScanner lot seg
ikke åpne, og skulle uansett se ut som en radar, ikke stablede blokker. Alle
lokale flater skulle valideres, rendre under 100 ms, og være beskrevet godt
nok til at butleren finner dem.

Meldingene Kjetil så finnes ikke i noen logg (`BindingRuntimeDiagnostics` er
kun i minne), så årsakene er lest ut av koden og bevist med diagnostikk i
test — ikke gjettet.

## Tre feil, ikke én

**1. Relasjoner var ikke i sidemenyen.** `BindingPersonalCopilotDestination`
er en hardkodet enum; `HavenRelationsWorkbench.configuration()` lå i
`personalCopilotV1MenuConfigurations()` og i ingen seksjon. En flate i lista
men i ingen meny finnes ikke. Nå: «Relasjoner» under Network, «Utvid
entiteten» under Personal, og en test som krever at *alle* destinasjoner er i
en seksjon.

**2. Avbrutt Face ID gjorde en uautentisert vault til standard.**
`IdentityVault.initialize()` returnerte uansett; `ensureBaseline()` og
`AppInitializer.initialize()` satte den som `defaultIdentityVault`;
`identity(for: "private", makeNewIfNotFound: true)` mintet en identitet uten
nøkkelmateriale; `localRegistrationStillUsableForActiveIdentity()` feilet på
eierbevis → «De lokale HAVEN-cellene kunne ikke valideres». Samtidig sa
`authenticatedRuntimeIsReady` true fordi den bare sjekket typen.

Fiks i CellApple: `IdentityVault.isAuthenticated`; `authenticatev2` kaster
når fallback svarer false eller policy ikke kan evalueres; `identity(for:)`
returnerer nil før autentisering — en vault som ikke er åpnet lager ikke
personer. Fiks i Binding/CellApple: vaulten byttes bare når autentisert.

**3. `ConfigurationCatalog` og `EntityScanner` var `scaffoldUnique`.** Én
instans, eid av identiteten som tilfeldigvis opprettet den. Enhver annen
identitet — verifikatorens, eller den autentiserte etter Face ID — fikk
`deniedNoGrant` på `matching`, `encounters`, `radar`. Porthole svelger feilen
(`try?`) og rapporterer `notFound`; verifikatoren prøver tre ganger med
timeout og bruker 1,7 s på å feile. Dokumentert som «fortsatt rødt, ikke
vårt» siden 21.08. Nå `identityUnique` som Porthole og Perspective. Katalogens
lærte formålsvekter blir eierens — det er de uansett.

## Identitetsmodellen, uttalt

Lokale flater (bare `cell:///`-referanser) lastes alltid med
**oppstartsidentiteten**, også etter Face ID. Den er varig siden 659e18a8.
`IdentityVault` (Face ID) er for staging og hemmeligheter. De er fortsatt to
personer; IdentityLink-VC-en er veien til én og ligger i køen. Det er ikke
«feil bruk av CellProtocol» at lokale flater ikke krever Face ID — det er
riktig: autentisering låser opp hemmeligheter, den skaper ikke celler.

## Radaren

`Visualization(kind: "radar")` er ny i skeleton-rendereren. Spec-en kommer
fra `EntityScannerCell.radar`, bygget av `RadarEntityLedger` — samme
aggregering som `RadarViewModel` nå bruker, så en skjerm og cellen ser det
samme. Posisjon fra avstand og peiling på enhetsdisken; ukjent peiling tegnes
som en stiplet bue, ikke som en gjettet prikk. Blipper brenner når de er
hørt og falmer med stillhet; nærmeste avstand står som ett stort tall — det
eneste noen leser på film. Sveip mens skanneren går. Trykk på en blipp
skriver `scanner.select`. Radaren poller hvert sekund mens den er på skjerm;
alle andre visualiseringer oppdaterer bare ved mutasjon, som før.

Én ny rendererkapabilitet, bestilt eksplisitt («radar eller
bevegelsessensoren i Alien»). Ingen andre skeleton-utvidelser.

## Finnbarhet

Butleren visste om en håndfull flater via nøkkelordregler. Katalogen kjenner
alle. `HavenSurfaceRelevance` (rent) scorer en flates egne ord — navn,
formål, beskrivelse, sammendrag, tags, interesser — mot det som skrives,
med norsk stavet tre måter møtende på midten («håndter» = «haandter» =
«handter»). `matching.query` på katalogen er lesende og bruker den;
`analyzeDraft` spør katalogen etter de statiske reglene, så en flate ingen
skrev regel for fortsatt blir funnet.

Auditen (`HavenSurfaceRelevance.audit`) sier hva som gjør en flate ufinnbar:
manglende eller kort beskrivelse (< 60 tegn), beskrivelse som gjentar navnet,
transliterert norsk (aa/oe uten ekte å/ø i teksten), færre enn tre
interesser, manglende sammendrag. 38 katalogstrenger fikk å/ø/æ tilbake.

## Testen som holder det

`testEveryLocalSurfaceLoadsFastIsDescribedAndFindable`: hver lokal flate
lastes varm og tas tiden på (budsjett 100 ms — Kjetils tall), beskrivelsen
auditeres, og flaten må finnes i topp 3 på en prompt laget av sin egen
beskrivelse *uten* navnet. Tabellen printes hver gang.

## Til CellScaffold

Samme audit gjelder flatene på scaffoldet, og butleren i Porthole skal bruke
samme relevans. Oppgavekø.
