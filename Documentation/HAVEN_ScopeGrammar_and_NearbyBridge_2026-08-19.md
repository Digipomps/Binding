# HAVEN — skalerbar scope-modell, kontekstruting og nearby-bridge

Dato: 19. august 2026
Status: designnotat + implementeringsoppdrag. Bygger på `HAVEN_PersonalButler_Audit_2026-08-19.md`.
Forutsetning: iOS deployment target er nå 18.0.

---

## 1. Korreksjon til auditrapporten

**F3 var for sterk.** Auditen sa at DiMy wallet-cellene er registrert i appens runtime. Det stemmer ikke i det innsendbare targetet: workspacet refererer bare `Binding.xcodeproj`, og app-targetet har én lokal pakkeavhengighet — `../CellProtocol` (produktene `CellBase` og `CellApple`). `DiMyCellProtocolCells` er ikke lenket inn, så `#if canImport(DiMyCellProtocolCells)` i `RootView` er falsk og registreringskoden kompileres ikke inn.

Det som fortsatt gjelder: katalogen i `ConfigurationCatalogCell` publiserer oppføringer for «DiMy Wallet Runtime» og access/entitlements-runtime med interests `["wallet", "payments", "commerce"]`. Det er metadata uten kode bak i dagens target. Det bør likevel ut av App Store-katalogen, fordi det beskriver funksjonalitet appen ikke har — og «beskriver funksjonalitet som ikke finnes» er sin egen review-risiko.

Konklusjonen om betaling står uendret: unlock via ecash er ikke mulig på iOS, og StoreKit-veien er den riktige.

---

## 2. Svaret på skalerbarhetsinnvendingen

Innvendingen er riktig. En kompilert liste over konfigurasjonsnavn skalerer ikke mot ambisjonen om at appen skal dekke all HAVEN-bruk, styrt av brukerens formål og kontekst. Anbefalingen skal derfor presiseres:

> **Lås grammatikken, ikke setningene.**

Apples faktiske bekymringer under 4.7 og 3.1 handler om hva en konfigurasjon kan **gjøre**, ikke hvor mange det finnes av dem:

- **4.7.2** — appen kan ikke eksponere native API-er til ikke-embedded software uten Apples tillatelse
- **4.7.3** — ingen deling av data eller tillatelser uten eksplisitt samtykke per tilfelle
- **3.1.1** — ingen omgåelse av IAP
- **4.7.4** — indeks med universal links, men **kun hvis** innholdet faktisk er «software that is not embedded in the binary»

Ingen av dem bryr seg om antall. Invarianten som må holde er:

> En CellConfiguration kan aldri introdusere en kapabilitet som ikke allerede er kompilert inn i binæren.

Holder den, er konfigurasjoner **data**, ikke software. Da kan serveren levere ubegrenset mange, og 4.7.4-indeksplikten utløses ikke i det hele tatt.

### Dere har allerede halve modellen

`BindingPersonalCopilotV1Policy.allowedStyleRoles` er en kompilert `Set<String>` med 40 stilroller. Det *er* en kapabilitets-allowlist, og den er riktig bygget. Hullet er at de øvrige aksene er selverklærte.

### De fire aksene som må være kompilerte

| Akse | I dag | Skal være |
|---|---|---|
| Skeleton-elementtyper | Renderer kjenner bare kompilerte typer (strukturelt sant, utestet) | Eksplisitt test som avviser ukjent type |
| Stilroller | `allowedStyleRoles`, kompilert ✓ | Uendret |
| Celleendepunkter | `approvedRemoteHosts` + **wildcard for tom host/localhost** | Kompilert sett av lokale cellenavn appen selv registrerer |
| Handlinger som krever native tillatelse | Ikke eksplisitt avgrenset | Kun native-medierte, alltid bak samtykkeport (4.7.3) |

Wildcarden er det reelle hullet: `isApprovedEndpoint` returnerer `true` for enhver `cell://`-URL uten host. En konfigurasjon kan dermed referere en hvilken som helst lokalt registrert celle.

### Bytt selverklæring med signatur

I dag:

```swift
// hasPersonalCopilotScope — konfigurasjonen erklærer seg selv godkjent
interests.contains { $0.lowercased() == appStoreScope }
```

Skal være: konfigurasjonen lastes bare hvis den er **signert med HAVENs release-nøkkel**. Interesse-tokenet beholdes som ruting-hint, men blir nødvendig og ikke tilstrekkelig.

Dette gir presis den arkitekturen dere vil ha:

- serveren kan publisere ubegrenset mange konfigurasjoner uten ny build
- appen verifiserer en signatur, ikke en streng
- review-setningen blir sann og etterprøvbar: *«Every configuration reachable in this build is first-party, cryptographically signed, and can only compose capabilities compiled into the binary. No configuration can introduce new capability, native API access, or purchase behavior.»*

Det er en **sterkere** påstand enn en navneliste, og den skalerer i motsetning til den.

### Konsekvens for review notes

Med denne modellen beskriver dere for Apple:

1. **hva som er kompilert** — elementtyper, stilroller, cellenavn, tillatelsesporter
2. **hvordan innhold autentiseres** — førstepartssignatur, én utsteder
3. **hva konfigurasjoner ikke kan** — ingen kode, ingen native API-tilgang, ingen kjøp, ingen nye kapabiliteter

Antall konfigurasjoner nevnes ikke, fordi det ikke er relevant under den modellen.

---

## 3. Kontekstruting: Arendal-eksempelet

Ideen er god og review-trygg **så lenge kontekst kun påvirker hvilken signert konfigurasjon som foreslås, aldri hva en konfigurasjon kan gjøre**. Formuler det slik i review notes, så er hele mekanismen uproblematisk.

### Ikke bruk posisjon i v1

`NSLocationWhenInUseUsageDescription` finnes ikke i prosjektet i dag, og geofencing rundt Arendal krever i praksis region monitoring, som betyr bakgrunnsposisjon, ny background mode og tung privacy-label. Det er mye kostnad for et signal dere kan få bedre og gratis.

### Bedre kontekstsignaler, rangert

| Signal | Tillatelse | Presisjon | Merknad |
|---|---|---|---|
| **Kalender** — brukeren har en Arendalsuka-oppføring | Allerede innvilget | Høyest | Du *deltar*, ikke bare *befinner deg i nærheten*. Gjenbruker `PersonalAgendaContextCell` |
| **Universal link / skannet kode** | Ingen | Eksakt | `applinks:haven.digipomps.org` er allerede på plass |
| **Nearby-peer annonserer arrangementskontekst** | Lokalt nettverk, allerede innvilget | Høy | Gjenbruker radaren; virker uten server |
| **Eksplisitt formålsvalg i chat** | Ingen | Brukerstyrt | Billigst, og mest i tråd med `purpose://`-modellen |
| Posisjon | Ny, tung | Middels | Utsett |

Kalendersignalet er strengt bedre enn posisjon: det skiller mellom å bo i Arendal og å delta på Arendalsuka. Hvis dere senere vil ha posisjon, gjør den grovkornet, `whenInUse`, og bare utløst av en eksplisitt brukerhandling.

### «Alle flater skal nås fra chat»

Dette er riktig, og det løser samtidig 4.2 Minimum Functionality — reviewer får én sammenhengende flyt i stedet for en menyskog.

Men det flytter kravet til inventarlisten: den maskingenererte inventaret må enumerere **hva chatten kan rute til**, ikke hva menyene eksponerer. Ellers gjenoppstår avviket mellom review-notat og virkelighet i ny form.

---

## 4. Nearby og bridge mellom to telefoner

### Rettet i denne runden

`NSBonjourServices` inneholdt bare `_haven-radar._tcp`. MultipeerConnectivity bruker både TCP og UDP, og `ScannerService` annonserer `HavenServiceType = "haven-radar"`. Uten `_haven-radar._udp` er oppdagelse upålitelig på iOS 14+. Begge er nå deklarert.

Apple, `MultipeerConnectivity`-rammeverkssiden:

> "Apps that use the local network must provide a usage string in their `Info.plist` with the key `NSLocalNetworkUsageDescription`. Apps that use Bonjour must also declare the services they browse, using the `NSBonjourServices` key."

`NSLocalNetworkUsageDescription` og `NSNearbyInteractionUsageDescription` er allerede på plass i byggeinnstillingene.

### Ikke legg tilbake background modes

Codex fjernet `nearby-interaction`, `bluetooth-central` og `push-to-talk`. **Det var riktig, og de skal ikke tilbake.** Apples egen dokumentasjon:

> "If the app moves into the background, the framework stops advertising and browsing and disconnects any open sessions. Upon returning to the foreground, the framework automatically resumes advertising and browsing, but the developer must reestablish any closed sessions."

MPC er altså forgrunnsbasert av design. Background modes uten reell bakgrunnsbruk er direkte avslagsgrunn. Konsekvensen for produktet er at bridgen er en forgrunnsfunksjon — begge telefoner må ha HAVEN åpen. Det passer godt med butler-til-butler-håndtrykket, som er en bevisst handling mellom to mennesker i samme rom.

### Bridge-transporten

`BridgeTransportProtocol` er liten — seks medlemmer:

```swift
public protocol BridgeTransportProtocol {
    func setDelegate(_ delegate: BridgeDelegateProtocol)
    func setup(_ endpointURL: URL, identity: Identity) async throws
    func sendData(_ data: Data) async throws
    func close() async
    func identityVault(for: Identity?) async -> IdentityVaultProtocol
    static func new() -> BridgeTransportProtocol
}
```

Dagens implementasjoner er `LightweightBridgeTransport` (WebSocket) og `VaporBridgeTransport`. Det finnes **ingen** MPC-transport ennå — MultipeerConnectivity brukes bare i `EntityRadar`. «Bytt transport» er derfor: skriv én ny konformans og registrer den for et skjema.

**Oppdrag til Codex:**

1. Ny fil `CellProtocol/Sources/CellApple/Bridging/MultipeerBridgeTransport.swift`, `MultipeerBridgeTransport: BridgeTransportProtocol`.
2. `setup(_:identity:)` tolker `mpc://<peer-token>` og etablerer/gjenbruker en `MCSession`. Behold `encryptionPreference: .required`, slik `ScannerService` allerede gjør.
3. Gjenbruk `ScannerService` sin advertiser/browser i stedet for å starte en konkurrerende annonsering på samme `serviceType`. To advertisers på `haven-radar` i samme prosess er en feilkilde — la scanneren eie oppdagelse, og la transporten be om en sesjon mot en allerede oppdaget peer.
4. Registrer via `CellResolver.registerTransport(MultipeerBridgeTransport.self, for: "mpc")`, ved siden av `registerDefaultWebSocketBridgeTransports()`.
5. `close()` må håndtere at rammeverket river sesjonen ved bakgrunn; reconnect skjer ved retur til forgrunn.
6. Invitasjon må kreve eksplisitt godkjenning på mottakersiden. `ScannerService` sin `didReceiveInvitationFromPeer` må ikke auto-akseptere for bridge-sesjoner — det er både en 4.7.3-forpliktelse og riktig produktatferd.

**Tester:** to-enhets manuell akseptanse (kan ikke automatiseres), pluss deterministiske tester for URL-parsing, avvisning av uinvitert peer, og at `close()` er idempotent.

### Flagg som må verifiseres før nearby gjøres til vekstmotor

Apples dokumentasjonsmetadata for `MCNearbyServiceAdvertiser` oppgir tilgjengelighet **«iOS: 7.0.0 – 27.0.0»**. En lukket øvre grense pleier å bety utfasing i den versjonen. Jeg har **ikke** klart å bekrefte dette mot en eksplisitt deprecation-melding fra Apple, og påstår det derfor ikke — men det må sjekkes før MPC gjøres til bærebjelken i vekststrategien.

Den gode nyheten er at arkitekturen allerede beskytter dere: når bridgen ligger bak `BridgeTransportProtocol`, kan transporten byttes til `Network.framework`/`DeviceDiscoveryUI` uten at noe over transportlaget endres. Det er verdt å bygge den abstraksjonen riktig nettopp nå.

---

## 5. Gjenstående gap

### Gjort i denne runden

- `IPHONEOS_DEPLOYMENT_TARGET` 26.1 → 18.0 i alle seks konfigurasjoner
- `_haven-radar._udp` lagt til i `NSBonjourServices`
- `Binding/PrivacyInfo.xcprivacy` opprettet, avgrenset til faktisk API-bruk: `UserDefaults` (`CA92.1`) og `FileTimestamp` (`C617.1`, `3B52.1`). Diskplass, boot-tid og aktive tastaturer er verifisert ubrukt og derfor ikke deklarert
- `ageRatingHint` default `"12+"` → `"13+"`

### Krever ett manuelt steg

- **`PrivacyInfo.xcprivacy` må legges til app-targetets Resources build phase.** Filen ligger på plass ved siden av `Info.plist`, men jeg endrer ikke `project.pbxproj` for filmedlemskap uten å kunne validere resultatet. Dra den inn i Xcode og huk av for HAVEN-targetet.

### Fortsatt åpent

| Gap | Type | Merknad |
|---|---|---|
| `MACOSX_DEPLOYMENT_TARGET` og `XROS_DEPLOYMENT_TARGET` står på 26.1 | Beslutning | Bevisst valg? Mac-rekkevidde er samme problem som iOS hadde |
| visionOS i `TARGETED_DEVICE_FAMILY = "1,2,7"` og `SUPPORTED_PLATFORMS` | Beslutning | Skal visionOS med i v1? |
| To ulike `DEVELOPMENT_TEAM` (`58VP3BNL4B`, `5UT5HQTCV9`) | P0 | Må avklares før arkivering |
| AASA-fil på `haven.digipomps.org` | P0 | Entitlements er riktige; selve `.well-known`-fila er ikke verifisert herfra |
| Signatur i stedet for selverklært scope | P0 | Seksjon 2 |
| Lokal endepunkt-wildcard | P0 | `isApprovedEndpoint` returnerer `true` for tom host |
| Maskingenerert inventar over det chatten kan rute til | P0 | Seksjon 3 |
| Butler-persistens over omstart | P0 | Fra auditen, uendret |
| Sosiale medier-spørsmål i ASC | P0 | Påkrevd fra september 2026 |
| DiMy-katalogoppføringer i App Store-katalogen | P1 | Beskriver funksjonalitet targetet ikke har |
| StoreKit 2 consumable | P1 | Når betaling skal inn |
| MPC-bridge-transport | P1 | Seksjon 4 |

### Ikke verifisert i denne runden

Ingen build eller test ble kjørt. `device_bash` har 45 sekunders tak, så full `xcodebuild` er ikke mulig herfra. Endringene i denne runden er konfigurasjon og manifest, verifisert ved inspeksjon og plist-parsing — men **overgangen fra iOS 26.1 til 18.0 må bygges og kjøres** før den er bevist. Den ene kjente iOS 26-avhengigheten i app-koden er `FoundationModels` i `ChatWorkbenchParityCells.swift:8901`, som allerede er korrekt gated med `#if canImport` og `@available(macOS 26.0, iOS 26.0, *)` og degraderer rent. `CellProtocol` har noen få `@available(iOS 26`/`27` som må kontrolleres på samme måte.
