# Celledeling som tilgangsstyring — 2026-08-25

Notat etter F1-feilen i nearby-scanneren. Kjetils observasjon, skrevet ut som
prinsipp og som konkret forslag.

---

## Feilen som utløste dette

`EntityScannerCell` la to nøkler i sin agreement-mal:

```swift
self.agreementTemplate.ensureGrant("r---", for: "disclosurePolicy")
self.agreementTemplate.ensureGrant("r---", for: "probeResult")
```

Konsekvensen var at enhver peer som slapp inn gjennom malen kunne lese de eksakte
formåls-refsene du hadde godkjent **for en annen peer**, pluss hele policyen din i
klartekst — `beaconPurposeRefs`, `beaconInterestRefs`, `probeDisclosureRefs`.

Det er verdt å merke seg *hvordan* feilen så ut da den ble skrevet. Den ser
rimelig ut. `capabilities` og `encounters` står rett ved siden av med samme
`r---`, og de skal være lesbare. Ingen enkelt linje er åpenbart gal. Feilen
oppstår først når du husker at `probeResult`-getteren returnerer hele kartet
nøklet på alle remote-UUID-er, og at cellen har over seksti nøkler.

---

## Prinsippet

> **En celle er tilgangsstyringens enhet. Én celle med seksti nøkler har seksti
> uavhengige beslutninger å ta feil på. Seks celler med ti nøkler hver har seks.**

Grunnen er ikke at ti er lettere enn seksti å lese gjennom. Grunnen er at når
nøklene ligger i samme celle, er sensitivitet en **egenskap ved den enkelte
nøkkelen**, som noen må vurdere riktig hver gang. Når de ligger i hver sin celle,
er sensitivitet en **egenskap ved cellen**, og da arver nøkkelen den.

Det gir tre konkrete gevinster:

1. **Feilen blir strukturell, ikke skjønnsmessig.** Du kan ikke ved et uhell dele
   probe-detaljer hvis probe-detaljene bor i en celle som ikke har noen
   agreement-mal i det hele tatt.
2. **Malen blir lesbar som en påstand.** «Denne cellen deler kun aggregater» er
   en setning man kan verifisere ved å telle nøklene. «Denne cellen deler 8 av 61
   nøkler» er det ikke.
3. **Testen blir mulig å skrive.** Du kan teste at en celles hele offentlige
   overflate er trygg. Du kan ikke gjerne teste at seksti nøkler hver for seg har
   riktig grant, uten å skrive seksti tester som ingen vedlikeholder.

Merk at dette er **det motsatte** av hvordan man vanligvis argumenterer for
oppdeling. Den vanlige begrunnelsen er kodehygiene: mindre filer, klarere ansvar,
lettere å teste. Her er begrunnelsen sikkerhetsteknisk, og den er sterkere:
oppdelingen fjerner en klasse av feil i stedet for å gjøre dem lettere å finne.

---

## Konkret forslag for EntityScannerCell

`EntityScannerCell` er i dag ~2 400 linjer og eier: transport-livssyklus,
beacon-policy og samtykke, probe-tilstand og nonces, per-peer tilstandsmaskin,
kontaktforespørsler, encounter-proofs, og eksport. Én agreement-mal dekker alt.

Foreslått deling i fire, etter **hvem som skal kunne lese hva**:

| Celle | Eier | Agreement-mal | Begrunnelse |
|---|---|---|---|
| **NearbyPolicyCell** | `NearbyDisclosurePolicy`, `approveBeacon`, beacon-konstruksjon | **Ingen.** Eier-bare, uten unntak | Policyen er brukerens intensjon. Ingen motpart har noen gang bruk for å lese den. En celle uten mal kan ikke lekke. |
| **NearbyRadarCell** | oppdagede peers, beacon-overlapp, entitetstype, tilstandsmaskin | Kun aggregater | Dette er det radaren viser. Trygt å projisere, fordi cellen fysisk ikke inneholder noen ref. |
| **NearbyProbeCell** | probe-sesjon, nonces, `probeResult`, detaljgodkjenning | Kun scoped til den spørrende peeren | Detaljer finnes her, så her må scoping håndheves — men det er ett sted, ikke ett blant seksti. |
| **EntityContactCell** | `requestContact`, `acceptContact`, encounters, eksport | Bred, og det er meningen | Å dele identitet og proof **er** cellens formål. Her er en rundhåndet mal riktig. |

`ScannerService` forblir ren transport og kjenner verken policy eller Agreement.

Den viktigste linjen i tabellen er den første. **NearbyPolicyCell skal ikke ha
noen agreement-mal.** Ikke en tom en — ingen. Da er F1 ikke lenger en feil man
kan gjøre; det er en kompileringsfeil å prøve.

---

## Når oppdeling *ikke* lønner seg

For balansens skyld, siden dette lett blir en regel som brukes for hardt:

- **Når nøklene deler tilstand som må være konsistent.** To celler som må skrives
  atomisk sammen er én celle med et koordineringsproblem, ikke to celler.
- **Når alle nøklene har samme sensitivitet uansett.** En celle med tjue nøkler
  som alle er eier-bare har ikke noe å vinne på å bli til fire.
- **Når grensen ville gå tvers gjennom en tilstandsmaskin.** Per-peer-tilstanden
  i nearby-stigen er ett eksempel: den må bo ett sted, ellers får du to
  sannheter om hvor en peer står.

Kriteriet er altså ikke størrelse. Det er om cellen har **flere ulike
lesergrupper**. En celle med seksti nøkler som alle skal leses av samme part er
grei. En celle med ti nøkler der tre skal deles og syv ikke, er en feil som venter.

---

## Anbefalt rekkefølge

Ikke nå. Appen ble grønn på telefonen i dag, og en oppdeling i fire celler
berører registrering, katalogoppføringer, skeleton-referanser og tester.

Riktig tidspunkt er **etter** to-enhets-akseptansetesten, når vi vet at stigen
faktisk virker på ekte maskinvare. Da er oppdelingen en refaktorering med et
fungerende referansepunkt å måle mot, i stedet for en omskriving av noe som
aldri er bevist.

Det som derimot bør gjøres med én gang, og som er billig: **skriv en test som
enumerer hele agreement-malen til `EntityScannerCell` og feiler hvis en ukjent
nøkkel dukker opp.** Den koster ti minutter og fanger neste F1 før den rekker å
bli en lekkasje.
