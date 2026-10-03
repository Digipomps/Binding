# Attach-drevet entitetstilstedeværelse — lokal runtime-kandidat

Dato: 2026-09-28. Oppgaven er «Implementer dette så vi får det i runtime».

## Hva som kjører

CellProtocol har en faktisk attach-trigger, signert tilbud/samtykke/kvittering,
fersk kontroll av eieradgang og en delt klient for samtykke eller policy. Binding
kobler klienten til eksplisitt menynavigasjon som attacher en remote celle.
Brukeren velger denne gangen, automatisk her i ett år, ikke spør her i ett år,
eller ikke nå. Automatisk bruk fornyer ikke policyens utløpstid. Policyoversikten ligger i identitetskoblingsflyten under
«Når jeg bruker eide celler …». «Spør neste gang» fjerner automatikk.

Policy og kvitteringer ligger kryptert med vault-avgrensede hemmeligheter.
Automatikk matcher mottakernøkkel, aktiv menneskeidentitet, domene, formål og
versjon. Delingstilgang, kopiert owner-UUID, debug-bypass og tilbakekalt
same-entity-kobling kvalifiserer ikke. Gjentatte forsøk gjenbruker en kvittering,
men må bevise gjeldende eierskap igjen. Ingen scaffold-identitet kobles til
menneskets entitet.

Dette registrerer tilstedeværelse med en eksisterende identitet. En ny nøkkel
eller to ennå ukoblede identiteter trenger fortsatt den signerte IdentityLink-
seremonien. Kvitteringen er ikke en rettighet til å lese/skrive/indexere data.
Den er et grunnlag for videre distribuerte entitetsfunksjoner, ikke bevis på at
alle slike funksjoner nå finnes. Ingen persondata er flyttet av denne kandidaten.

## Integrasjonsstatus

| Del | Faktisk status |
| --- | --- |
| CellProtocol | Implementert og 101 fokuserte tester består |
| Binding / macOS HAVEN | Bygger med lokal CellProtocol; 15 eksisterende identitets-/sikkerhetstester består |
| Native attach-samtykke | Direkte GUI-test bestod: samtykke, automatisk nytt attach med én kvittering, og avbryt med fortsatt celletilgang. XCTest UI-runner er separat blokkert av macOS-autentisering |
| iPhone | Delt native kode finnes; nytt iOS-bygg og fysisk to-enhetstest er ikke verifisert |
| CellScaffold | Mottakeradapter lagt til under CELLPROTOCOL_LOCAL_CHECKOUT; bygg stoppet av cache-eierskapskontroll før kompilering |
| Sprout, agent, menyhjelper | Ikke koblet til denne nye kontrakten ennå |
| Staging / prod / installert app | Ikke oppdatert av denne implementasjonen |
| Push / datamigrering / indeksering | Separat arbeid; ingen ny tillatelse eller implementasjon følger av tilstedeværelse |

## Praktisk lokal test

Åpne den isolerte testappen uten å erstatte /Applications/HAVEN.app:

```sh
open -n /private/tmp/haven-owner-attach-runtime/app-products/HAVEN.app --args --owner-attach-runtime-test
```

Fixture-modus hopper over normal oppstart og bruker bare midlertidige testnøkler
og minnelagring. Den kjører GeneralCell.attach, delt runtime-klient og det
native samtykkearket. Velg «Automatisk her i ett år», kjør attach igjen, og
kontroller to fullføringer men én mottakerkvittering. «Ikke nå» skal beholde
celleforbindelsen uten fullføring. Dette tester ikke en ekstern server eller
varig Keychain-lagring; disse trenger egne integrasjonstester.

Den vanlige appens attach-flyt krever en oppdatert mottaker med støttet vault
og kryptert kvitteringslager. Tilbyderen konfigureres med en eksisterende
provisionert mottakersigner på serveren. Ustøttede verter påvirker ikke vanlig
celletilgang. Ingen tilfeldig Absorb, import, preview eller automatisk oppstart
slår på automatisk entitetsutvidelse.

## Kilder og gjenskapbarhet

Arbeidet er isolert for å bevare pågående arbeid i hovedarbeidsområdene:

- Binding: `codex/entity-extension-security-20260928`, basis `ff3b20ca`.
- CellProtocol: `codex/owner-attach-entity-extension-20260929`, basis `81601a6f835252aba7e99d43786fb5d67227c245`.
- CellScaffold: `codex/owner-attach-runtime-20260928`, basis `adf48d46`.

Nye endringer er foreløpig lokale. Koordinert kildearkiv og sjekksummer ligger i
hovedarbeidsområdets `Implementation/EntityExtension-20260928/Runtime`.
`OwnerAttachRuntime.xcworkspace` refererer til Binding-prosjektet og en lokal
CellProtocol-mappe ved siden av Binding. Prosjektets vanlige remote package-pin
er ennå ikke oppdatert; bruk dette arbeidsområdet for kandidaten. Publisering
krever først en koordinert CellProtocol-versjon og deretter consumer-pins.

Kandidaten ble bygd med Xcode for macOS arm64, ad-hoc signering og lokal
CellProtocol. App-resultat: `Test-HAVEN-2026.09.28_19-18-39-+0200.xcresult`,
12 XCTest + 3 Swift Testing; alle bestod. CellProtocol-kjøringen består av
OwnerAttach, BridgeIdentityBoundary, GeneralCellInterface, ExploreContractValidator
og IdentityLink. Én syntetisk JSON-golden fastsetter ISO8601-wire og avviser
manglende signatur. Dette er Swift-dekning, ikke Sprout-interoperabilitet.

Serverens påkrevde bounded-build stoppet på en eksisterende SwiftPM-cache uten
`.haven-swiftpm-cache-v1`. Ingen markør ble forfalsket og ingen cache ble slettet.
UI-runneren må også få kjøre etter at den pågående macOS-autentiseringen er ferdig.
Ingen CI, deploy eller produksjonsendring er utført.

## Handoff til distribuert entitetsdata

`OwnerAttachExtensionClientRecord` inneholder validert kvittering og eventuelt
kryptert `receiverEndpoint` som rutinghint. Dette kan være innspill til en senere
entity-scaffold-inventarløsning, men er ikke i seg selv en fullstendig inventarliste
eller en tilgangsgrant. Ny lesing/skriving/indeksering må kontrollere aktiv
identitet, gjeldende eierskap, domene, mottakernøkkel og selvstendig datapolicy.
Tilbakekall og nøkkelrotasjon må gjelde også om en historisk kvittering finnes.

## Direkte native GUI-kjøring

Den endelige appen ble åpnet med fixture-flagget og betjent gjennom
tilgjengelighetstreet 2026-09-28. «Automatisk her i ett år» ga
«Bekreftet. Lagrede tilstedeværelser: 1 Fullføringer: 1». Et nytt attach
ga «Lagrede tilstedeværelser: 1 Fullføringer: 2», uten nytt samtykkeark.
Etter en ny fixture-prosess ga «Ikke nå» resultatet
«Avslått. Cellen er fortsatt tilkoblet. Fullføringer: 0».
Dette verifiserer den kjørbare native brukerflyten med faktiske lokale
GeneralCell-operasjoner. Det erstatter ikke fysisk telefon-/servertesting.
