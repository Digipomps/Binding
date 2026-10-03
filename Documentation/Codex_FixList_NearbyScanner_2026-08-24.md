# Codex-retteliste: nearby scanner — 2026-08-24

## STATUS 2026-08-24, etter Codex-runden

| # | Feil | Status |
|---|---|---|
| F1 | `probeResult`/`disclosurePolicy` lekker gjennom agreement-malen | **Rettet** — begge `ensureGrant` fjernet |
| F2 | 200-byte-vakten målte mot `"pending"`-UUID | **Rettet** — `sessionUUID` genereres først og deles; `ScannerService.init` tar `sessionUUID: String? = nil` |
| F3 | `.probed` kunne ikke gå tilbake til `.probing`; `.probing` var en felle | **Rettet** — `.probing: [.probed, .beaconMatched]`, `.probed: [.contactRequested, .probing]`, med tester |
| F4 | Gjenoppdagelse nullstilte peer-tilstand | **Rettet** — `isNewPeer`-sjekk før ny tilstandsmaskin |
| F5 | Uskyndet delt tilstand på tvers av tre køer | **Rettet** — serielt `stateQueue` med `DispatchSpecificKey`-reentransvakt mot deadlock |
| F6 | `NearbyEntityKind` manglet `unspecified` | **Rettet** — `case unspecified = "u"` |

**Alle seks er rettet.** Målt:

```
swift test --disable-sandbox --filter "Nearby|ScannerService|PerspectiveCellMatchPayload|EntityScannerCell"
→ Executed 38 tests, with 0 failures (0 unexpected) in 0.360 seconds
```

Koden kompilerer — testkjøringene bygger hele pakken.

**Alt ligger ucommittet** på `claude/perspective-entities-invite-20260822`.

### UTENFOR SCOPE — krever din beslutning

Codex endret også `Sources/CellBase/Cells/CellResolver/CellResolver.swift`
(+30 linjer), som ikke sto på rettelisten. Endringen er en innstramming:
`schemePreference == .automatic` faller nå bare tilbake til usikret `ws://` for
loopback og `.local`-verter:

```swift
private func allowsAutomaticInsecureWebSocket(for host: String) -> Bool {
    guard CellBase.allowsInsecureWebSockets else { return false }
    let normalizedHost = normalizedHostKey(host)
    return normalizedHost == "127.0.0.1" || normalizedHost == "::1"
        || normalizedHost == "[::1]" || normalizedHost == "localhost"
        || normalizedHost.hasSuffix(".local")
}
```

Tidligere ga `allowsInsecureWebSockets` klartekst mot **enhver** vert. Dette er
en reell sikkerhetsforbedring, men det er også en atferdsendring: et
utviklingsoppsett som bruker `ws://` mot en LAN-IP (`192.168.x.x`) vil nå bli
tvunget til `wss://` og feile. Sjekk om noe i staging-oppsettet ditt gjør det før
du committer.

### Gjenstår

1. **Hele testsuiten.** 997 tester. Jeg fikk ikke kjørt den herfra — hver
   Codex-MCP-kall kuttes ved 60 sekunder, og selv en firedel av suiten bruker
   lengre tid. Kjør fra terminal:
   ```
   cd /Users/kjetil/Build/Digipomps/HAVEN/CellProtocol
   swift test --disable-sandbox 2>&1 | grep -E "failed|Executed [0-9]+ tests" | tail -20
   ```
   Se særlig etter regresjoner i CellResolver-testene på grunn av endringen over.
2. **`xcodebuild` av Binding-targetet.** Aldri kjørt etter iOS 26.1 → 18.0.
   Dette er den viktigste enkeltmålingen som gjenstår.
3. **To iPhone-er i samme rom.** Akseptansekriteriet: peer B synlig på peer A sin
   radar med overlapp-antall og entitetstype, før noen tilkobling.

**Merk om verktøyet:** avbrutte `swift test`-kall etterlater foreldreløse
`swift-test`-prosesser som slåss om byggelåsen og får alle senere kall til å
henge. `pkill -f swift-test` rydder.


Implementasjonen fra `Codex_Handoff_NearbyPurposeBridge_2026-08-20.md` er på plass
og i hovedsak riktig: beacon, probe-aggregat, policy, invitasjonskø, per-peer
tilstandsmaskin og 30 tester over 6 filer. Auditen fant seks feil. De er små,
men to av dem er sikkerhetsrelevante.

Alt ligger **ucommittet** i `CellProtocol` på branch
`claude/perspective-entities-invite-20260822`. Rett først, commit så.

**Produktbeslutning fra Kjetil 2026-08-24:** probe skal bli der den er — den
fyrer etter `connected`, altså etter godkjent invitasjon. Beacon-overlapp regnes
lokalt før tilkobling og driver radaren alene. Speccens formulering «automatisk
ved overlapp, uten å vekke brukeren» gjelder **beacon-overlapp**, ikke probe.
Ikke bygg en egen probe-økt før invitasjon. Oppdater ordlyden i seksjon 3.2 i
handoff-doket så den slutter å motsi koden.

---

## F1 — `probeResult` og `disclosurePolicy` lekker gjennom agreement-malen

**Alvorlighet: høy. Dette er orakelet vi lukket, gjenoppstått ett trinn opp.**

`EntityScannerCell.swift:122-123`:

```swift
self.agreementTemplate.ensureGrant("r---", for: "disclosurePolicy")
self.agreementTemplate.ensureGrant("r---", for: "probeResult")
```

`probeResult`-getteren (`:277-288`) returnerer hele kartet, nøklet på alle
remote-UUID-er, inkludert `.detail`-resultater med refs i klartekst. Enhver peer
som slipper inn gjennom agreement-malen kan dermed lese de eksakte refsene du
godkjente **for en annen peer** — og via `disclosurePolicy` hele din
`beaconPurposeRefs`, `beaconInterestRefs` og `probeDisclosureRefs`.

**Rettelse:** fjern begge fra `agreementTemplate` slik at de forblir eier-bare.
Hvis `probeResult` må være lesbar for en peer, filtrer getteren til kun den
forespørrende peerens eget UUID — ikke hele kartet.

**Test:** en peer med agreement-tilgang skal ikke kunne lese en annen peers
`.detail`-refs, og ikke kunne lese `disclosurePolicy` i det hele tatt.

---

## F2 — 200-byte-vakten måler feil streng

**Alvorlighet: middels. Grensen vi hevder å håndheve, håndheves ikke.**

`EntityScannerCell.swift:349-352`:

```swift
let beacon = makeBeacon(policy: disclosurePolicy, sessionUUID: "pending")
service = ScannerService(owner: requester, serviceDicoveryInfoDict: beacon.encodeToDiscoveryInfo())
localBeacon = makeBeacon(policy: disclosurePolicy, sessionUUID: service.mySessionUUID)
```

Størrelsesvakten kjører mot `uuid = "pending"` (7 byte). `ScannerService.init`
overskriver etterpå med en ekte 36-tegns UUID. **Hver annonsert record er 29 byte
større enn det som ble målt.** Testen `NearbyBeaconTests.swift:68` måler 175 B
for en full policy — den reelle recorden er da ~204 B, altså allerede over vår
egen grense.

**Rettelse:** bygg beaconet med den ekte sesjons-UUID-en før encoding. Enten ved
å opprette `ScannerService` først og bygge beaconet etterpå, eller ved å generere
sesjons-UUID-en utenfor og sende den inn begge steder.

**Test:** oppdater `testRealisticEightByEightPolicyEncodesToMeasured175BonjourTXTBytes`
til å bruke en 36-tegns UUID og assertere mot den faktiske grensen. Legg til en
test som fanger at et beacon bygget med kort placeholder-UUID ikke slipper
gjennom.

---

## F3 — `.probed` kan ikke gå tilbake til `.probing`

**Alvorlighet: middels. Ratebegrensningen lover et budsjett tilstandsmaskinen
forbyr å bruke.**

`NearbyPeerState.swift:38` tillater kun `probed → [contactRequested]`. Men
`probeMaxPerPeer` er 2 (`NearbyDisclosurePolicy.swift:44`). En andre manuell
`probeRequest` kaller `transitionPeer(remoteUUID, to: .probing)`
(`EntityScannerCell.swift:1252`) og kaster alltid.

I tillegg er `.probing` en felle ved pakketap: `probing → probing` er ulovlig, og
det finnes ingen timeout tilbake til `.beaconMatched`. Mistes et aggregat-svar,
eller avvises det på nonce-mismatch, står peeren i `.probing` resten av økten —
og siden `probing` bare tillater `probed` + terminaler, blokkerer et tapt
probe-svar også **kontakt**-trinnet.

**Rettelse:** tillat `probed → probing`, og legg inn en timeout fra `.probing`
tilbake til `.beaconMatched` (foreslått 15 s). Alternativt: sett
`probeMaxPerPeer = 1` og dokumenter at ett probe-forsøk er alt man får — men
timeout-fellen må uansett lukkes.

**Test:** to påfølgende probes mot samme peer er lovlig. Et tapt probe-svar
etterlater ikke peeren i `.probing`. En peer i `.probing` kan fortsatt nå
`.contactRequested` etter timeout.

---

## F4 — gjenoppdagelse nullstiller peer-tilstand

**Alvorlighet: middels.**

`EntityScannerCell.swift:1074` gjør ubetinget
`peerStates[remoteUUID] = NearbyPeerStateMachine()` ved hver
`foundDevicesChanged`. MPC-browsere re-rapporterer peers de allerede kjenner. En
peer i `.connected` eller `.agreementSigned` faller dermed tilbake til
`.discovered`.

**Rettelse:** opprett kun ny tilstandsmaskin hvis `peerStates[remoteUUID] == nil`.
Ellers behold eksisterende og oppdater bare beacon-overlappet.

**Test:** to `foundDevicesChanged` for samme remoteUUID etterlater tilstanden
uendret.

---

## F5 — uskyndet delt tilstand på tvers av tre køer

**Alvorlighet: høy for flerpeer-testing. Dette er nøyaktig scenarioet
per-peer-arbeidet skulle fikse.**

`ScannerService` er verken en actor eller `@MainActor`, men:

- `pendingInvitations` skrives fra MPC-annonsørens delegatkø (`receiveInvitation`),
  fra `DispatchQueue.main` (timeout-`DispatchWorkItem`, `:395-404`), og fra
  cellens async-kontekst (`respondToInvitation`, `:371`).
- `bridgeSetupTasks` / `bridgeDelegatesByRemoteUUID` i `setupBridge` (`:429-442`)
  har en check-then-insert som ikke er atomisk. To `.connected`-callbacks for
  ulike peers kan interleave.

Under Swift 5 er dette et ekte datakappløp. Under Swift 6 strict concurrency er
det en kompileringsfeil.

**Rettelse:** legg all delt mutabel tilstand bak én seriell `DispatchQueue`, eller
merk klassen `@MainActor`. Velg det som passer prosjektets øvrige mønster — sjekk
hvordan andre CellApple-klasser gjør det før du bestemmer.

**Test:** kan ikke testes deterministisk. Kjør i stedet ThreadSanitizer på
to-enhets-scenarioet og rapporter om den er ren.

---

## F6 — `NearbyEntityKind` mangler `unspecified`

**Alvorlighet: lav, men den gjør standardbeaconet udekodbart.**

`ScannerService.swift:304` annonserer `"k": "u"`, men `NearbyEntityKind`
(`NearbyBeacon.swift:5-11`) har ingen `u`-case. `NearbyBeacon.init?(discoveryInfo:)`
returnerer derfor `nil` for hvert eneste standardbeacon. Det degraderer til
«ingen beacon», som er trygt, men det var ikke meningen.

**Rettelse:** legg til `case unspecified = "u"` i `NearbyEntityKind`.

**Test:** standardbeaconet round-tripper gjennom
`encodeToDiscoveryInfo()`/`init?(discoveryInfo:)` og gir `.unspecified`.

---

## Oppryddinger — ta hvis tiden strekker til, ikke ellers

- **`NearbyDisclosurePolicy.beacon` (`:92-101`) er død og farlig.** Den lager et
  **tilfeldig** `sessionUUID` og brukes ikke; `EntityScannerCell.makeBeacon`
  (`:441-449`) duplikerer kroppen med den ekte UUID-en. Et beacon med tilfeldig
  UUID ville aldri matche en probe. Slett den ene.
- **`bridgeDelegate` er fortsatt en global last-writer-wins-peker** (`:190`).
  Inngående ruting bruker riktig `bridgeDelegatesByRemoteUUID` (`:918`), men
  `identityVault(for:)` (`:851`) går via den globale — så med to peers kan vaulten
  utledes fra feil bridge. Kommentaren på `:188-189` erkjenner det.
- **`ScannerPeerTransport.new()` (`:92-94`)** returnerer
  `ScannerService(owner: Identity())`, som bygger en hel ny MCPeerID + advertiser
  + browser som bieffekt av en statisk fabrikk. Kalles den noen gang, får du en
  fantom-radar. Vurder å la den kaste i stedet.
- **`stop()` tømmer ikke `foundPeersDict`/`reversedFoundPeersDict`**, så en
  stoppet service svarer fortsatt på oppslag mot foreldede peers.
- **`transitionPeer` på en ukjent peer** (`:2386-2388`) kaster
  `TransitionError.illegal(from: .lost, …)` med en oppdiktet `from`. Feilrapporten
  blir misvisende. Bruk en egen `.unknownPeer`-feil.
- **`import CryptoKit` er ubetinget** i `NearbyBeacon.swift:2`. CellApple er de
  facto Apple-only i dag, men dette er nok en vegg hvis noen forsøker Linux igjen.

---

## Maskinvare — verifisert, ingen retting nødvendig

Auditen bekreftet at kapabilitetsgatingen er riktig:

- `platformSupportsNearbyPrecision` (`ScannerService.swift:149-155`) er
  `NISession.isSupported` på iOS, `false` ellers.
- `NISession`, `NIDiscoveryToken`, `NINearbyPeerConfiguration` refereres kun
  innenfor `#if os(iOS)`. macOS/visionOS får `Any?`-shims (`:222-230`), hele
  `NISessionDelegate`-konformansen er `#if os(iOS)` (`:964`).
- På en iOS-enhet uten UWB (iPhone SE, eldre iPad) sjekker `startup()`
  (`:602-608`) `supportsNearbyPrecision` **før** `NISession()` og returnerer med
  status `precisionUnavailable`. Innkommende peer-tokens er også gated
  (`:891-896`). Ingen krasj, og det er et **høylytt** no-op, ikke et stille.
- **Hele avsløringsstigen er uavhengig av UWB.** Ingenting i den nye koden rører
  `NISession`. Beacon, probe, invitasjon og kontakt virker identisk på en iPad
  uten UWB og på macOS. UWB gir kun avstand og retning på toppen.

Det betyr at «funksjonell på enheter med støttende maskinvare» allerede er
oppfylt i design: MPC er gulvet, UWB er en tilleggsgevinst.

---

## Verifikasjon

Rapporter faktiske tall:

1. `swift build` i CellProtocol — ren?
2. `swift test --filter Nearby` og `--filter PerspectiveCellMatchPayload` —
   antall tester, antall passerende, tid.
3. Hele suiten — ingen regresjoner i de 25 Agreement-testene eller andre.
4. `xcodebuild` av Binding-targetet. Denne har aldri vært kjørt etter
   iOS 26.1 → 18.0-nedjusteringen. **Det er den viktigste enkeltmålingen.**
5. Faktisk annonsert `discoveryInfo`-størrelse i byte etter F2, med ekte UUID.
6. Deretter: to iPhone-er i samme rom. Akseptansekriteriet er at peer B vises på
   peer A sin radar **med overlapp-antall og entitetstype, før noen tilkobling**.
