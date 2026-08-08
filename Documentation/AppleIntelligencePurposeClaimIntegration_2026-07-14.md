# Apple Intelligence: formåls- og claim-analyse i Binding

Status: implementert og lokalt verifisert 2026-07-14. Dokumentet skiller mellom det som er bevist, det som bare er en hypotese, og det som fortsatt krever sammenlignende evaluering.

## Konklusjon

`coreai-torch` finnes og publiseres på PyPI med Apple som verifisert eier, men pakken konverterer PyTorch-modeller til Core AI IR. Den tuner ikke Apples innebygde Apple Intelligence-modell og er ikke nødvendig for Binding-integrasjonen i dette steget.

Binding bruker i stedet Apples `FoundationModels`-rammeverk direkte fra Swift. Den deterministiske Binding-koden lager en liten mengde gyldige kandidater. Apple-modellen får bare utføre avgrensede mikrooppgaver med guided generation. En deterministisk port validerer modellsvaret før noe publiseres som formål eller claim.

Denne arkitekturen er i tråd med Apples egen beskrivelse av device-scale-modellen: modellen er egnet til blant annet ekstraksjon og klassifisering, mens krevende resonnering bør deles i mindre oppgaver. Guided generation gir strukturelt avgrensede Swift-utdata. Kilder:

- [Foundation Models](https://developer.apple.com/documentation/FoundationModels/)
- [LanguageModelSession](https://developer.apple.com/documentation/foundationmodels/languagemodelsession)
- [Meet the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2025/286/)
- [coreai-torch på PyPI](https://pypi.org/project/coreai-torch/)

## Formål og mål

### F-001: Bedre lokal resonneringskvalitet uten å gi småmodellen fri kontroll

Målet er ikke å få den lokale modellen til å generere hele HAVEN-strukturen. Målet er å kombinere dens språkforståelse med deterministiske kontrakter, slik at Binding kan få høyere kvalitet uten å svekke identitet, tilgangskontroll eller sporbarhet.

| Goal | Mål | Status 2026-07-14 |
| --- | --- | --- |
| G-001 | Modellen kan bare velge formålsreferanser som Binding-koden har laget | Oppfylt i kode og tester |
| G-002 | Manglende bekreftelse skal ende i `purpose://prompt.unknown` | Oppfylt i kode og tester |
| G-003 | Claim-ID og claim-tekst skal komme fra deterministisk, sitatforankret ekstraksjon | Oppfylt i kode og tester |
| G-004 | Modellen kan bare velge kanoniske `ClaimType`-verdier | Oppfylt i kode og tester |
| G-005 | Analyse skal være eieravgrenset og uten Perspective-, Entity- eller domeneendringer | Oppfylt i kode og tester |
| G-006 | Apple-pipelinen skal være minst like god som store modeller på avtalte oppgaver | Ikke målt; evalueringsmanifest opprettet |

G-006 er en åpen kvalitetspåstand, ikke en konklusjon. To live smoke-tester og eksisterende E3-resultater er nyttige implementasjonsbevis, men de er ikke tilstrekkelige til å påstå generell frontier-paritet.

## Implementert arkitektur

### Formålsdekomponering

1. `BindingChatIntentClassifier` og ressursmatchingen lager maksimalt fire kandidater fra den versjonerte Binding-taksonomien.
2. Kandidater under resolverterskelen `0.68` fjernes før modellen kalles.
3. Apple-modellen svarer `yes`, `no` eller `unsure` for én kandidat om gangen via `@Generable`.
4. Porten ignorerer oppdiktede purposeRefs og velger bare bekreftede kandidater.
5. Uten en bekreftet kandidat returneres `purpose://prompt.unknown` og ingen anbefalt handling.

Provider-kontrakten publiserer kandidatlisten, modellens bounded verdicts, valgt formål, portpolicy og sporbar status under `purposeDecomposition`.

### Claim-analyse

1. Koden deler teksten i maksimalt seks sitatforankrede kandidater. URL-domener og desimaltall behandles ikke som setningsgrenser.
2. Hver kandidat får stabil ID, eksakt tegnintervall, styrke og eventuelle eksplisitte URL-ankre.
3. Apple-modellen vurderer først `yes/no/unsure`, deretter én av seks kanoniske claim-typer.
4. Porten avviser ukjente ID-er og claim-typer.
5. Godkjente resultater publiseres som `ClaimDefinition` med skjema `haven.claim-definition.v0`.
6. Eksplisitte URL-er merkes `needs_external_source_audit`; manglende kilde merkes `source_missing`. Modellen får aldri markere en kilde som støttende.

Provider-endepunktene er:

- `SET ai.classifyIntent`
- `GET ai.lastClassification`
- `SET ai.analyzeClaims`
- `GET ai.lastClaimAnalysis`

Alle er owner-scoped gjennom CellProtocol-avtaler og `validateAccess`. Analyseendepunktene lagrer kun siste providerresultat for innsyn. De oppretter ikke ClaimCell, endrer ikke Perspective eller Entity, sender ikke data og starter ikke verktøy.

## Claim-ledger for selve anbefalingen

| Påstand | Vurdering | Evidens / mangel |
| --- | --- | --- |
| `pip install coreai-torch` er nødvendig for å tune Apple Intelligence | Motsagt for denne integrasjonen | Pakken konverterer egne PyTorch-modeller til Core AI IR; Binding bruker systemmodellens Swift-API |
| Avgrensede mikrooppgaver og en deterministisk port kan gjøre Apple-modellen mer pålitelig i HAVEN | Delvis støttet | E3 målte 85 % på holdt-ut purpose-test i full pipeline; Binding har nå to beståtte live-smokes. Resultatet generaliserer ikke automatisk til claim/argumentkvalitet |
| Denne løsningen er minst like god som de store modellene | Ikke verifisert | Krever blinded, versjonslåst, paret evaluering etter evalueringsmanifestet |
| Norsk LoRA-adapter er nødvendig nå | Ikke vist | E3b er fortsatt en egen hypotese. Arkitekturen må måles adapterløst først, slik at bare dokumenterte feil møtes med trening |

Lokale forskningsgrunnlag:

- `../CellProtocolDocuments/Deliverables/Small_Model_Purpose_Decomposition_Research_2026-07-11.md`
- `../CellProtocolDocuments/Deliverables/Codex_Handoff_E3b_Norwegian_LoRA_Adapter_2026-07-13.md`
- `../CellProtocolDocuments/Tools/PurposeKnowledge/e3_apple_microtask.swift`

## Verifikasjon

Live-testene er opt-in slik at den vanlige testsuiten ikke blir avhengig av modelltilgjengelighet eller latenstid:

```sh
Scripts/test_binding.sh CODE_SIGNING_ALLOWED=NO \
  'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) BINDING_APPLE_PURPOSE_SMOKE' \
  -skip-testing:BindingUITests \
  '-only-testing:BindingTests/ChatWorkbenchParityTests/appleProviderLiveGuidedPurposeSmokeStaysInsideDeterministicShortlist()'
```

Den samme kommandoen med `appleProviderLiveGuidedClaimSmokeUsesExactQuoteAndBoundedType()` kjører live claim-testen.

Observerte resultater 2026-07-14:

- Live purpose: bestått, valgt `personal.chat.assist.todo` innenfor kandidatlisten, 0 modellfeil, 3,62 sekunder i siste kjøring.
- Live claim: bestått, eksakt sitat og `project_capability`, 0 modellfeil, 3,98 sekunder.
- Deterministiske tester dekker bounded kandidater, fail-closed, oppdiktede refs/ID-er, ukjente claim-typer, URL-ankre, provider-audit, bivirkningsfrihet og foreign-requester-avslag.

Disse resultatene beviser at den implementerte vertikale skiven virker på maskinen. De beviser ikke semantisk kvalitet over et representativt korpus.

## Neste bevisgrense

`AppleIntelligencePurposeClaimEvalManifest_v1.json` definerer neste måling. Først når den er kjørt kan vi avgjøre om:

1. deterministisk kandidatport alene er tilstrekkelig,
2. Apple-mikrooppgavene gir et reelt løft,
3. bestemte norske feiltyper forsvarer en LoRA-adapter,
4. Apple-pipelinen faktisk er ikke-inferiør eller bedre enn valgte, versjonslåste store modeller.

Argumentgraf, støtte/motargument, komposisjonslogikk, kildeverifisering og persistent ClaimCell er eksplisitt utenfor denne første skiven. De skal legges til som egne bounded mikrooppgaver etter at claim-ekstraksjonen er målt.

## Tverr-scaffold kontekstgrense

Når Binding senere bruker purpose- eller Entity-data fra flere scaffolds, skal Apple-providerens kontekst ikke bygges ved direkte endpointsøk eller ved å kopiere en global Entity. Den skal motta et redigert, purpose-scoped resultat fra den foreslåtte `PurposeQueryCoordinatorCell` i `CrossScaffoldPurposeEntityFabric_Architecture_2026-07-14.md`.

Hvert kontekstfragment må beholde kilde, purposeRef, revision eller watermark, content hash, freshness, redactions og tilgangsbeslutning. Modellen skal få vite når resultatet er partial, stale eller incomplete. Et fragment som Binding har `r`-tilgang til, kan ikke lagres i analysehistorikk eller brukes til trening uten en separat `s`-capability og eksplisitt retention intent.

Inntil den fødererte kontrakten, durable replay og commit-semantikken er implementert, er Apple-integrasjonen begrenset til dagens lokale, owner-scoped kontekst. Dette er en bevisst fail-closed grense.
