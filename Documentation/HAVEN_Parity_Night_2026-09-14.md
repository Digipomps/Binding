# HAVEN-paritet natt til15.september2026

Brukerbestilling14.september: Avklar om HAVEN er klar til å prøve personkoblingen; undersøk og forbedre paritet gjennom natten slik at appen er så lik Porthole som praktisk mulig. Dette inkluderer visuell likhet i tillegg til samme innhold, navigasjon, handlinger og feiltilstander. Arbeidet fortsetter i eksisterende oppgave, ikke en ny brukeroppgave.

## Bekreftet startstatus

- Signert personkoblings-IPA b12b0414 finnes og SHA256 matcher fortsatt db0afc32ec88ea25912feeb60fe8c8b45f8cf710b11af46df6315b96ff8574a8. Den er ikke installert av denne oppgaven. Den kan være kandidat for avgrenset QR-/nærhetstesting, men er ikke klarbevis for hele kobling/dataflyten.
- Full personkobling på fysisk telefon, deretter native datatilgang, er ikke verifisert. Ny dataklient615 har sju grønne klienttester; den signerte b12-pakken inneholder ikke dataklienten. Dataoppgavens configure/brukerflate er ikke koblet inn, og siste TLS-runtimeprøve feilet.
- Freshness14.september: dataoppgaven står på0ac6d973. Signalhullet i cleanup er ifølge oppgavens dokumentasjon rettet, og20 lokale kontroller besto7.441s. Ny diagnostisk CI ble avvist før dispatch av automatisk godkjenningskontroll, som viste til manglende akseptert brukerautorisasjon for allokeringen, knapp budsjettmargin og kjent kanselleringsforsinkelse. Denne avviste CI-handlingen skal ikke gjentas/omgås av nattarbeidet. Uavhengig paritetsarbeid fortsetter.
- Originale Binding-arbeidstre har omfattende andres WIP, blant annet ContentView, FullLibraryView, BootstrapView, chatparitet, scanner og testkode. Bevar det. Nattendringer skal være isolerte og reviewbare; dokumenter valgt source/pins og kontroller relevante eksisterende endringer før en kandidat velges. Ikke overskriv eller nullstill arbeidsfilene.
- Eksisterende Scripts/run_skeleton_parity_suite.sh er en gammel oppskrift: den har hardkodet originalrepo, globale sentinel-filer og direkte xcodebuild. Ikke start den ukritisk mot skittent originaltre. Les nåværende guarded wrappers og diskporter først, gjenbruk navngitte testcases, og skill harnessfeil fra produktfeil.
- Audit29.august rapporterte manglende bridgehead på staging/prod. Dette er historisk evidens som må friskes opp før den brukes som nåværende rotårsak. Ikke gjeninnfør en gammel usikret bro for å få visuell paritet.

## Arbeidsmål gjennom natten

1. Etabler samme navngitte CellConfiguration/Skeleton-corpus i Porthole og Binding, med eksakt kilde/pin, identitetstype og viewport. Prioriter oppstart/bibliotek, chat, referanse/navigasjon, personkobling/nærhet, lister/tabs, felter/opplasting og lastings-/tom-/feiltilstander.
2. Kjør faktiske synlige brukerforløp der miljøet tillater det. Bevar skjermbilder, semantisk tre/DOM, nett-/konsollfeil og handlingseffekter. Test phone-/kompaktformat og macOS, synlige knapper, tekstbryting, avstander, rekkefølge, tastatur/scroll og tilgjengelighet. Native plattformforskjeller er lov når de er nødvendige; samme brukerintensjon og tydelig visuell likhet er målet.
3. Rett dokumenterte avvik i riktig eksisterende lag. Hold manglende transport/autorisasjon, rendereravvik og native navigasjonsfeil adskilt. Ikke skjul feil med lokale erstatningssider, svake tester, fiktive data i produktet eller vide fullmakter. Ingen ny protokollsemantikk uten Kjetils vurdering. Rett reversible UI-/rendererfeil innen eksisterende kontrakt og kontroller målrettet.
4. Lever en morgenstatus med bilder, konkrete rettinger, pass/fail per scenario og presis beslutning om hva Kjetil kan teste. Ikke kall kildeinspeksjon, gamle skjermbilder eller grønne unit-tester full aktuell paritet. Marker utilgjengelig/native capture som manglende bevis.

## Foreløpig matrise — ennå ikke nattverifisert

| Scenario | Kontrakt/kilde | Porthole | Binding | Handlinger | Visuell/kompakt | Nåværende kategori |
| --- | --- | --- | --- | --- | --- | --- |
| Oppstart og bibliotek | Innganger funnet | Ikke fanget | Ikke fanget | Ikke kjørt | Ikke fanget | Åpent |
| Chat/composer | Lokale tester og WIP funnet | Ikke fanget | Ikke fanget | Ikke kjørt | Ikke fanget | Åpent |
| Tekst, markdown, stack/section | Eksisterende fixtures | Ikke fanget | Ikke fanget | Ikke kjørt | Ikke fanget | Åpent |
| Lister, grid og tabs | Eksisterende fixtures | Ikke fanget | Ikke fanget | Ikke kjørt | Ikke fanget | Åpent |
| Button/form/tekst/opplasting | Kilde/kontrakttester funnet | Ikke fanget | Ikke fanget | Ikke kjørt | Ikke fanget | Åpent |
| Relative keypaths og referanser | Eksisterende remote suite | Ikke fanget | Ikke fanget | Ikke kjørt | Ikke fanget | Mulig transport/kontraktgap; må friskes opp |
| Tom/lasting/avvist/ugyldig | Eksisterende fixtures | Ikke fanget | Ikke fanget | Ikke kjørt | Ikke fanget | Åpent |
| Personkobling QR/nærhet | Signert b12-kandidat | Ikke fysisk prøvd | Tidligere syntetisk review; ikke nattprøvd | Fysisk ubekreftet | Ikke sammenlignet | Native/hardware-verifikasjon mangler |

Matrisen er startinventar, ikke beståtte tester. Utvid til øvrige støttede SkeletonElement-typer og reelle katalogflater etter første dokumenterte corpus. Rapporter alle typer/scenarier som ikke er dekket.

## Arbeidsregler og ressurser

Bruk binding-skeleton-parity-testing og haven-functional-service-verification; bruk renderer-/scaffold-/identity-ferdigheter ved relevante rettinger. Ingen nye subagenter eller brukeroppgaver er bestilt. Gjør ingen automatisk virkelig personkobling, nøkkelprovisjonering, installasjon over brukerens app, produksjonsendring eller datamigrering. Bruk syntetiske identiteter og isolerte testverter for tester. Respekter eksisterende kapasitetsporter og kjøp/CI-budsjetter; oppdater faktisk fri plass før bygg, ingen omgåelse/rydding. Lokal kilde-, fixture-, browser- og avgrenset testarbeid fortsetter selv om en tung bygge-/privilegert CI-gate er sperret. Dokumenter reelle begrensninger i stedet for å vente gjennom natten uten nytt arbeid.

Nattplan: oppfølging i denne oppgaven23:00,01:00,03:00,05:00 og07:00 Europe/Oslo, bare natt14.–15.september. Ingen andre automasjoner skal endres. Ved hvert gjenopptak: les denne filen og siste CHECKPOINT, fortsett fra faktisk status, ikke start fra nytt. Avslutt nattarbeidet med oppsummering siste kjøring; ikke forleng automatisk til nye netter. Lokalt arbeid krever at maskinen og desktop-appen kjører.

## Kildeinnganger

- Documentation/SkeletonParitySuite.md og SkeletonPortabilityRequirement.md
- BindingTests/SkeletonRendererParityTests.swift, CellConfigurationVerifierXCTest.swift, SkeletonParityRemoteXCTest.swift, SkeletonPresentationOverlayTests.swift, ChatWorkbenchParityTests.swift
- CellProtocol/Sources/CellBase/CellConfiguration/CellConfiguration.swift og Skeleton/SkeletonDescription.swift; Tests/CellBaseTests/SkeletonTests.swift
- CellProtocol/Sources/CellApple/Cells/Porthole/Utility Views/Skeleton/Suggestion/SkeletonView.swift og SkeletonParityRenderer.swift
- CellScaffold/package.json, playwright/skeleton-scenarios, scripts/skeleton-iterate.js
- Personkobling: Documentation/Personal_Entity_Link_Test_Runbook_2026-09-11.md
- Nattartefakter: Implementation/ParityNight-20260914/

## Første friske baseline — 14.september kl.22:30 CEST

Begge offentlige /skeleton-parity/api/catalog-endepunkter på staging og prod svarteHTTP200 med samme4490byte JSON og SHA256aae28a2bf2f5126279e0c5fb167bb2be64448ff599dd0f607da20b5fdd3b3333. Katalogen har10 fixtures. Dette er faktisk tilgjengelighet av fixturekatalogen, ikke bevis for rendering, handlinger eller en autentisert cellebro. Ingen innlogging, private entiteter eller mutasjoner ble brukt. Rårespons og metadata ligger i Implementation/ParityNight-20260914/.

Automatiseringen haven-paritet-i-natt er opprettet og lagret som aktiv heartbeat på denne oppgaven, bare på de fem planlagte tidspunktene. Åpne Codex og en påslått Mac er nødvendig for lokale kjøringer; automatiseringen er ingen garanti for at maskinen er tilgjengelig eller at alle native tester kan kjøres.


## Frisk delrapport — natt til 15. september, første native sammenligning

[Oppdatert paritetsmatrise](../Implementation/ParityNight-20260914/PARITY_MATRIX.md) inneholder faktiske bilder, før/etter-funn og gjenværende mangler. Alle ti web-fixtures er fotografert i bredt og smalt format; ni gyldige fixtures er også renderert med ekte Binding/CellApple i en isolert macOS-testvert. Web-skjemaets fyll/lagre/gjenåpne/reset er gjennomført.

Isolerte kandidater retter tap av radtekst, dupliserte SwiftUI-rad-ID-er, manglende lokale grid-data, utilsiktet høydeutvidelse og vertikal sentrering av korte flater. En CSS-kandidat fjerner horisontal overflow fra lange adresser på telefonbredde. 13 målrettede native tester består. Faktiske bilder/OCR bekrefter tre ulike listerader, tre grid-kort og begge relative rader i begge bredder. Full visuell paritet, vanlig appoppstart, chat, iPhone, autentisert transport og entitetskobling er fortsatt åpne. Ingen kandidat er installert eller deployet; originalenes kildefiler er bevart.

## Delrapport kl.03:25 — iOS og chat er nå faktisk renderert

Samme isolerte kandidat er bygget og kjørt i iOS26.2 og18.6-simulatorer. Fem flater er fotografert på hver: tekst, liste, grid, form og chat. Eget testapp-ID gjør at vanlig HAVEN er bevart. Appens nåværende minimum er iOS18.0. Dette er simulator- og rendererbevis; fysisk telefon, QR/nærhet, autentisert transport og entitetskobling gjenstår.

En ny fanerettelse gjør at native bruker de leverte etikettene og valgt fane, og fjerner hjelpeflater når listen er tom. Førbildet viste alle hjelpere selv om ingen var aktiv. Etterbildene på begge iOS-versjoner viser at feilen er rettet. 14 målrettede tester består, inkludert en faktisk renderingstest med tom, fjernet og oppdatert faneliste. Originalenes kildehasher er fortsatt uendret; kandidatpatchene kan anvendes uten konflikt.

Staging Porthole krever innlogging, så hele bibliotek-/chatreisen er ikke gjennomført. Chat-sammenligningen bruker virkelig chatkonfigurasjon og state fra en celle med identitet bare i RAM, uten personhistorikk eller melding til noen modell. Web og iOS bruker identisk frosset payload; Mac regenererte UUID-er og tidsstempler fra samme factory. Full visuell paritet er fortsatt åpen, særlig justering, felt, knapper og editorhøyde. Se [bilder og oppdatert matrise](../Implementation/ParityNight-20260914/PARITY_MATRIX.md) og [runde03-notater](../Implementation/ParityNight-20260914/PHASE2_NOTES.md). Begge testapper er avsluttet; neste planlagte runde er kl.05 og samlet morgenrapport kl.07.


## Delrapport kl.05:50 — faktisk UI-bruk og visuelle rettinger

Sluttkandidaten består **15 Mac-regresjoner og4 iOS26.2 UI-forløp**,0 feil. Nye rettinger gir leading-justering, kompakte badges, tydelige felt/knapper, bedre editorhøyde og knappetreffområde, hele kompakte bibliotekfaner og en chatlogg som kan rulles uavhengig. Med tastaturet oppe holdes editor og sendepil synlige sammen. Innvendige faner deler nå én tastaturverktøylinje.

Det er kjørt ekte typing, trykk i knappens padding, bibliotekets avvisning/oppdatering/lukking, fanevalg og scrolling til melding12. Dette skjer i en isolert testvert: biblioteket avviser autentisering, formhandling avvises uten identitet, og ingen chatmelding sendes. Resultatene beviser de konkrete UI-forløpene, ikke fungerende autentisert tjenestetilgang.

20 nye Mac-bilder og fem nye bilder på hver av iOS26.2 og18.6 er lagret. Mac bruker nå eksakt samme frosne chatpayload som web/iOS. Ti UI-skjermbilder dokumenterer forløpene. Seks eksakte OCR-kontroller av liste/grid/relative rader passer; chat er visuelt bekreftet, med eksplisitt registrert Å/Apne-OCR-avvik i kompakt Mac. Små Mac-borderartefakter og øvrige åpne tema-/komponentgap er ikke skjult.

[Oppdatert matrise med bilder](../Implementation/ParityNight-20260914/PARITY_MATRIX.md), [konkret testoppskrift](../Implementation/ParityNight-20260914/TEST_RUNBOOK.md) og [maskinlesbar verifikasjon](../Implementation/ParityNight-20260914/VERIFICATION.json) beskriver hva som faktisk kan prøves. Produktpatchene er regenerert og kan anvendes uten konflikt; originalkildene er uendret. Normal HAVEN og den signerte telefon-IPAen inneholder ikke nattens rettinger. Fysisk personkobling, autentisert chat/bibliotek og datatilgang er fortsatt åpne. Ingen commit, CI, deploy eller personlig kobling er gjort i denne runden. Siste planlagte morgenrapport er kl.07.


## Nattarbeidet avsluttet kl.07

[Samlet morgenrapport med før/etter-bilder og pass/fail](../Implementation/ParityNight-20260914/MORNING_REPORT.md) er levert. Sluttkontrollen bekrefter de19 beståtte testene fra siste kandidatrunde, eksisterende simulatorprodukt og uendrede originalkilder/patcher. Ingen nye tester eller produktendringer kl.07. Den separate simulatorappen er klar for de avgrensede UI-forløpene; vanlig HAVEN og hele personkoblingen er fortsatt ikke klare til ende-til-ende testing. Nattplanen er fullført, og haven-paritet-i-natt er satt på pause uten nye kjøringer.
