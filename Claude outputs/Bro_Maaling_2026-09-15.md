# Broen målt live — 2026-09-15

Spørsmålet var «er bridge oppe nå?». Dette er målingen, ikke en lesning av koden.

WebSocket åpnet fra en ekte nettleser mot drift. Staging kjører
`app_revision 6c391437e06d5510cabe8f361c76e5baa004d7ba` = origin/main,
bygget 2026-09-14T19:45:05Z (`/health/build`).

## Svaret: broen virker. Men ikke i CellScaffold.

### Den virker — bevis

```
wss://staging.haven.digipomps.org/palazzo-concierge/bridgehead/PalazzoConciergeKnowledge/<uuid>
wss://haven.digipomps.org/palazzo-concierge/bridgehead/PalazzoConciergeKnowledge/<uuid>
```

Begge: socket **åpner**, serveren sender **`{"cid":0,"cmd":"ready"}`**, og holder
forbindelsen åpen (7 s hhv. 6 s uten close). En levende bro som snakker
protokollen, i drift, på **begge** verter.

`<uuid>`-segmentet er påkrevd — uten det (to segmenter) lukkes den med 1006.

PalazzoScaffold ligger bak sti-prefikset `/palazzo-concierge/`.

### CellScaffold har ingen bridgehead-rute

| Probe (staging **og** prod) | Resultat |
|---|---|
| `GET /bridgehead/<Celle>/<uuid>` + to varianter | **404** `{"reason":"Not Found"}` |
| `wss://…/bridgehead/<Celle>/<uuid>` | aldri åpnet, **1006** |
| `wss://…/v1/resolver/native-porthole/<pub>/<bridge>` | **åpner (101), så close 1008** |
| `wss://…/browserhead/wsce/<id>` | 1006 (FIDO-redirect) |
| `GET /sprout/bridge/discovery` | 404 |

CellScaffold har nøyaktig **to** WebSocket-ruter:

- `browserhead/wsce/:sessionId` — FIDO-beskyttet, for web-Porthole
  (`VaporBrowserhead.swift:129`)
- `v1/resolver/native-porthole/:pubId/:bridgeId` — krever Sprout-utstedt
  porthole-kontrakt (`VaporSproutResolver.swift:60`)

`routes.swift:269` har `app.webSocket("bridgehead", ":pubId")` **utkommentert**.

## Maskineriet er intakt — det er ruten som mangler

`Sources/App/Controllers/VaporBridgehead.swift` finnes fortsatt (124 linjer), med
`bridgeConfig(publisherIdentity:publisherReference:bridgeReference:transport:)`
som bygger en komplett `BridgeBase.Config`. Filens egen kommentar sier det rett ut:

> No web route is registered here; the old unauthenticated bridgehead is removed.

Og `native-porthole` beviser mønsteret i samme prosess: den bygger
`VaporBridgeTransport` + `BridgeBase` med
`identityDomain: "bridgehead:<bridgeID>:<uuid>"`. Close 1008 der er en *policy*-
avvisning — ruten og broen fungerer, kontrakten mangler.

Altså: BridgeBase virker, transporten virker, protokollen virker. Det som er
borte er én rute med autentisering foran.

## Hullet, presist

Appen har **én** vei til en fjerncelle på offentlig vert:

- `Binding/RemoteCatalogSupport.swift:23` — `secureRemoteRoute`:
  `websocketEndpoint: "bridgehead"`, `schemePreference: .wss`,
  `pathLayout: .endpointThenPublisherUUID`
- `Binding/ContentView.swift:549` — `defaultRemoteWebSocketPath = "bridgehead"`
- vert: `staging.haven.digipomps.org`

Det gir `wss://staging.haven.digipomps.org/bridgehead/<publisherUUID>`, som ikke
finnes.

Appen kan heller ikke bruke ruten som *faktisk* finnes:

```
grep -rn 'v1/resolver|portholes/access|native-porthole|sproutResolver' Binding/ Cells/
→ 0 treff
```

Den gjør ikke Sprout-dansen i det hele tatt.

De tre eneste eksplisitte `wss://`-endepunktene i appen peker alle på Palazzo —
altså på den ene broen som virker.

## Veivalget

`PDD_bridge-fase2-handshake_2026-09-04` er G1-godkjent 04.09, kontrakten validert
(`contract/validate_contract.py`, 9/9 PASS), G2 venter. Men **WP3 hardner
`native-porthole/<pubId>/session`** — den lukker ikke appens hull. Den forbedrer
en rute appen ikke bruker.

To utveier. De kan ikke begge være riktige:

**1. Autentisert bridgehead i CellScaffold.** Appen uendret. Cellen avgjør selv
via sin `Agreement`. Nærmest det uttalte formålet — en celle over bro har samme
grensesnitt som en lokal celle, og rammeverket er desentralisert.

**2. Appen over på resolver-ruten.** Ny kode i Binding: hent Sprout-kontrakt via
`/v1/resolver/portholes/access`, koble til `native-porthole`. `bridgehead` i
Binding blir legacy. Mer sentralisert — en resolver må utstede kontrakt før to
celler kan snakke sammen.

Valget er formålsdrevet, ikke teknisk. Det avgjør også hva fase 2-PDD-en skal
gjøre i P3.

## Rader til bevisledgeren

Klar til å limes inn i `CellScaffold/Documentation/ProjectControl/VIRKER_OG_VIRKER_IKKE.md`.
Ikke skrevet dit herfra: hovedtreet (459 linjer, 07.09) og worktreene (252 og 206
linjer, 09.09) har ulike versjoner av fila, og git fra mounten er forbudt.

| Påstand | Status | Bevis | Regel |
|---|---|---|---|
| Broen i HAVEN er nede | **NEI** | 2026-09-15: `wss://<vert>/palazzo-concierge/bridgehead/PalazzoConciergeKnowledge/<uuid>` åpner og serveren sender `{"cid":0,"cmd":"ready"}` på **både** staging og prod | Mål per vert og sti-prefiks, ikke per repo. Én scaffold mangler ruten; en annen svarer i prod. |
| CellScaffold eksponerer en bridgehead | **NEI** | 2026-09-15: 404 på tre HTTP-varianter, 1006 på wss, begge verter. `routes.swift:269` er utkommentert. Kun to ws-ruter finnes | Appens `defaultRemoteWebSocketPath = "bridgehead"` peker på en rute som ikke finnes. |
| Bridge-maskineriet må bygges på nytt | **NEI** | `VaporBridgehead.bridgeConfig` finnes fortsatt og bygger komplett `BridgeBase.Config`; `native-porthole` bruker samme `VaporBridgeTransport` + `BridgeBase` og gir 101 før policy-close 1008 | Det som mangler er én rute med autentisering, ikke en bro. |
| Appen kan bruke `native-porthole` i dag | **NEI** | `grep -rn 'v1/resolver\|portholes/access\|native-porthole\|sproutResolver' Binding/ Cells/` → 0 treff | Å hardne resolver-ruten løser ikke appens hull uten ny klientkode. |

## Hvordan målingen ble gjort

Fra Claudes innebygde nettleser på Mac-en (skyens egress-liste blokkerer
`*.digipomps.org` og `*.dimy.io`, og `device_bash`-VM-en har ingen egress —
begge målt 2026-09-15). JavaScript i sidekonteksten åpnet `WebSocket` mot hver
kandidat og logget `open`, innkommende meldinger, close-kode og varighet.
Ingen frames ble sendt til serveren; kun lyttet.
