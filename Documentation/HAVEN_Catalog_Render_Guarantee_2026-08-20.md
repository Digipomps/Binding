# HAVEN — garanti for at alt katalogen tilbyr faktisk lastes

Dato: 20. august 2026
Kjørt mot: `platform=macOS,arch=arm64`, `CellConfigurationVerifierXCTest`, ekte runtime.

---

## 1. Hvorfor perspective-buggen kunne skje

Garantien var aldri koblet til virkeligheten.

- Katalogen tilbyr konfigurasjoner fra én autoritativ funksjon, `ConfigurationCatalogCell.scaffoldPurposeTemplates()` — 69 deskriptorer fordelt på seks grupper, filtrert etter modus.
- Verifikasjonen kjørte mot en **håndskrevet liste på ti** i `testPersonalCopilotLocalSurfacesLoadWithoutReferenceFailures`.
- De to listene har ingen kobling. Legger du til en flate i katalogen, skjer det ingenting i testen.

Co-Pilot — hovedflaten — stod ikke i testlista. Det er hele forklaringen på at en `notFound` på primærflaten kunne shippes.

Verifikatoren selv (`CellConfigurationVerifier`, 1666 linjer i `BindingTests.swift`) er god: den resolver referanser, laster inn i en ekte Porthole, leser rot-prober, faller tilbake til fulle bindinger når rot-proben er en trunkering, og kan kjøre knapper. Problemet var aldri verktøyet. Det var hva det ble pekt mot.

## 2. Endringen: katalogen verifiserer seg selv

**`ConfigurationCatalogCell.offeredCatalogConfigurationsForVerification()`** (DEBUG-only) returnerer nøyaktig det katalogen tilbyr, i samme rekkefølge og under samme gating som appen bruker.

**`testEveryOfferedCatalogConfigurationHasReadableRoots`** itererer over den lista og kjører `contractReport` på hver eneste konfigurasjon. Feil samles opp og rapporteres samlet i stedet for fail-fast, slik at én ødelagt flate ikke skjuler de andre.

Konsekvensen er strukturell: **en flate kan ikke lenger tilbys uten å bli verifisert.** Lista kan ikke drifte fra virkeligheten, fordi det ikke lenger finnes to lister.

## 3. Første måling

```
4 of 16 offered configurations are not fully loadable
```

Seksten er tallet i App Store-modus, der gaten filtrerer til `personal-copilot-v1`. Fire av dem — 25 % — er flater appen i dag presenterer som mulig å laste, men som ikke laster.

| Flate | Feil | Klasse |
|---|---|---|
| **Butterpop Studio** | `cell://staging.haven.digipomps.org/MusicPublishingConsole` → «There was a bad response from the server» på bridgehead-websocketen | Fjernavhengighet |
| **Calendar Store** | rot `calendar.calendar` → `notFound`, og fallbacket til full binding lykkes heller ikke | Kontraktgap i cellen |
| **Apple Intelligence** | rot `catalog.matching` → `notFound` | Kontraktgap i cellen |
| **Entity Scanner** | refererer `cell:///ConferenceNearbyRadar`, som ikke er registrert i App Store-modus → `notFound` | Scope-brudd |

### Hva hver av dem betyr

**Butterpop Studio** er et selvstendig funn utover rendering: den er `personal-copilot-v1`-scopet og dermed tilbudt i App Store-modus, selv om modenhetsvurderingen fra 3. august eksplisitt listet Butterpop blant flatene som skal ut av det innsendte targetet. Den feiler i tillegg fordi den avhenger av en levende staging-vert. En konfigurasjon som bare virker når en fjernvert svarer, kan ikke tilbys som «mulig å laste» uten at tilgjengelighet er sjekket først.

**Calendar Store** og **Apple Intelligence** er samme klasse som perspective-buggen: cellen navngir nøklene sine under et prefiks (`calendar.state`, `calendar.collections`, …) uten å servere selve rotnøkkelen. `GeneralCell.get` har en nested-fallback, men den forutsetter at rotnøkkelen svarer. Merk at verifikatoren allerede prøver den fulle bindingen før den gir opp — så dette er ekte gap, ikke for streng probing.

**Entity Scanner** er det mest alvorlige for review-historien: en `personal-copilot-v1`-flate refererer en conference-celle. I App Store-modus er conference-cellene ikke registrert, så referansen kan ikke resolveres. Det er både en renderingsfeil og et brudd på scope-grensen dere beskriver for Apple.

## 4. Det som gjenstår for en ekte 100 %-garanti

Testen måler nå. Den **hindrer** ennå ikke.

**Steg 1 — gjør testen blokkerende.** Den bør kjøre i CI og stoppe en build der en tilbudt flate ikke laster. Uten det er den bare en rapport.

**Steg 2 — gjør verifikasjon til en betingelse for å bli tilbudt.** Det sterkeste designet er at `scaffoldPurposeTemplates()` ikke lister en konfigurasjon som ikke har bestått verifikasjon. Da blir «alt som tilbys virker» en egenskap ved systemet i stedet for en påstand om det. For lokale, kompilerte konfigurasjoner kan dette gjøres ved byggetid.

**Steg 3 — fjernkonfigurasjoner må verifiseres der de publiseres.** Klienten kan ikke garantere for noe den ikke har hentet. Butterpop-feilen er den generelle formen: en fjernflate kan feile fordi verten er nede, fordi kontrakten har endret seg, eller fordi skeletonet refererer noe klienten ikke har. Tre mekanismer trengs:

- **Publiseringstid, på CellScaffold:** samme `contractReport` kjøres mot konfigurasjonen før den publiseres i katalogen. En konfigurasjon som ikke består, publiseres ikke.
- **Signatur:** klienten laster bare konfigurasjoner signert av HAVENs release-nøkkel, slik designnotatet om scope-grammatikk beskriver. Da er «verifisert ved publisering» noe klienten kan stole på uten å verifisere på nytt.
- **Tilgjengelighet ved listing:** en fjernflate bør ikke presenteres som lastbar før verten har svart. Alternativet er å vise den som midlertidig utilgjengelig — ærlig, og langt bedre enn en feilskjerm etter at brukeren har trykket.

**Steg 4 — dekk knappene også.** Testen kjører i dag med `buttonsToExecute: []`. Verifikatoren kan eksekvere statiske knapper, og den eksisterende ti-flate-testen gjør det. Å utvide den nye testen til også å bekrefte at handlinger er nåbare, lukker resten av «virker 100 %».

## 5. Endrede filer i denne runden

- `Binding/Cells/ConfigurationCatalogCell.swift` — `offeredCatalogConfigurationsForVerification()`, DEBUG-only
- `Binding/BindingTests/CellConfigurationVerifierXCTest.swift` — ny test som verifiserer alt katalogen tilbyr

Ingen produksjonsatferd er endret av disse to.

## 6. Vurdert og forkastet

Jeg implementerte først et fallback i appens probe-sti: ved rot-probe-feil skulle den bekrefte mot den fulle bindingen før den erklærte flaten ulesbar. Så oppdaget jeg at `CellConfigurationVerifier` allerede gjør nøyaktig dette (`directReadableBindings` + `firstReadableBindingOutcome`) — og at de fire flatene feiler *til tross for* det fallbacket.

Endringen hadde altså ingen dokumentert effekt, og la til en ekstra lesesti i primær lastesløyfe. Den er reversert. Appens probe er strengere enn verifikatorens; det er verdt en egen, evidensbasert endring, ikke en gjetning smettet inn her.

## 7. Ikke verifisert

- Testen er kjørt én gang, på macOS-destinasjonen. Ikke kjørt på iOS-destinasjon.
- De 53 konfigurasjonene som bare tilbys utenfor App Store-modus er ikke målt. Kjør testen med `BINDING_ENABLE_CONFERENCE_DEMO_MENUS=1` for å få hele bildet.
- Ingen av de fire feilene er rettet i denne runden. De trenger hver sin undersøkelse, og jeg vil ikke gjette på tre av dem i samme runde som jeg leverte en verifisert fiks på den fjerde.
