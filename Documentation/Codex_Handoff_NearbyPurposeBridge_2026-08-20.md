# Codex-handoff: Nearby-broen — annonsering, gradert avsløring og policy — 2026-08-20

Oppdragsgiver: Kjetil. Skrevet av Claude etter kildelesning i
`CellProtocol/Sources/CellApple/EntityRadar/`, `Sources/CellApple/PurposeAndInterest/`,
`Binding/BootstrapView.swift` og `CellScaffold/Sources/App/Cells/ContactEndpoint/`.

**Ingenting i dette dokumentet er verifisert mot en kjørende to-enhets-økt.**
Alle linjenumre er lest 20. august 2026 og kan ha flyttet seg. Bekreft hver
diagnose i koden før du endrer den.

---

## 0. Forutsetning: rebase før første linje kode

**Lokal `CellProtocol/main` er 2 foran og 3 bak `origin/main`.** Det er en ekte
gaffel, ikke etterslep. Ingen av arbeidspunktene under skal påbegynnes før den er
saneret. De tre commitene som mangler treffer dette oppdraget direkte:

| Commit | Hva | Hvorfor det angår oss |
|---|---|---|
| `fd8c8bc` (#22) | Håndterer create/register-race for `scaffoldUnique` i `createAndRegisterCell` | Nearby-broen registrerer navngitte emit-celler per peer. To peers som kobler samtidig er nøyaktig racet #22 fikser. Uten den bygger vi flerpeer-støtte på en kjent bug. |
| `135d3c0` (#23) | Ny `SkeletonElement.NavigationBar` — **elementtypene er 24, ikke 23** | Seksjon 5 sa «de 23 som finnes holder». Tallet var utdatert i det øyeblikket det ble skrevet. |
| `fc259fd` (#21) | `SkeletonModifiers.wrap` + `FlowLayout` for ekte flex-wrap | Overlapp-chips på radarkortene (arbeidspunkt E14) er nøyaktig dette. Uten `wrap` må vi jukse med `Grid` og få uniform kolonnebredde. |

Rekkefølge: rebase → bygg → kjør testene → grønn baseline → så arbeidspunkt A1.

Bygg-baselinen mangler også. Nedjusteringen fra iOS 26.1 til 18.0 i
`Binding.xcodeproj` ligger ucommittet og er aldri bygget. Se
`Deploy_Handoff_Dirty_Trees_2026-08-20.md` i samme mappe. **Ikke start
implementasjon på et tre som ikke bygger** — da vet vi ikke om en feil er vår
eller arvet.

---

## 1. Målet

HAVEN har to fungerende halvdeler som ikke snakker sammen:

- **Nearby-radaren** (`ScannerService` + `EntityScannerCell`) finner kropper i
  rommet, men vet ikke hva de vil.
- **Formål/interesse-matching** (`PerspectiveCell.matchPayload`) og
  kontaktregisteret (`ContactRegistryCell` i CellScaffold) vet hva folk vil, men
  kjører enten først etter full tilkobling, eller bare på serveren.

Oppdraget er å koble dem, gjennom en **gradert avsløringsstige** der hvert trinn
gir litt mer informasjon mot litt mer forpliktelse, og der hele stigen styres av
en policy som er **streng i utgangspunktet**.

Stigen:

| Trinn | Kanal | Hva avsløres | Krever |
|---|---|---|---|
| 0 — Beacon | MPC `discoveryInfo` | Ugjennomsiktige tokens for formål/interesser + entitetstype + kontekst | Brukergodkjent policy |
| 1 — Probe | MPC bridge, før identitet | Et policy-avgrenset utvalg formål/interesser i klartekst | Automatisk ved token-overlapp |
| 2 — Kontaktforespørsel | MPC bridge, signert | Identitet, nøkler, full perspektiv-snapshot, encounter-proof | Eksplisitt brukerhandling begge veier |
| 3 — Agreement | Admission-stien i `GeneralCell` | Grants, conditions, varighet | Eksplisitt signering |

Trinn 2 og 3 finnes langt på vei allerede. Trinn 0 og 1 finnes ikke.

---

## 2. Dagens tilstand — de fire konkrete hullene

### 2.1 Annonseringen finnes, lesingen finnes ikke

`EntityScannerCell.startConnectService` (`EntityScannerCell.swift:243-262`) henter
`LobbyCell.purposes` og sender dem inn som `discoveryInfo`:

```swift
if let infoDict = try await lobbyPublicPurposes(requester: requester) {
    service = ScannerService(owner: requester, serviceDicoveryInfoDict: infoDict)
}
```

Mottakersiden kaster dem (`ScannerService.swift:489-510`):

```swift
func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
    guard let remoteUUID = info?["uuid"] else { ... }
    // if discovery info is interessting add peer      ← selve hullet
    foundPeersDict[remoteUUID] = peerID
```

`info` brukes kun til `uuid`. Delegatsignaturen
`foundDevicesChanged(manager:foundDevice:remoteUUID:)` (`ScannerService.swift:38`)
har ikke plass til resten, så den kan ikke propageres uten en signaturendring.

Konsekvens: formålsmatch skjer først i `buildEncounterRecord`
(`EntityScannerCell.swift:546`), altså **etter** full MPC-tilkobling *og* signert
kontaktutveksling. Man må håndhilse på hele rommet for å finne ut hvem man ville
snakke med.

### 2.2 `discoveryInfo` bærer prosa, og sprenger TXT-recorden

`LobbyCell.purposes` er `[String: String]` — formåls-id → **fritekstbeskrivelse**
(`LobbyCell.swift:19-95`). `MCNearbyServiceAdvertiser` legger `discoveryInfo` i en
Bonjour TXT-record. Per [RFC 6763 §6.1](https://www.ietf.org/rfc/rfc6763.txt) er
hver key/value-streng begrenset til 255 byte, og hele recorden bør holdes langt
under 1300 byte for å få plass i én pakke.

To feil samtidig:

- **Størrelse.** Én setning per formål sprenger budsjettet raskt. Advertising
  feiler eller trunkeres stille.
- **Personvern.** Koden anonymiserer peer-navnet omhyggelig fem linjer over
  (`privatePeerDisplayName`, `ScannerService.swift:88-98`) og kringkaster så
  formålsbeskrivelsene i klartekst til alle innen rekkevidde.

### 2.3 Invitasjoner auto-aksepteres

`ScannerService.swift:468-478`:

```swift
func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
    guard reversedFoundPeersDict[peerID] != nil else { ... invitationHandler(false, nil); return }
    invitationHandler(true, self.mcSession)
}
```

Enhver peer browseren har sett blir sluppet inn uten brukergodkjenning. Dette er
allerede identifisert som punkt 6 i seksjon 4 av
`Binding/Documentation/HAVEN_ScopeGrammar_and_NearbyBridge_2026-08-19.md`, og er
både en 4.7.3-eksponering og feil produktatferd.

### 2.4 Radaren er de facto én-til-én

`bridgeReady` er én global `Bool` (`ScannerService.swift:559`). `setupBridge` blir
no-op for peer nummer to. `stop()` nullstiller flagget, men rydder verken
`bridgeDelegate` eller de navngitte emit-cellene som ble registrert med
`resolver.registerNamedEmitCell(name: remoteUUID, …)` (`:578`). Start/stopp-sykluser
lekker registreringer.

---

## 3. Design

### 3.1 Trinn 0 — `NearbyBeacon`

Ny, liten, verifiserbar datastruktur som er det eneste som noensinne går ut i
`discoveryInfo`.

**Nøkler (korte med vilje — hver byte teller):**

| Nøkkel | Innhold | Budsjett |
|---|---|---|
| `uuid` | sesjons-UUID, som i dag | 36 B |
| `v` | beacon-versjon, `"1"` | 1 B |
| `k` | entitetstype: `p`/`o`/`l`/`e`/`a` | 1 B |
| `c` | kontekst-token (arrangement), 8 hex | 8 B |
| `pt` | formåls-tokens, `.`-separert, maks 6 × 8 hex | ≤ 53 B |
| `it` | interesse-tokens, samme form | ≤ 53 B |

**Token-avledning.** For en kanonisk ref `purpose://klimatilpasning`:

```
token = first 8 hex chars of SHA256(canonicalRef)
```

**Hvorfor 8 hex og ikke 6** (endret etter Codex' gjennomgang 2026-08-20): 6 hex er
24 bit. En konferanse med 500 deltakere à 12 tokens gir 6 000 tokens i rommet, og
med 24 bit er en kollisjon da praktisk talt sikker. 8 hex gir 32 bit og flytter
problemet ut av det sannsynlige. Færre og bredere tokens er riktigere enn flere
og smalere — derfor maks 6 per akse, ikke 8.

**Kollisjon er ikke bevis.** Token-overlapp er *utelukkende et hint om hvem det
kan være verdt å spørre*. Det skal aldri i seg selv gi kontakt, tillit, tilgang
eller Agreement. Skriv den regelen som en kommentar i `NearbyBeacon.overlap` så
den ikke går tapt.

Kanonisk ref er utgangen fra `PerspectiveCell.portableRef`/`slugify`
(`PerspectiveCell.swift:330-356`) — den samme funksjonen begge sider allerede
bruker. Gjenbruk den; ikke skriv en ny slugify.

**Vær ærlig om hva dette er.** Trunkerte usaltede hasher over et lite offentlig
vokabular er trivielle å brute-force. Dette er **obfuskering mot tilfeldig
sniffing, ikke konfidensialitet**, og det skal stå i klartekst i koden og i
samtykke-teksten til brukeren. Skriv ikke «kryptert» eller «privat» noe sted.

En reell forbedring finnes som oppfølging, ikke i v1: salte tokenene med
kontekst-tokenet (`SHA256(contextRef + canonicalRef)`), slik at bare de som vet
at de er på Arendalsuka kan regne ut treff. Det koster kryssbarhet mellom
kontekster og bør besluttes separat.

**Størrelsesvakt.** `NearbyBeacon.encodeToDiscoveryInfo()` skal:

1. beregne total UTF-8-størrelse av alle nøkler + verdier
2. droppe tokens fra halen av `it`, så `pt`, til totalen er ≤ **200 byte**
3. logge nøyaktig hva som ble droppet via `CellBase.diagnosticLog(…, domain: .flow)`
4. aldri droppe `uuid`, `v` eller `k`

200 byte er valgt konservativt, ikke fordi Apple oppgir en eksakt grense — de
gjør ikke det. Ikke påstå en grense vi ikke kan sitere.

**`NearbyEntityKind`.** Ny enum, med vilje minimal:

```swift
public enum NearbyEntityKind: String, Codable, CaseIterable {
    case person = "p"
    case organization = "o"
    case place = "l"        // POI / venue
    case event = "e"
    case agent = "a"        // butler/agent som annonserer på vegne av noen
}
```

Dette er **første gang entitetstype finnes i matchestien i det hele tatt** — jeg
fant ingen `EntityKind`/`entityType`-enum noe sted i `Sources/CellBase` eller
`Sources/CellApple`. `EntityRepresentation` mangler også et slikt felt
(`EntityRepresentation.swift:500`).

**Ikke** gjør `PerspectiveCell.matchPayload` typebevisst i denne runden. Bær
typen i beaconet og i `NearbyEntity` så UI kan filtrere og stigen kan ha ulike
regler per type — en møteplass eller organisasjon kan beacone permanent, et
menneske må samtykke per økt. Typebevisst scoring er et eget oppdrag.

### 3.2 Trinn 1 — probe

Når to beacons overlapper, skal den ene kunne be om litt mer, uten å avsløre
identitet og uten å vekke brukeren.

**Rettet etter Codex' gjennomgang 2026-08-20.** Første utkast lot probe-svaret
returnere eksakte refs automatisk. Det var feil, og feilen er verdt å forstå
før du implementerer:

> Token-rommet er offentlig. En angriper kan enumerere hele vokabularet, beacone
> alle tokens, og høste eksakte refs fra alle i rommet — automatisk, uten å
> avsløre noe selv. Asymmetrien er hele problemet: ærlige peers avslører kun ved
> ekte overlapp, angriperen avslører ingenting og får alt.

Ratebegrensning løser ikke dette; den senker bare hastigheten. Nonce og
replayvern løser det heller ikke — en aktiv angriper prober bare på nytt med
friske nonces. Derfor endres selve svaret:

**Automatisk probe-svar er aggregert, aldri eksakt.**

| Nivå | Utløses av | Innhold |
|---|---|---|
| `probeAggregate` | automatisk, ved overlapp | antall treff per akse, bøttet (`1`, `2`, `3+`), og entitetstype. **Ingen refs.** |
| `probeDetail` | ett eksplisitt trykk fra brukeren | refs fra `probeDisclosureRefs` som faktisk overlapper, i klartekst med visningsnavn |

Aggregatet gir ~2 bits per probe i stedet for en full ref-liste, og det er nok
til å drive UI-et: «3+ felles formål» er akkurat det brukeren trenger for å
bestemme seg for om det er verdt å trykke. Bekvemmeligheten er beholdt, orakelet
er borte.

Keypaths på `EntityScannerCell`:

- `probeRequest` (set, `-w--`) — `{ remoteUUID, requestId, nonce, reasonTokens }`
- `probeAggregate` — automatisk svar etter policy, uten UI
- `probeDetail` (set) — krever eksplisitt brukerhandling på **begge** sider
- `probeResult` (get, `r---`) — det som kom tilbake, per remoteUUID

Harde krav Codex ba om, alle adoptert:

- **Sesjonsbundet nonce og `requestId`** på hver probe. Duplikat `requestId`
  innen samme sesjon avvises.
- **Replay-/duplikatvern**: et svar som allerede er sendt for et `requestId`
  sendes ikke på nytt.
- **Maksimal payload-størrelse** på både request og respons. Avvis, ikke
  trunker.
- **Utløpskontroll i begge ender** — policyens `expiresAt` sjekkes både før
  sending og før svar. En utløpt policy svarer ikke.
- **Sletting ved `stop()` og ved utløp**: all probe-tilstand, alle nonces og alle
  `probeResult` tømmes.
- Kun til peers hvis beacon overlapper (`probeMode == .onOverlap`).
- Ratebegrenset: maks N probes per peer per økt, maks M totalt per minutt.
  Fortsatt nyttig, men ikke lenger den bærende beskyttelsen.
- Probe-utveksling persisteres **ikke** som encounter-proof. Den er flyktig.

### 3.2b Per-peer tilstandsmaskin

Codex påpekte at speccen manglet dette, og den har rett — «`bridgeReady` per
peer» er ikke en spesifikasjon. Definer én eksplisitt maskin, én instans per
`remoteUUID`:

```
discovered → beaconMatched → probing → probed
           → contactRequested → contactAccepted → connected
           → agreementPending → agreementSigned
                                    ↓ (fra hvilken som helst tilstand)
                                  lost / rejected / expired
```

Ulovlige overganger skal kaste, ikke logge og fortsette. Tilstanden eies av
`EntityScannerCell`, ikke av `ScannerService` — transporten skal ikke kjenne
til Agreement.

### 3.3 Trinn 2 — formell kontaktforespørsel

Finnes allerede: `requestContact` / `acceptContact` /`buildEncounterRecord`
(`EntityScannerCell.swift:183-200`, `:325-500`, `:546`). Signerer med
`Identity.sign`, verifiserer motparten, lagrer encounter-proof under
`proofs.encounters.<id>` i EntityAnchor og relasjonen under
`relations.identities.<uuid>`.

Det som må endres:

- `didReceiveInvitationFromPeer` skal ikke auto-akseptere (se 2.3). Ny
  delegat-callback `invitationReceived(manager:peerID:remoteUUID:)`, kø i
  `pendingInvitations`, og en ny keypath `respondToInvitation` som tar
  `{ remoteUUID, accept: Bool }`.
- Forslag om å sende kontaktforespørsel skal komme fra
  `beaconOverlapCount >= policy.minimumOverlapForSuggestion`, aldri automatisk
  sendes. `contactRequestMode` default er `.manualOnly`.

### 3.4 Trinn 3 — Agreement

Admission-stien finnes: `GeneralCell.addAgreement(_:for:authorizedBy:)`
(`GeneralCell.swift:1246-1340`) med `agreementDerivedFromTemplate`
(`:1377-1404`), som krever at grants er en delmengde av malens og at
`authorizationPolicyBinding` er identisk. `Contract.signed(...)` gir en
issuer-signert snapshot.

**Merk begrensningen og ikke lov rundt den:** `Contract` er issuer-only og
subject-bound av design — `Contract.swift:18-21` sier det eksplisitt, og
`Agreement.sign(identity:)` (`Agreement.swift:231-236`) er en tom stub. Bilateral
signatur finnes ikke. Nearby-flyten skal derfor beskrive dette som «du signerer
din side», ikke som «dere signerte sammen».

Denne delen er avhengig av Agreement-verktøyoppdraget som går i egen tråd. I
denne omgangen: definer `agreementTemplateRef` i policyen og en tydelig
overleveringsgrense, men ikke bygg Agreement-UI her.

### 3.5 Policyen

Ny fil, `CellProtocol/Sources/CellApple/EntityRadar/NearbyDisclosurePolicy.swift`.

```swift
public struct NearbyDisclosurePolicy: Codable, Equatable {
    public enum ProbeMode: String, Codable { case off, onOverlap, always }
    public enum ContactRequestMode: String, Codable { case manualOnly, suggestOnOverlap }

    public var schema: String            // "cellprotocol.nearby.disclosurePolicy.v1"
    public var beaconEnabled: Bool       // default false
    public var entityKind: NearbyEntityKind
    public var beaconPurposeRefs: [String]
    public var beaconInterestRefs: [String]
    public var contextRefs: [String]
    public var probeMode: ProbeMode      // default .onOverlap
    public var probeDisclosureRefs: [String]
    public var probeMaxPerPeer: Int      // default 2
    public var probeMaxPerMinute: Int    // default 12
    public var contactRequestMode: ContactRequestMode  // default .manualOnly
    public var minimumOverlapForSuggestion: Int        // default 1
    public var agreementTemplateRef: String?
    public var approvedAt: TimeInterval?
    public var expiresAt: TimeInterval?  // default: approvedAt + 8t
}
```

**Streng i utgangspunktet.** `NearbyDisclosurePolicy.strict` er standardverdien og
har `beaconEnabled = false`, tomme ref-lister, `probeMode = .off`. Ingenting går
ut før brukeren har godkjent.

**Formål hentes fra aktivt Perspective, men velges eksplisitt.** Les kandidatene
fra `perspective.query.activePurposes` og `advertisedPurpose`
(`PerspectiveCell.swift:873-905`). Presenter dem i en samtykkeflate som viser
**nøyaktig hva som vil kringkastes** — inkludert at det er tokens, og at tokens
kan brute-forces. Ingen forhåndsavhukede bokser. `approveBeacon` skal ta imot
den eksplisitt valgte listen, ikke et «godkjenn alt»-flagg.

**Policyen utløper.** `expiresAt` default `approvedAt + 8 timer`. En glemt
beacon som står på i ukevis er den mest sannsynlige personvernsvikten i hele
designet. Når policyen utløper skal `ScannerService.stop()` kalles og brukeren
varsles.

---

## 4. Arbeidsliste

Rekkefølgen er valgt så hvert steg er verifiserbart alene.

### A. Nye filer i `CellProtocol/Sources/CellApple/EntityRadar/`

1. **`NearbyBeacon.swift`** — `NearbyEntityKind`, `NearbyBeacon`,
   `encodeToDiscoveryInfo() -> [String: String]`, `init?(discoveryInfo: [String: String])`,
   `overlap(with:) -> NearbyBeaconOverlap` (rent mengdesnitt, ingen celle-rundtur),
   størrelsesvakt.

   **Token-avledning må gjenbruke `slugify`/`portableRef` fra `PerspectiveCell`.**
   Avklart av Codex 2026-08-20: begge er `private` i dag
   (`PerspectiveCell.swift:330` og `:341`). Løft dem ut til
   `Sources/CellBase/Utilities/PortableReference.swift` som en stateless, testbar
   utility, og la `PerspectiveCell` kalle den i stedet for å beholde sin egen
   kopi. To implementasjoner av samme slugify er en garantert kilde til at to
   telefoner regner ut ulike tokens for samme formål.
2. **`NearbyDisclosurePolicy.swift`** — struct over, `.strict` som statisk
   standard, `validate() throws`, og en `redactedSummary()` for logging.

### B. `ScannerService.swift`

3. Utvid `ConnectServiceDelegate.foundDevicesChanged` med
   `discoveryInfo: [String: String]?`. Propager `info` fra
   `browser(_:foundPeer:withDiscoveryInfo:)` (`:489`) i stedet for å droppe den.
   Fjern kommentaren på `:504` når hullet den beskriver er tettet.
4. `didReceiveInvitationFromPeer` (`:468`): fjern auto-accept. Legg til
   `pendingInvitations: [MCPeerID: (Bool, MCSession?) -> Void]`, ny
   delegat-callback, og en timeout som avslår stille etter 30 s.
5. `bridgeReady: Bool` → per-peer tilstand. Verifiser at `setupBridge` faktisk
   kan kjøre for peer nummer to uten å kollidere på `bridgeDelegate`.
6. `stop()`: avregistrer emit-celler og nullstill `bridgeDelegate`. **Avklart av
   Codex 2026-08-20:** det finnes ingen navnebasert avregistrering. Bruk
   `CellResolver.unregisterEmitCell(uuid:)` (protokoll linje 17, implementasjon
   `:2433-2438`), og hold derfor rede på uuid-en til hver celle som registreres i
   `setupBridge` (`ScannerService.swift:328`). Ikke legg til en navnebasert
   variant i dette oppdraget. Merk at `#22` (se seksjon 0) endrer nabolaget her: den
   fanger `registerAtAlreadyTakenEndpoint` og gir tilbake vinneren i stedet for å
   kaste. Les den fiksen før du rører registreringsstien for flere peers.
7. `init(owner:serviceDicoveryInfoDict:)`: bytt standardverdien
   `["interest": "*"]`. Den er meningsløs i dag, men **erstatningen må ikke selv
   annonsere noe** — Codex påpekte at et «minimalt beacon» som default ville
   stride mot `.strict`. Standardbeaconet skal bære `uuid`, `v` og `k` satt til
   uspesifisert, og **ingen `pt` eller `it`**. Ingenting om brukeren går ut før
   `approveBeacon` er kjørt.

### C. `EntityScannerCell.swift`

8. `startConnectService` (`:243`): bygg `discoveryInfo` fra
   `NearbyDisclosurePolicy` + `NearbyBeacon`, ikke fra `lobbyPublicPurposes`.
   Behold `lobbyPublicPurposes` for visning **etter** tilkobling.
9. Nye keypaths: `disclosurePolicy` (get, `r---`), `setDisclosurePolicy` (set),
   `approveBeacon` (set), `probeRequest` (set), `probeResult` (get),
   `respondToInvitation` (set). Registrer explore-kontrakter for alle, i samme
   stil som de eksisterende (`:180-240`).
10. `foundDevicesChanged`: dekod peer-beacon, regn overlapp lokalt, og legg
    `entityKind`, `beaconOverlapCount`, `matchedPurposeTokens`,
    `matchedInterestTokens`, `contextToken` i event-payloaden.
11. Probe-håndtering: send/motta over eksisterende `sendScannerFlowElement`-sti
    (`ScannerService.swift:222`), med egen `FlowElement.topic`. Ratebegrensning
    her, ikke i UI.

### D. `RadarModels.swift`

12. `RadarEntityUpdate` og `NearbyEntity`: legg til `kind: NearbyEntityKind?`,
    `beaconOverlapCount: Int`, `probeDisclosure: [String]?`. `matchScore` beholdes
    for post-tilkoblings-scoren — ikke gjenbruk feltet til beacon-overlapp, de
    betyr forskjellige ting.

### E. `Binding/BootstrapView.swift`

13. `shouldShowEntityByDefault` (`:6073`): la `beaconOverlapCount > 0` være et
    synlighetskriterium, slik at rommet filtreres **før** tilkobling.
14. Radar-kortene skal vise entitetstype og overlapp-antall før tilkobling, og
    tydelig skille «beacon-overlapp» (uverifisert) fra «verifisert formålsfit»
    (etter signert proof). Dagens `fallbackPurposeSummary` (`:5205`) sier
    «Proximity only» — den skal nå kunne si hva som faktisk overlappet.
    Overlapp-tokens rendres som chips med `SkeletonModifiers.wrap` fra `#21` —
    ikke som `Grid`, som gir uniform kolonnebredde og ser feil ut for tekst av
    ulik lengde.
15. Samtykkeflate for `approveBeacon`. Skeleton-vokabularet holder — bruk
    `Toggle`, `List`, `Text`, `Button`. Ingen nye elementtyper.

### F. Tester

**Endret etter Codex' gjennomgang:** testene skal *ikke* samles til slutt. Alt
fra B4 til C11 endrer sikkerhetsrelevant tilstand, og en test skrevet to uker
etter koden tester det koden gjør, ikke det den skulle gjort. Skriv testen i
samme commit som arbeidspunktet. Nummereringen under er hva som må finnes når
oppdraget er ferdig, ikke en fase.

16. `NearbyBeaconTests` — token-determinisme på tvers av to «enheter», ÆØÅ og
    diakritikk gjennom slugify, størrelsesvakt dropper riktig og logger,
    round-trip `encode`/`init?`, avvisning av ukjent `v`, overlapp-regning.
17. `NearbyDisclosurePolicyTests` — `.strict` slipper ingenting ut, utløpt policy
    stopper beacon, `validate()` avviser refs som ikke finnes i aktivt
    Perspective.
18. **`PerspectiveCellMatchPayloadTests` — helt ny.** `matchPayload`
    (`PerspectiveCell.swift:634`) er den eneste matcheren som kjører i produkt og
    har i dag **null enhetstester**. Dekk: direkte formålstreff, via-interesse-rute,
    `minMatchScore`, `limit`-trunkering, dedup-nøkler, `min()*min()`-scoren, og
    slugify-kollisjoner.
19. `ScannerServiceInvitationTests` — uinvitert peer avvises, invitasjon krever
    eksplisitt svar, timeout avslår, `stop()` er idempotent.
19b. `NearbyProbeTests` — **den viktigste testfilen i oppdraget.** Automatisk svar
    returnerer aldri en ref, uansett payload. Duplikat `requestId` avvises.
    Overdimensjonert payload avvises (ikke trunkeres). Utløpt policy svarer ikke.
    `stop()` tømmer nonces og `probeResult`. Og en eksplisitt orakel-test: en
    simulert peer som beaconer *alle* tokens i vokabularet skal få aggregater og
    null refs.
19c. `NearbyPeerStateMachineTests` — hver lovlig overgang, og at hver ulovlig
    overgang kaster.
20. To-enhets manuell akseptansetest. Kan ikke automatiseres. Skriv en kort
    sjekkliste i `Binding/Documentation/` og noter hva som faktisk ble målt.

---

## 5. Begrensninger og ikke-mål

- **Ingen background modes.** MPC er forgrunnsbasert av design. `nearby-interaction`,
  `bluetooth-central` og `push-to-talk` ble fjernet med rette og skal ikke tilbake.
- **Ingen CoreLocation.** Kontekst kommer fra kalender, universal link, eller
  peer-beacon — ikke fra posisjon. Se seksjon 3 i
  `HAVEN_ScopeGrammar_and_NearbyBridge_2026-08-19.md`.
- **Ingen nye skeleton-elementtyper.** Etter rebase er det 24 (`NavigationBar`
  kom med `#23`), pluss `SkeletonModifiers.wrap` fra `#21`. Det holder. Tror du
  du trenger en 25.: si fra og stopp, ikke oppfinn en.
- **Ikke rør `MatchStrategyPlanner` eller `PurposeInterestAdjacencyIndex`.** De er
  ubrukt bibliotekkode. Å koble dem på er et eget oppdrag.
- **Ingen taksonomi-bro i denne runden.** `commons/taxonomies/` har ekte
  `broader`/`narrower`-relasjoner, men ingenting bygger bro fra `purpose.learn`
  til `purpose://learn` til et `Purpose`-objekt. Beaconet matcher eksakt på
  kanoniske refs, som i dag. Noter broen som neste oppdrag — den er det som gjør
  at «Networking» og «Network» kan treffe hverandre.
- **Ingen bilateral Agreement-signatur.** Se 3.4.
- **Ikke skriv «privat» eller «kryptert» om beacon-tokens.** Se 3.1.

---

## 6. Verifikasjon som forventes

Kjør og rapporter faktiske tall, ikke «ser riktig ut»:

1. `swift test` i CellProtocol for de nye testmålene. Oppgi antall tester og tid.
2. Full `xcodebuild` av Binding-targetet. Merk: `device_bash` har 45 s tak, så
   dette må kjøres direkte i terminal eller Xcode.
3. Mål faktisk `discoveryInfo`-størrelse i byte for en realistisk policy med 8
   formål og 8 interesser. Rapporter tallet.
4. To enheter i samme rom: bekreft at peer B vises i peer A sin radar **med
   overlapp-antall og entitetstype, før noen tilkobling er gjort**. Det er
   akseptansekriteriet for hele oppdraget.
5. Bekreft at en invitasjon fra en peer nå krever eksplisitt godkjenning, og at
   avslag ikke etterlater en halvåpen sesjon.

---

## 7. Åpne spørsmål til Kjetil

1. **Kontekst-salting.** Skal `c` (kontekst-token) brukes som salt for `pt`/`it`?
   Det gir reell beskyttelse mot brute-force, men gjør at to personer med samme
   formål i ulike kontekster ikke finner hverandre. Min anbefaling er å utsette
   det til v1 er målt i felt.
2. **Hvem eier policyen?** Ligger `NearbyDisclosurePolicy` i `EntityScannerCell`,
   i `PerspectiveCell`, eller i en egen celle? Argumentet for `PerspectiveCell`
   er at formålene bor der. Argumentet for `EntityScannerCell` er at policyen er
   transportspesifikk.
3. **Organisasjoner og steder som beaconer permanent.** En stand på Arendalsuka
   vil stå på hele dagen. Skal `expiresAt`-regelen være annerledes for
   `.organization`/`.place`/`.event` enn for `.person`? Jeg tror ja, men det er
   et produktvalg.
4. **`ContactRegistryCell`-broen.** Skal en nearby-peer man har utvekslet proof
   med automatisk bli en `ContactRegistryEntry`? I dag kaller **ingenting**
   `publishEntry` utenfor tester. Det er en egen, større kobling.
