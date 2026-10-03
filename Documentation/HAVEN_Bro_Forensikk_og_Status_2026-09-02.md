# Broen: hva som er borte, hva som virker, og hva jeg gjorde i natt

Dato: 2. september 2026, natt
Verter verifisert mot: staging og prod, begge på `e085fdc5` (redeployet 2026-09-02)
Kode verifisert mot: CellScaffold `origin/main` = `9805fa3b` (PR #198)
Rådata: `Binding/_audit-skeleton-render-20260828/forensics-20260902-230013.md`,
`ws_probe_result.txt`, `state-fetch-*.md`, `logs/`

---

## Svar på de fire spørsmålene dine

### «Kan noe ha blitt slettet i opprydningen?»

**Nesten ingenting ble slettet. Fire ruter ble avregistrert.** Det er forskjellen
som gjorde dette vanskelig å se.

Fra 1. juli til i dag er det slettet **én** fil under `Sources/` i hele
CellScaffold (`CellProtocolPublishedRuntimeCompatibility.swift`, 15. juli), og
**null** filer i CellProtocol. All brokode ligger der fortsatt. `VaporBridgehead.swift`
finnes, `AdminAuthenticatedVaporBridgeTransport.swift` finnes, `BridgeBase` finnes.

Det som forsvant er fire linjer i `routes.swift`:

| Rutesamling | Konsekvens |
|---|---|
| `VaporBridgehead` | **den generelle broen** — hver `cell://<vert>/<Celle>` i appen |
| `VaporMusicPublishingMVP` | `/mvp/music/tracks/:id/policy` — eneste vei til å endre pris på en publisert sang. 404 i dag |
| `VaporAgeProofDoorMVP` | nå `enabled: app.environment == .testing` — av i staging og prod |
| `VaporPaymentProofDoorMVP` | samme |

Derfor fant den forrige undersøkelsen «ingenting slettet» og konkluderte for
raskt: `git log --diff-filter=D` ser ikke en avregistrering. Koden overlever;
det er *inngangen* til den som er borte.

### «Betyr dette at ingen bridge funker?»

**Nei. Bromaskineriet virker. Én bestemt rute er borte.**

Jeg fullførte ekte websocket-håndtrykk mot begge verter:

| Bro | staging | prod | Tolkning |
|---|---|---|---|
| `/v1/resolver/native-porthole/Porthole/<uuid>` | **101**, så lukket **1008** | samme | virker og avviser korrekt uten kontrakt |
| `/bridgehead/<Celle>/<uuid>` | 404 | 404 | ruten finnes ikke |
| `/bridgehead/session` | 404 | 404 | multipleks finnes ikke her |
| `/palazzo-concierge/bridgehead/…` | 403 | 403 | Palazzos egen bro er oppe, avviser uautentisert |
| `browserhead/wsce/<id>` | 303 → /login | 303 | virker, krever sesjon |
| admin-vert `/bridgehead/AdminEntry/<uuid>` | 502 | — | egen driftssak, `/health/live` er 200 |

Merk 101-en: den betyr **ikke** at døra står åpen. Vapor oppgraderer alltid når
ruten mangler `shouldUpgrade`, og validerer inni handleren. Uten kontrakt lukkes
forbindelsen umiddelbart med kode 1008. Jeg sjekket dette med et råsocket-håndtrykk
nettopp fordi en naiv probe ville lest 101 som «åpen».

Så: en autentisert bro til en celle **virker i produksjon i dag**. Den er bare
bundet til én publisher (`SPROUT_NATIVE_ALLOWED_PUBLISHERS=["Porthole"]`) og krever
en kontrakt appen ikke vet hvordan den skal skaffe.

### «Identityvault-feilen kan jo være på grunn av manglende bridge»

**Nei — og jeg har beviset.** Den er uavhengig, men fra samme herdingskampanje.

`VaporIdentityVault.identity(for:makeNewIfNotFound:)` har denne porten:

```swift
guard strictRuntimeDocumentRootPath == nil else {
    if makeNewIfNotFound { logStrictRuntimeRejection(.strictRuntimeWriteProhibited) }
    return nil
}
```

`configure.swift` kaller `activateStrictRuntimeMode()` ved oppstart mot et signert
identitetsmanifest. I strict-modus nekter vaulten å lage **nye** identiteter.

Og de to 500-rutene ber om nettopp det: `VaporPersonalCopilot` mynter
`personal-copilot-v1:<tilfeldig sesjons-UUID>`, `VaporSkeletonParity` mynter
`skeleton-parity:<slug>:<tilfeldig sesjons-UUID>`. En tilfeldig UUID per
nettleser-sesjon kan aldri stå i et forhåndssignert manifest. Rutene er
arkitektonisk uforenlige med strict runtime.

**Fiksen finnes allerede i repoet.** `VaporButterpopStudio.swift:786` dokumenterer
akkurat denne feilen og løser den: ikke prøv å mynte en identitet, bruk en
cookie-scopet anonym ID for kontinuitet og rategrense, og en identitet som
allerede finnes for selve celleoperasjonen. `VaporPersonalCopilot` gjør det
allerede riktig på konfigurasjonsrutene sine via `EphemeralIdentityVault`
(`readAnonymousConfiguration`) — det er derfor de svarer 200 mens katalogruten
svarer 500. Mønsteret er etablert; det er bare ikke brukt de to stedene.

### «Har vi mistet noe viktig?»

Ja, to ting.

1. **Transparensegenskapen.** En celle over bro skal ha samme grensesnitt som en
   lokal. Uten den generelle ruten har HAVEN ingen vei til en fjern celle i det
   hele tatt, og hele desentraliseringspremisset er teoretisk.
2. **Å endre pris på en publisert sang.** `VaporMusicPublishingMVP` er
   avregistrert, så `/mvp/music/tracks/:id/policy` er 404. Uten den må en miks
   republiseres for å endre pris.

Og en tredje ting som ikke er tapt, men er verdt å vite: **oppdagelsestjenesten
lyver.** `SproutBridgeDiscoveryCompatibility.swift:172` bygger fortsatt
`/bridgehead/<publisher>/<bridge>` og deler den ut til klienter — en URL som gir
404. Testen `SproutBridgeDiscoveryRoutesTests` asserterer den strengen og er
grønn. Den koder URL-en, ikke formålet, og kunne aldri fanget dette.

---

## Palazzo og Butterpop

| | Web | I appen |
|---|---|---|
| **Palazzo** | `/palazzo-concierge/` **200** på begge verter | blokkert: egen bro under sti-prefiks svarer 403 på uautentisert håndtrykk |
| **Butterpop** | `/butterpop` **200**, `/butterpop/api/catalog` **200** | blokkert: flaten refererer `cell://staging/MusicPublishingConsole` over den døde broen |

Begge web-flatene er altså friske. Det er veien fra appen som mangler, og det er
den samme ene ruten for begge.

nginx proxyer `/palazzo-concierge/` til Python-tjenesten på `127.0.0.1:8098` med
`Upgrade`-videresending, så 403-en kommer fra Palazzo-appen selv, ikke fra nginx.
Merk også: repoets `staging_haven.conf` har ingen palazzo-blokk, men staging
serverer den likevel — levende nginx og repoets kopi har drevet fra hverandre.

---

## Hva jeg endret i natt

### CellProtocol — verifisert grønt

`CellResolver.remoteWebSocketConnectionURL` bar ikke
`CellBase.remoteWebSocketQueryItemsProvider`, selv om den legacy-stien
(`remoteWebSocketEndpoint`) og multipleks-sesjons-URL-en begge gjorde det. Det er
den dedikerte per-celle-stien appen faktisk bruker. Siden
`LightweightBridgeTransport` åpner socketen med `URLSession.webSocketTask(with:)`
og ikke kan sette headere, var URL-en eneste mulige kanal for et bevis — og den
kanalen var stengt akkurat der den trengtes.

Fjorten linjer, speiler blokken 40 linjer lenger opp i samme fil. To nye tester
i `BridgeTests.swift`. **`swift build`: grønt. Begge tester: grønne.**

### CellScaffold — skrevet og kompilerer grønt

`Sources/App/Controllers/VaporCellBridge.swift`, ny generell bro-rute.

Den viktigste avgjørelsen: **jeg fant ut at klienten allerede har vokabularet.**
`CellResolver.proveRemoteBridgePrincipal` mynter allerede en
`IdentitySigningChallenge` med domain `cellprotocol.remote-bridge`, action
`resolve`, audience `CellResolver` og endepunktet som resource — via den
offentlige `CellResolver.remoteBridgeAuthorityChallengeResource`. Beviset regnes
ut i dag og **kastes**: det brukes bare til å utlede en lokal cache-nøkkel, aldri
sendt. Serveren ber derfor om nøyaktig det beviset klienten allerede kan lage, og
kaller klientens egen resource-funksjon så de to ikke kan drive fra hverandre.
Jeg skrev først et eget vokabular og forkastet det da jeg fant dette.

To bevisveier, slik du valgte:
- **identitetsbevis** — signert `IdentitySigningChallenge`, med replay-vern via
  `CellBase.signingChallengeReplayStore`. Asymmetrisk; ingenting hemmelig i binæren.
- **Sprout-kontrakt** — verifisert signatur, utløp, subjektnøkkel og at
  `bridge_endpoint` peker på denne cellen. Beviser formål, ikke bare identitet.

Ruten har **ingen navneliste over tillatte celler**. Den beviser hvem som ringer;
cellen avgjør selv via sin `Agreement`. En liste her ville flyttet autoritet vekk
fra cellen og gjenskapt nøyaktig den driften vi nettopp gravde opp.

**Av som standard.** `HAVEN_CELL_BRIDGE_ENABLED` må settes. Å lande fila endrer
ingenting i drift før noen slår den på bevisst — det er den eneste forsvarlige
måten å gjeninnføre en rute som ble fjernet av en sikkerhetsgrunn.

`swift build --target App`: **BUILD_EXIT=0, null kompileringsfeil.** Tre runder
med feil underveis (manglende `import CellVapor`, tre manglende `Self.`), alle
rettet og bygget på nytt.

### Regresjon

- CellProtocol `BridgeTests`: **50 tester, 0 feil** — inkludert de åtte
  eksisterende `testCellResolverRemoteBridge*`-testene som dekker nettopp
  bro-oppkoblingen jeg rørte.
- CellProtocol `CellRuntimeEnvironmentTests`: **6 tester, 0 feil** — samme
  provider som endringen bruker.

Det er verifisert, ikke påstått. Men merk skillet: at det kompilerer og at
enhetstestene er grønne er ikke det samme som at broen virker mot en levende
vert. Det siste krever deploy.

---

## Det som IKKE er sant i morgen tidlig

Du ba om at alt skal virke. Dette er hva som ikke gjør det, og hvorfor.

- **Broen er ikke live.** Jeg kan ikke deploye — det blokkeres for meg uansett
  sandkasse, og står i din egen bevisledger. Ruten må inn i et image og deployes
  av deg.
- **App-mot-web-paritet er ikke verifisert.** Harnessen som finnes for nettopp
  det — skeleton-parity-fixturene — svarer 500 på begge verter på grunn av
  strict-runtime-feilen over. Den må fikses og deployes før paritet kan måles.
  Jeg vil ikke påstå paritet uten å ha målt den.
- **100 ms-kravet: 74 av 77 flater klarer det nå.** Det er ikke helt.

  Siste måling, 2026-09-02 23:44, alle 77 lokale flater gjennom appens egen
  laste- og rendersti:

  | | ved nattens start | nå |
  |---|---:|---:|
  | sum lastetid | 38 115 ms | **4 430 ms** |
  | median lastetid | 2 ms | **1 ms** |
  | flater under 100 ms | 52 av 79 | **74 av 77** |
  | flater ≥ 900 ms | 27 | **3** |
  | grønn / gul / rød | 18 / 21 / 40 | **39 / 7 / 33** |

  De tre som gjenstår er `Trusted Issuers Registry`, `Identities Access Control`
  og `Cloud Bridge Transport`, alle på ~1400 ms — samme ubrukte retry-budsjett,
  men her med `subscribeFeed: true` og en feed som aldri blir aktiv. Én årsak,
  tre flater, ikke undersøkt ferdig.

  Seks flater ble grønne uten at jeg rørte dem: de fem Apple Intelligence- og
  Entity Scanner-flatene med `catalog.matching`/`scanner.encounters`-hullet, som
  er lukket i Binding-commitene som landet mens vi jobbet. To rot-keypath-hull
  står igjen.

  **Men merk hva 100 ms måler.** Lastetid er ikke render. Render har median
  178 ms, p90 489 ms, og første meningsfulle innhold median 86 ms — og de
  tallene er SwiftUI-hosting og PNG-snapshot inne i testharnessen, ikke det en
  bruker opplever. Jeg vil ikke rapportere dem som om de var brukertid.

  De 33 røde lokalt: **26 er fjernverten** (samme manglende bro), 5 er celler
  katalogen tilbyr uten at de finnes i appen, 2 er rot-keypath-hull.

---

## Én kommando til deg

Når du har lest og godkjent formen på ruten:

```bash
cd /Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/_wt-bridge-identity-20260830
git add -A && git commit && git push -u origin claude/bridge-identity-proof-20260830
gh pr create --fill
```

CI kompilerer den. Deploy er fortsatt din.

Rekkefølgen jeg ville tatt:
1. Strict-runtime-fiksen på de to 500-rutene (Butterpop-mønsteret finnes allerede)
   — den gir deg parity-harnessen tilbake, og den er liten.
2. Bro-ruten, med `HAVEN_CELL_BRIDGE_ENABLED` av til du har sett den kjøre.
3. Slå på broen på staging, mål, og først da produksjon.

---

## Tillegg 2026-09-03: hvor feilen sitter, presist — og klientsiden lukket

**Feilen sitter i ett sted: websocket-endepunktet i CellScaffold.**
Ikke i `BridgeBase`. Ikke i transporten. Kontrollforsøket som viser det:

`native-porthole` på **samme vert, samme prosess** bygger en `BridgeBase` med
`VaporBridgeTransport` og kobler den til en celle — og den svarer 101 og lukker
korrekt med 1008 uten kontrakt. Samme `BridgeBase`, samme transport, annen rute.
Den ene virker, den andre er 404. Da kan feilen ikke ligge i det de deler.

Bekreftende bevis:
- `AdminScaffoldBridgeRoutes` bruker samme `VaporBridgeTransport` + `BridgeBase`
  og virker på sin egen vert.
- Klientsiden: `BridgeTests` 50/50 grønne, inkludert åtte
  `testCellResolverRemoteBridge*` som dekker selve bro-oppkoblingen.
- Null slettede filer i CellProtocol i hele perioden.

Feilen er én manglende `routes.grouped("bridgehead").webSocket(...)`.

### Klientsiden var også halv — nå lukket

Ruten alene hadde ikke vært nok. `CellResolver.proveRemoteBridgePrincipal`
regnet allerede ut en `IdentitySigningChallenge` for hver fjernbro og **kastet
den**: `ProvenRemoteBridgePrincipal` bar identityUUID, fingeravtrykk og
vault-referanse, men ikke selve beviset. En server som ba om bevis ville derfor
avvist appen selv med ruten på plass.

Endret i `_wt-bridge-credential-20260830`:
- `ProvenRemoteBridgePrincipal` bærer nå `authorityChallenge` og
  `authoritySignature`.
- `proveRemoteBridgeAuthority(for:logicalEndpoint:)` gjør nøyaktig de samme
  kontrollene som `IdentitySigningChallenge.proveControl`, men returnerer det
  signerte materialet i stedet for en Bool.
- Scopet er hevet til konstanter på `CellResolver`
  (`remoteBridgeAuthorityDomain/Action/Audience`) så klient og server leser
  samme kilde.
- Den dedikerte bro-URL-en bærer `bridge_proof` og `bridge_signature`.

`swift build --target CellBase`: **BUILD_EXIT=0.**
`swift test --filter BridgeTests`: **TEST_EXIT=0, 50 av 50 grønne, 0 feil** —
inkludert de åtte testene som dekker nettopp den endrede kodestien.

Kjeden er dermed hel i kode: appen signerer → URL-en bærer → ruten verifiserer →
cellen avgjør via sin `Agreement`. Det som gjenstår er commit, PR, image og
deploy — og at `HAVEN_CELL_BRIDGE_ENABLED` settes på staging først.
