# NearbyScanner: UI, kapasitet og konferansedekning

Gjennomgått 7. september 2026. Bestilling: sjekk om scanneren nå er en ren radar, om den håndterer et variabelt og stort antall enheter, forventet rekkevidde og muligheten for kjeding.

## Konklusjon og evidensnivå

Entity Scanner har nå en sirkulær radar, men hele arbeidsflaten består fremdeles av mange kort og eldre sektorbokser. Dynamiske datastrukturer er på plass; konferansekapasitet er ikke dokumentert.

- Lokal Binding HEAD: `775fc93d`. Arbeidstreet har allerede mange endringer, blant annet i konfigurasjonskatalog og tester. Disse er ikke endret i gjennomgangen.
- Faktisk kjørende app inspisert med CUA: `/Users/kjetil/Library/Developer/Xcode/DerivedData/Binding-bnzbjkzdqhtnnnfveahehmbivnwn/Build/Products/Debug/HAVEN.app`.
- Brukersti: Personal Co-Pilot → Entity Scanner → rull til radar. Observerte mørk sirkulær radar, meter-ringer, «STOPPED», null signaler og null tilkoblede. Store introduksjonskort gjør at radaren ikke er synlig ved åpning i det eksisterende vinduet. Hjelp, feilsøking og de eldre sektorboksene ligger fortsatt nedenfor. AX-treet viste også «Innholdet er ikke tilgjengelig akkurat nå» i eldre deler av flaten.
- Appens nøyaktige kildecommit kunne ikke bekreftes fra UI. Det observerte innholdet samsvarer med den nåværende konfigurasjonen på disk.
- Ingen scanning, invitasjoner, identitetsutveksling eller relé ble startet. Ingen ny build eller testpakke ble kjørt. Ingen radio-, UWB-, bakgrunns- eller konferansebelastning er verifisert.
- Eksisterende tester er lest, ikke kjørt. Skissen er interaktiv, men bruker syntetiske data og beviser ikke kapasiteten til produktet.

## Kildeankre og konkrete funn

| Lag | Kilde | Funn |
| --- | --- | --- |
| Aktiv scannerflate | `Cells/ConfigurationCatalogCell.swift`, `entityScannerToolConfiguration`, rundt 16230 | `SkeletonVisualization(kind: "radar", keypath: "scanner.radar", actionKeypath: "scanner.select")` er koblet inn. Hero-kort står før den. |
| Gjenværende bokser | Samme fil, rundt 16345 | `bindingConferencePortalEmbeddedRadarLayout`, kortgrid, fokuspanel, hjelp, feilsøking, flow og lagring ligger fremdeles i samme lange flate. |
| Ny radarrenderer | `../CellProtocol/Sources/CellApple/EntityRadar/RadarVisualizationView.swift` | Dynamisk `ForEach(spec.blips)`, sirkler og animert sveip. Ingen gruppering, zoom, kollisjonshåndtering eller oversikt for konferansetetthet. Hver enhet får markør, tekst, skygge og eventuelt usikkerhetsbue. |
| Ny radarmodell | `../CellProtocol/Sources/CellApple/EntityRadar/RadarModels.swift`, `RadarEntityLedger.radarSpec()` | Dictionary per remote UUID og dynamisk liste. Ingen liten fast antallsgrense. Flere sorteringer av hele listen per snapshot. Taushet gir fading og senere pruning. |
| Ukjent posisjon | Samme fil, `fallbackAngleRadians`, `normalizedRadius` | Ukjent vinkel bestemmes av hash av remote UUID. Ukjent avstand plasseres ved radius 0,72. Rendereren merker manglende retning med stiplet bue; plasseringen er likevel ikke en måling. Ved stor tetthet samles posisjonsløse enheter rundt samme ring. |
| Skala | Samme fil, `rangeMeters` | 8 meter er standard ytterring; avstand utenfor skala klemmes til kanten. «REKKEVIDDE» i renderer kan mistolkes som radioens rekkevidde. |
| Eldre konferanseadapter | `Binding/BootstrapView.swift`, rundt 5564 | Primærkort avkortes med `prefix(8)`, skjulte kort med `prefix(8)`, alle-kort med `prefix(12)`. Den separate radarsurface-listen bruker alle enhetene som sendes inn. |
| Eldre radarflate | `Binding/ConferenceNearbyRadarSurfaceView.swift`; `Binding/ContentView.swift`, rundt 8560 | Egen native konferanseradar er valgt på bestemte konferansekonfigurasjonsnavn. Den har store navnemarkører og en ikke-rullbar stabel for usikker retning. Dette er en annen renderer enn den nye radaren som nå vises i Entity Scanner. |
| Transport | `../CellProtocol/Sources/CellApple/EntityRadar/ScannerService.swift`, rundt 288 | Én `MCSession`. Discovery-lister er dynamiske. Ingen implementert generell multi-hop-relé for videreformidling av nærhetsobservasjoner funnet i scannerløpet. Direkte transportbroer er ikke i seg selv et slikt relé. |
| UWB | Samme fil, rundt 255, 714, 881 og 1099 | Én `niSession`, én `peerDiscoveryToken`, én `connectedRemoteUUID`. Ny tilkobling setter global motpart og starter presisjon igjen; tokenmottak overskriver globalt token. Ikke en implementasjon som måler alle tilkoblede uavhengig. Sammenhengen mellom token og remote UUID bør testes med minst tre enheter før flere samtidige presisjonsmål loves. macOS-grenen har ikke NearbyInteraction. |
| Variabelt antall-test | `BindingTests/BindingTests.swift`, rundt 6138 | Testen med «SupportsVariableEntityCounts» injiserer tre kandidater; viser to og så tre etter filterendring. Dette er ingen test av 100 eller 1000 enheter. |
| Ny ledger-test | `../CellProtocol/Tests/CellBaseTests/RadarEntityLedgerTests.swift` | Dekker folding, posisjon, ukjent retning, fading/pruning og selection med små datasett. Ingen konferansebelastning. |

Det er også to valgtilstander: ny radar skriver `scanner.select`, mens eldre fokus/kontaktdeler bruker `nearbyRadar`. Samkjøring av valg må verifiseres ved opprydding; denne gjennomgangen har ikke bevist en feil i valgflyten.

## Antall og rekkevidde

Skill eksplisitt mellom antall registrerte deltakere, oppdagede peers, aktive forbindelser og samtidige presisjonsmålinger.

- Apple dokumenterer maksimalt åtte peers inklusive egen enhet per MCSession, altså sju andre enheter i den ene sessionen som brukes her. Dette er en forbindelsesgrense, ikke dokumentasjon på maksimalt antall oppdagede enheter.
- Generelle Nearby Interaction-grenser varierer med maskinvare/plattform. Koden her representerer i tillegg én aktuell UWB-motpart.
- Ingen målt rekkevidde for denne implementasjonen er dokumentert i gjennomgangen. 8 m i UI må omtales som visningsskala.
- MultipeerConnectivity kan bruke lokal Wi-Fi og peer-to-peer Wi-Fi. En nettverksoppdagelse er derfor ikke bevis på en bestemt fysisk avstand. På konferansen kan nettverkssegmentering, Bonjour-filtrering og klientisolasjon påvirke discovery.
- For en første feltpilot foreslås testpunktene 2, 5, 10, 20, 30 og 50 meter, med fri sikt og med mennesker/telefon i lomme. Et konservativt mål på omtrent 5–15 m stabil lokal nærhet er et planleggingsvalg som må måles, ikke dokumentert eller garantert ytelse. Felles nettverk kan gi større logisk dekning uten fysisk avstandsmåling.
- iOS-bakgrunn begrenser eksisterende MPC-løsning: Apple sier advertising/browsing stoppes og åpne sessions frakobles når appen går i bakgrunnen. BLE har også egne bakgrunnsbegrensninger; å bytte transport løser ikke automatisk kontinuerlig konferansesporing.
- Xcode 27 deprekerer MPC; Apples TN3213 anbefaler migrering til Network framework. Et konferansearbeid bør vurdere dette før ny omfattende transport bygges på MPC.

## Foreslått produktretning

Dette er anbefalinger, ikke implementerte funksjoner.

1. Én dominerende radarflate med liten statuslinje og ett sett start/stopp-handlinger. Flytt tekniske forklaringer, feilsøking og flow til egne hjelpe-/diagnostikkflater. Bevar tilgjengelig kontakt, profil og chat i ett panel for valgt person.
2. Tegn små markører; vis navn ved valg. Grupper tette markører med antall, og la trykk/zoom åpne gruppen. Behold markerte personer synlige. Tilby søk og en fullstendig tilgjengelig liste, med lasting ved behov og korrekt totalantall.
3. Vis målt retning/avstand, avstand uten retning, helt ukjent posisjon og observasjoner via andre som forskjellige tilstander. Ingen hash-baserte punkter i en fysisk radar for ukjent posisjon. Ukjent retning med kjent avstand kan være en full usikkerhetsring; ukjent avstand trenger et område uten meterskala.
4. Bygg oversikt for tusenvis av deltakere via konferansetjeneste/soner; la telefonen prioritere lokale oppdagelser og noen få valgte forbindelser. Bruk presisjonsmåling for valgt person der maskinvare og tillatelser tillater det. Tusenvis i katalogen innebærer ikke tusenvis av radiomål samtidig.
5. Mål UI med 0, 1, 10, 100, 1000 og 5000 syntetiske enheter, også med alle posisjoner ukjente og alle posisjoner overlappende. Kontroller tellere, valg, gruppedrill, søk og CPU/minne. Suppler med faktiske enheter, bakgrunn/forgrunn, tap/rejoin og 3+ motparter for UWB-identifikasjon. Sett mål for funnrate og forsinkelse før kapasitetsløfter.

Interaktiv designskisse: `/Users/kjetil/.codex/visualizations/2026/09/07/01a07d88-79b9-7192-94a4-a6b7ab37379b/nearby-radar.html`. Posisjoner og antall er syntetiske. Gruppering og ukjent-posisjonstilstand kan prøves. Ikke integrert i HAVEN. Fragmentformat og JavaScript-syntaks er kontrollert. En isolert DOM-stub-kjøring bekreftet at 10/100/1000/5000 syntetiske enheter beholder riktige antall og at gruppedrill, tilbake og ukjent-posisjonstilstanden endrer modellen. Dette verifiserer ikke nettleserlayout. CUA-nettleserens URL-policy avviste lokal `file://`-forhåndsvisning; ingen omgåelse ble forsøkt.

## Kjeding og AirTag-sammenligningen

AirTag-lignende dekning kommer fra nærliggende Apple-enheter som rapporterer observasjoner videre til iCloud. Det er ikke en kjede av AirTags som gir hverandre direkte radaravstand. Find My-tilbehør går gjennom Apples MFi-program; det er ikke en generell API for en deltakeroversikt i HAVEN.

Et eget HAVEN-nett av frivillige observatører/konferansenoder er teknisk mulig som en separat utvidelse. Første versjon bør bruke konferansenoder på stabilt nett, med kortlivede, dedupliserte observasjoner og tydelig avsender, tidspunkt, usikkerhet og sone. Mobil videresending kan undersøkes senere med begrenset antall hopp og rategrenser. Synlighet/videresending må inngå i deltakerens uttrykkelige konferansesamtykke; ingen automatiske profil- eller identitetstilganger utledes fra nærhet.

Hvis A ser B og B ser C, følger det ikke at C er i en bestemt retning eller avstand fra A. Ved samtidige avstandsmål gir trekantulikheten bare et intervall; uten slike mål har man kun et indirekte nærværssignal. Vis «sett via konferansen, sone B, for 12 s siden» fremfor en oppdiktet lokal radarkoordinat.

## Offisielle kilder, kontrollert 2026-09-07

- [Apple MCSession: åtte peers inklusive lokal enhet](https://developer.apple.com/documentation/multipeerconnectivity/mcsession)
- [Apple Multipeer Connectivity: transport og bakgrunn](https://developer.apple.com/documentation/multipeerconnectivity/)
- [Apple TN3213: migrering til Network framework](https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework)
- [Apple Nearby Interaction: sessionsgrense varierer](https://developer.apple.com/documentation/nearbyinteraction/nierror/code/activesessionslimitexceeded)
- [Bluetooth SIG: faktorer som bestemmer rekkevidde](https://www.bluetooth.com/learn-about-bluetooth/key-attributes/range/)
- [Apple Core Bluetooth: bakgrunnsscanning](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html)
- [Apple Find My security: vidererapportering og kryptering](https://support.apple.com/guide/security/find-my-security-sec6cbc80fd0/web)
- [Apple Find My-tilbehør og MFi](https://developer.apple.com/find-my/)
