# Scanner → felles samtale → samtykket samtaleminne

Status: **forslag til vurdering**, 2026-09-11. Ikke implementert eller aktivert.
Type: idé/funksjonsforslag. Område: Scanner, samtaleceller, Agreements/Conditions, transkript og tillitspakker.

## Formål og brukerønske

To brukere som finner hverandre gjennom Scanneren, skal kunne møtes i en felles celle. Initiativtakerens scaffold kan være standardvert. Det samme mønsteret skal kunne brukes ved digitale møter. En deltaker kan foreslå opptak og etterfølgende deling av transkript, slik at begge kan hente ut temaer, avtalte oppfølginger og utvalgte opplysninger om hverandre. Begge skal kunne be om en tillitspakke som viser samtykke, delte data og behandling.

Målet er et nyttig, kontrollerbart samtaleminne. Opptak skal være valgfritt; det skal fortsatt være mulig å møtes og snakke uten det. Dette er en utvidelse av scannerarbeidet, ikke en erstatning for utestående Butler-forbedringer eller maskinvaretester.

## Foreslått brukerflyt

1. **Møtes:** «Åpne felles samtale» på et valgt treff. Den andre godtar invitasjonen. Cellen viser hvem som deltar og hvilket scaffold som hoster den. En digital invitasjon kan føre til samme flyt; lenken alene gir ikke tilgang.
2. **Foreslå opptak:** «Skal vi ta opp samtalen og lage et felles transkript?» Begge ser samme korte plan: lydkilde, formål, deltakere, behandlingssted/modell, hva som deles og hvor lenge materialet beholdes. «Vis tillitspakke» åpner detaljene.
3. **Begge godtar:** Opptak starter først etter at begge har godkjent den aktuelle planen. Mikrofontillatelse og opplåsing av identitet er egne tekniske forutsetninger, ikke samtykke på den andres vegne. Avslag gir ingen gjentatte autentiserings- eller samtykkeforsøk.
4. **Under samtalen:** Begge ser aktivt opptak og har Pause/Stopp. Pause, tilbakekalling, manglende bekreftet forbindelse eller deltakerendring stanser den berørte behandlingen til gyldige vilkår igjen er etablert. Nye personer i en fysisk samtale krever en ny avklaring; appen kan ikke garantere å oppdage alle som blir hørbare.
5. **Etterpå:** Et versjonert transkript og et begrenset sett dataforslag vises for gjennomgang. Brukerne kan rette, utelate og bestride tekst og talertilordning. De godkjenner hvilken versjon eller hvilke utdrag som deles. Hver person velger så hva som skal beholdes i egen Entity.

En oversiktlig første flate trenger bare deltakere, vert, opptaksstatus og hovedhandlinger. Tekniske detaljer og bevis ligger bak tillitspakken. Samtykke til opptak, transkripsjon, modellbehandling, deling og varig lagring er separate beslutninger i kontrakten; kompatible valg kan gjennomgås samlet i én forståelig plan, uten fem unødige dialogbokser.

## Felles celle og myndighet

Bruk en privat samtaleinstans med egen sesjonsreferanse; offentlig oppdagelsesmetadata i lobbyen skal ikke få lyd, transkript, bevis eller personuttrekk. Initiativtakerens scaffold er et standardforslag til vert, som begge ser før de godtar. Vertskap gir ikke råderett over den andres Entity eller samtykke.

Et implementasjonsforslag er en versjonert behandlingsplan bundet til sesjon, deltakersett, domene, formål, vert, navngitte mottakere, modellrute og lagringsvilkår. Signerte godkjenninger bindes til samme planinnhold. Conditions kan også kreve gruppe-/relasjonsbevis fra scannerflyten. Slike medlemsbevis gir ikke i seg selv samtykke til opptak.

Resolver/Cell må kontrollere den aktuelle handlingens Contract/Grant og samtykkebevis. Hostens vanlige eiertilgang må ikke alene kunne omgå kravet om den andres godkjenning. Dette må verifiseres spesielt; en generell `validateAccess`-sjekk eller en hake i UI er ikke tilstrekkelig dokumentasjon. Endringer i deltakersett, mottakere, behandlingssted eller formål krever oppdatert myndighet. Et vertsskifte kan bare skje innen en allerede avtalt ramme eller etter ny godkjenning.

Den som ber om stopp, skal få lokal innsamling stoppet umiddelbart. Fjernstopp krever kvittering og en eksplisitt grense for hvor lenge en opptaker kan fortsette uten gyldig kontakt. Ved ukjent fjernstatus skal tillitspakken vise nettopp det. Tilbakekalling kan stanse videre autorisert behandling; den beviser ikke at allerede utleverte kopier er borte.

## Data, gjennomgang og lagring

| Materiale | Foreslått håndtering |
| --- | --- |
| Rålyd | Bare fra avtalt lydkilde, med særskilt avtalt oppbevaring. Opptak innebærer ikke automatisk tillatelse til å beholde lydfilen varig. |
| Transkript | Versjonert arbeidsmateriale med kilde-/tidsreferanser, usikker talertilordning og synlige rettelser. Gjennomgang og deling har egne kvitteringer. |
| Temaer, interesser, formål og oppfølginger | Modellforslag med kilde, behandling, usikkerhet og individuell akseptstatus. Omtale av et tema beviser ikke at personen har denne interessen. |
| Opplysninger om deltaker A til B | Må dekkes av avtalt deling av As opplysninger; B velger hva som beholdes. Ikke automatisk profilberikelse. |
| Egen Entity | Bare valgte felt under eierens lagringsmyndighet. Vis forskjell fra tidligere godkjente verdier; ikke overskriv stille. Begge kan ende med forskjellige, legitime utvalg. |
| Private notater | Holdes utenfor den felles pakken og den andres innsyn med mindre de uttrykkelig deles. |
| Tillitspakke | Minimerte bevis og referanser, med egen oppbevaringspolicy. Den trenger ikke inneholde hele lydfilen eller alle private notater. |

Første uttrekkskatalog bør være liten: samtaletemaer, uttrykkelig oppgitte interesser/formål og foreslåtte oppfølginger. Hold kildesitat, normalisert verdi og modellens slutning adskilt. Et syntetisk eksempel: «A nevnte fjellturer» kan være et kildestøttet samtalenotat; «A liker fjellturer» krever mer grunnlag og eventuell bekreftelse fra A.

Oppbevaring må avtales separat for rålyd, modellkontekst, transkript, utkast, aksepterte felt og kvitteringer. Forslaget er kortvarig arbeidsmateriale med mulighet til å beholde valgte resultater; ingen konkret TTL er valgt her. Utløp og faktisk sletting må være forskjellige statuser, med håndtering av frakoblede kopier og sikkerhetskopier. Eksisterende lagringspolicy skal ikke endres som følge av dette notatet.

Lagring krever `s`-myndighet i relevant Contract. Det gir ikke automatisk videredelingsrett. Begges lagring må ha uavhengige kvitteringer; én vellykket lagring betyr ikke at begge er ferdige. Gjenopptakelse må være idempotent og tåle at én part er frakoblet.

## Tillitspakke før, under og etter

Begge bør kunne åpne sin pakke når som helst. Den har en felles, verifiserbar del og en privat del for den enkelte:

- hva jeg godkjente, planversjon, formål, deltakere, domene, tidspunkt, utløp og eventuelle tilbakekallinger;
- hva som ble registrert og delt, mottaker, versjon/utdrag og mottakskvittering;
- hvilke transkripsjons- og modellsteg som kjørte, hvor, med hvilke innganger og resultatreferanser;
- hvilke forslag jeg godtok, endret eller avviste, og hva som faktisk ble lagret i min Entity;
- avtalt oppbevaring, utført sletting, utestående handlinger og manglende kvitteringer.

Bruk signerte samtykke-/handlingskvitteringer og integritetsreferanser til konkrete versjoner. Pakken må skille planlagt, tillatt, forsøkt, bekreftet og ukjent. Signaturer viser hvem som attesterte hvilke data; de beviser ikke alene at transkriptet er sant eller at en vert aldri laget en kopi utenfor systemet. Pakken gir etterprøvbarhet, ikke ekstra adgang eller et generelt troverdighetsstempel på motparten.

Ved ekstern modellbehandling skal pakken vise navngitt mottaker/rute, datautvalg, formål og oppbevaring før overføring, og faktisk forespørsels-/resultatkvittering etterpå. Hemmeligheter skal ikke inn i pakken. Funksjonens eksterne tilgang, lydinnsamling, Entity-lagring og deling er alle **ikke startet** i dette arbeidet.

## Kildekontroll og gjenbruk

Kildeinspeksjon 2026-09-11; dette beviser ikke installert eller ende-til-ende funksjonalitet:

- [Binding Bootstrap](../Binding/BootstrapView.swift) registrerer `Lobby` som `scaffoldUnique` `GeneralCell`. [CellApple LobbyCell](../../CellProtocol/Sources/CellApple/EntityRadar/LobbyCell.swift) tilbyr et eierpublisert offentlig formålsoppslag. Ingen av disse er en ferdig samtykket samtale-/opptakscelle.
- [BindingVoiceInputTranscriber](../Binding/BindingVoiceInputTranscriber.swift) har lokal diktering med `requiresOnDeviceRecognition`. Den eksisterende chatflyten er komposisjon, ikke et opptakssystem med samtykke fra flere deltakere. Fysisk mikrofon og lyd fra digitale møter trenger egne verifiserte adaptere; tilgang til andre møteappers lyd er ikke etablert.
- [TranscriptStoreCell](../../CellScaffold/Sources/App/Cells/Transcript/TranscriptStoreCell.swift) har requester-avgrenset lagring, hash, release/sweep/tidy og oppbevaringspolicy. Standard er `keepUntilReleased`, med `autoDeleteOnExpiry=false`. TTL alene betyr altså ikke automatisk sletting. Den viste oppsettbanen bruker også `rw--` for lagringshandlinger; særskilt `s`-håndheving må avklares før dette brukes som bevis på korrekt autorisert samtalelagring.
- [PersonalDataTrustPackageCell](../../CellScaffold/Sources/App/Cells/PersonalDataTrustPackage/PersonalDataTrustPackageCell.swift) tilbyr forslag og skjema, og oppgir eksplisitt at den ikke henter eksternt, skriver Entity eller deler data.
- [AgentTrustPackageCell](../../CellScaffold/Sources/App/Cells/AgentTrustPackage/AgentTrustPackageCell.swift) og [AgentTrustPackage](../../CellProtocol/Sources/CellBase/Agreement/AgentTrustPackage.swift) har relevante strukturer for modellruter, policygrenser, godkjenninger og audit. De gjelder agent-/tjenestekjeder, og må ikke omtales som ferdig støtte for denne samtaleflyten.
- [Agreements and Contracts](../../CellProtocolDocuments/Book/04_Agreements_Contracts.md) beskriver domeneavgrenset myndighet, Conditions, `s` og separat videredelingsrett. Eksisterende [scannerbevis](NearbyScannerImplementation_2026-09-10.md) kan være inngangskontroll, ikke opptakssamtykke.

Datatilsynets veiledning beskriver informasjon om ansvarlig, formål, behandlingsgrunnlag, mottakere, lagringstid og rettigheter ved lydopptak der personvernregelverket gjelder. Derfor bør disse være eksplisitte plan-/pakkefelt. Gjensidig godkjenning er et foreslått produktkrav her; dette notatet fastslår ikke at ett samtykkemønster dekker alle private, konferanse- eller arbeidslivssituasjoner. Kilde: [Hvilke rettigheter har den det gjøres opptak av?](https://www.datatilsynet.no/personvern-pa-ulike-omrader/overvaking-og-sporing/lydopptak/har-den-det-gjores-opptak-av-noen-rettigheter/), sist endret 2026-06-05, kontrollert 2026-09-11. Nettlesingen i denne vurderingen gjaldt bare offentlig veiledning; ingen person-/samtaledata ble hentet eller sendt.

## Avgrenset første versjon og akseptanse

Start med to deltakere, én avtalt opptaker og en konkret støttet lydkanal. Avklar vertens tilgjengelighet, behandlingsrute og oppbevaring før implementasjon. Bruk en syntetisk samtale til å prøve samtykke → transkript → gjennomgang → uavhengig lagring → pakke hos begge, før reell lyd kobles på.

Følgende må demonstreres, ikke bare beskrives:

1. Begge godkjenner samme plan; manglende/forfalsket/utløpt bevis og feil domene gir avslag, også når initiativtaker er host-eier.
2. Opptak er av før samtykke, og avslag utløser ikke gjentatte dialoger. Begge kan stoppe; tap av forbindelse, omstart og deltakerbytte testes.
3. En ny modellrute, mottaker eller planversjon kan ikke bruke gammelt samtykke. Offentlig lobby/Explore/logging lekker ikke private verdier.
4. Bare valgte data deles og lagres. Feil mottaker, manglende `s`, ukjent lagringsskjema og ubekreftede personslutninger håndteres eksplisitt.
5. Endringer og bestridelser er sporbare. Gjennomgangssignaturer blir ikke presentert som bevis på faktuell sannhet.
6. Begges lagring bekreftes separat og overlever restart/reload. Nettbrudd eller gjentatt innsending lager ikke doble poster.
7. Eksport, utløp, selektiv sletting og frakoblede kopier får reelle, nøkterne kvitteringer. Ubekreftet sletting vises som uavklart.
8. Begge kan lese tillitspakken og se hva som er godkjent, faktisk utført og fortsatt ukjent, uten å få den andres private notater.

Ingen appkode, datatilgang eller samtykkeinnstillinger er endret i denne vurderingen. Forslaget er dokumentert i repoet; det er ikke opprettet en ekstern sak eller hevdet lagret i en WorkItemCell.
