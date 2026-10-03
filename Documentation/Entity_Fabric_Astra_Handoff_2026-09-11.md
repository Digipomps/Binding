# Astra-handoff: autorisert entitetsdata på tvers av scaffolds

work_id: entity-fabric-20260911
status: IN_PROGRESS
dispatched_task: 01a090e0-cced-7351-a2b1-f82408848442
active_worktree: /Users/kjetil/.codex/worktrees/c8a4/CellScaffold
created_at: 2026-09-11
owner: ny Astra-oppgave, bestilt av Kjetil
integrator: mottakende Astra for dataarbeidet; denne Binding-oppgaven for kobling/nærhet
repo: CellScaffold, med koordinerte endringer i CellProtocol, sprout og klienter ved behov
base_ref: origin/main, må kontrolleres på nytt før implementasjon
target_branch: egen codex/-gren i isolert worktree

## Mandat fra Kjetil

**Presisering fra Kjetil 2026-09-11:** Det er menneskers entiteter som kobles, ikke scaffoldene. Opplevelsen er å utvide egne muligheter ved å koble egne entiteter på tvers av steder. Personens to eierskapsbevis må være autoriteten. Scaffold-admin, sprout «Scaffold»-nøkkel og agentens tjenestenøkkel er separate tekniske identiteter; de skal aldri bli personens `same_entity` bare fordi de drifter samme maskin. Agenten handler med personens avgrensede delegering. Revider brukerflyt, modeller og tester etter denne grensen.

Forsk, analyser, implementer og test tilgang til å lese, skrive og indeksere entitetsdata over alle scaffolds der samme entitet er autorisert til stede: HAVEN på telefon/Mac, lokal agent, menyhjelper, sprout, staging og prod. Gjør det mulig å velge bedre tilgjengelighet ved å flytte eller replikere utvalgte lokale entitetsdata til prod. Promoter gjennom prosjektets deployment-løp når implementasjonen er robust og dokumentert klar for prod.

Start med et kildebasert design og gjennomfør deretter arbeidet. Ikke stopp ved en rapport. Eksisterende kobling på en vert er ikke dokumentasjon på at alle andre verter har samme entitet eller samme tilgang. Kjetils antakelse er at sammenhengende kobling foreløpig mangler; verifiser, ikke normaliser ID-er eller nøkkelfiler for å få et positivt resultat.

Arbeidet med tjenestefunksjonalitet og promotering er bestilt. Kjetil har ikke bestilt en konkret overføring/sletting av sine eksisterende private data nå. Lag gjennomgåbar flytte-/replikeringsplan og test med syntetiske eierdata. Be om valg av faktiske data og mottakere før privat migrering. Ikke gjør staging til tillitsrot for prod eller importer agentens administrative rettigheter som personlige eierrettigheter.

## Eksklusiv grense mot pågående arbeid

Den opprinnelige oppgaven arbeider med telefonkobling, QR, Network-basert nærhetsinngang, agent/hjelper/sprout-integrasjon og praktiske to-enhetstester. Dens isolerte checkouts ligger under:

`/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/EntityContinuity-20260911/{CellProtocol,Binding,sprout}`

Ikke endre disse checkoutene. Ikke endre `ScannerService`, ny nærhetstransport, Binding `IdentityLinkFlow`, kamera-/koblings-UI eller de samme sprout-CLI-filene uten koordinering. Du eier dataoperasjoner, plassering, lesing/skriving, autoriserte spørringer/indekser, replisering/migrering, persistens og relevante CellScaffold-adaptere. Send kontraktbehov til opprinnelig oppgave. Separate repoer og egne commits; ingen omskriving av andres arbeid.

## Verifisert grunnlag og ferskhetsbegrensning

Kontrollert 2026-09-10: Binding PR #30 merget 2026-09-09 (`3c712731b4ace977b5bc0786d73b6158d392456a`), CellScaffold #223 merget 2026-09-09 (`6b666b2f69a5c6ff83b2d7c1a3ca3bc36dd5c0d2`), CellProtocol #33 merget 2026-09-05 (`c500672cc10eadbd30b6fea5e108da75a6e9a03a`). De gir QR/passkey-kobling, `same_entity`-register og runtime-policy. Dette beviser ikke dagens drift, sikkerhetsdekning eller installert revisjon. Kjør handoff-ferskhetskontrollen, undersøk nyere arbeid og gjenbruk det som har landet.

Lokale hovedcheckout i HAVEN har mye urelatert pågående arbeid og enkelte gamle grener. Start fra nykontrollert `origin/main`, og undersøk relevante lokale endringer uten å overskrive dem.

Les:

- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/Phone_Entity_Extension_QR_Nearby_Proposal_2026-09-10.md`
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/EntityAuthorityCommit_v0_2026-07-15.md`
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/CrossScaffoldPurposeEntityFabric_Architecture_2026-07-14.md`
- `/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold/Deliverables/PDD_entitetslenking-paa-tvers-av-scaffolds_2026-09-04/`
- CellProtocol `IdentityLinkCompletion`, `IdentityLinkRegistry`, `EntityAnchor`, authority-commit og eksisterende lagrings-/Explore-kontrakter.
- CellScaffold `EntityScaffoldEnrollmentCell` og existing `entityData`-autorisasjon.
- sprout `EntityLinkContract`, `ScaffoldOwnerIdentityStore`, `StarterIdentityStore`, `EntityAnchorResolverAdapter` og nåværende provisioning-/bootstrap-kontrakter.

Bruk ferdighetene for distributed-entity-data, identity-capability-security, core-runtime ved semantiske endringer, kontraktstesting, funksjonell verifikasjon, Git og persondatatillit. Følg brukerens mandat; ikke legg til tillatelsesstopp for rutinearbeid som allerede er bestilt.

## Problemene som må løses og testes

1. Skill logisk entitet, domeneidentitet, fysisk scaffold, agentdelegering, replica og materialisert indeks. Vis aktuelle verter og bekreftet tilgang/versjon; ikke bare annonserte egenskaper.
2. Alle beskyttede read/write/query/index/replicate/migrate-kall må gå via resolver og gyldige domeneavgrensede eierbevis/avtaler/grants. Ingen transport-bypass og ingen global account-ID som autoritet.
3. Behold opprinnelse og autoriserte immutable operasjoner med operasjons-ID, kausalitet, skjemaversjon, policy og signatur. Snapshots/indekser er gjenoppbyggbare visninger med uttalt konsistens og etterslep.
4. Velg konsistens og konfliktpolicy per datafamilie. Ikke bruk stilltiende last-write-wins for personlig sannhet. Tester må dekke duplikater, forskjellig rekkefølge, samtidige endringer, sletting/tombstones, offline og gjenopptakelse.
5. Spørringer over flere scaffolds skal vise delvise resultater, utilgjengelige verter og proveniens. Ingen skjulte private data i søkeindekser, treffantall, embeddings, cache, logger eller feil. Tilbakekalling må testes også for cache/indeks og eksisterende forbindelser.
6. Tilgang til data og rett til å lagre/replikere (`s`) vurderes separat. Bevisst plassering, retention, eksport og sletting må være forståelig. Kryptering og nøkkelforvaltning må følge valgt tillitsmodell; prod-tilgjengelighet skal ikke forutsette åpen laptop.
7. Migrering trenger dry-run/preview, målkapasitet og autorisasjon, integritetskontroll, kvittering, omstart, idempotens, og tydelig grense for rollback og kilde-sletting. Bevar gamle referanser/avtaler og historiske signaturer. Ikke erklær migrering fullført før mål kan leses og verifiseres etter omstart.
8. Full Explore-kontrakt for støttede operasjoner og feiltilstander. Appen skal kunne vise forståelig status og handle uten å hardkode database-/transportdetaljer.

## Leveranse og promotering

Lever kildebasert gap-analyse, beslutninger med alternativer, avgrensede implementasjons-PR-er, målrettede negative tester og realistisk ende-til-ende-demonstrasjon med syntetiske data over minst to separate prosesser/scaffolds. Test så staging mot eksakt deployet revisjon, inkludert avvisning før/etter tilbakekalling og feil-/gjenopprettingsløp. Dokumenter residuale antakelser og hva som faktisk er kjørt.

Promoter via eksisterende release-/deploy-prosess når kriteriene er oppfylt, med reviewbare endringer, kontrollerte migreringer, rollback og produksjonssmoke. Følg reelle gjeldende deploy-grenser; ikke behandle en grønn enhetstest eller bare vellykket deploy som bevis på robust prod-drift. Hvis eksplisitt menneskelig godkjenning gjenstår i prosessen, gjør den konkrete releasen helt klar til det steget.

Oppdater denne oppgavens eget varige arbeidsspor med kilde-revisjoner, filer, verifikasjon og åpne punkter. Rapporter ingen «sømløs» eller prod-klar tilstand før brukerreisen og negative sikkerhetsbaner er vist. Lagre kontekst før vinduet fylles.

## Konkret overlevering 11. september, etter implementert personseremoni

Koblingsklienten er reviewbar i Binding PR32, kode `b12b0414`, med CellNearby `436b6a7` (CellProtocol PR38), sprout-inngang `4a5b3ef` (PR2; verifisert PATH-/symlink-oppslag for nærhetsprogrammet) og menyhjelper `022661a` (PR15). Signert iOS-utviklerbygg er laget med eksisterende profil og signaturverifisert. Ingen fysisk installasjon eller personkobling er gjort. Prøveoppskrift: `Personal_Entity_Link_Test_Runbook_2026-09-11.md`.

CellScaffold personkandidat `5ee51e68` besto hele CI34619634244. Oppfølging `746e66ee` bygget alle mål i CI34629774748. Swift-bolk 1–24 og 16 av 17 tester i bolk 25 besto. En feil bruk av ValueType-objektlikhet er rettet til kanonisk JSON i lokal commit `ac2531f2`, og tatt inn i dataoppgavens samlede neste CI. Admin/P0 besto; dokumentprøven venter fortsatt på avklaring etter manglende lagret-status ved linje 23. Videre serververifikasjon og promotering følger dataoppgaven. Oppfølgingen inkluderer avventet runtime-policyinstallasjon, eksisterende-person-oppslag uten provisjonering fra åpen completionroute, og reelle HTTP-/P256-/retry-/revoketester. De tilsvarende endringene er allerede tatt inn i dataoppgavens gren. Klientens avbruddsretting b12b0414 har 12 beståtte koblingstester; den eldre IPA-en 3a41745f er erstattet av signert b12b0414. Telefonen lagrer eksakt, lokalt verifisert completion-envelope kryptert før første remote mutation; ved omstart tilbyr den eksplisitt gjenopptaking. Nåværende serverbekreftelse kreves før lokal kvittering/aktivering. Kvitteringsreferansen fra den andre personentiteten er ingen gjensidig datafullmakt.

Dataoppgaven eier videre en egen Binding-klient for den nye, personinitierte HTTPS-rute/scopes-descriptoren i separat arbeidstre og avgrenset fil. Den aktive koblingsklonen skal ikke endres av det arbeidet. Hent eksakte Cell-ID-er gjennom autentisert, signert forespørsel, og bind forbindelsen før WebSocket-oppgradering. Behold opprinnelig linked requester og eksisterende per-operation proof scopes. Ikke bruk teknisk starter-/admin-kontrakt som personmyndighet. Dette var fortsatt et faktisk produksjonsgap ved overlevering, ikke en eksisterende rute som bare manglet dokumentasjon.

Sprout-oppgaven «Lag prompt for distribuert HAVEN» trenger også en terminal-initiert person-/device-godkjenning uten innlimt QR/deep-link, nettlesercookies eller nøkkelimport. Den nåværende `sprout entity connect` er en inngang/locator, og på Linux skriver den nettadressen. `haven-nearby` bruker Apples Network; dette er ikke en Linux-radioadapter. Ingen eksisterende godkjent loopback/device-code-kontrakt ble funnet. Passkey-godkjenningen skal fortsatt utføres av mennesket.

Ny, samtidig sprout-onboarding har egne nøkkel-/tilstandsherdinger og `OnboardingCommand.swift`; bevar disse ved samordning. Vår omdøping `main.swift` til `SproutCLI.swift` må flettes med terminaldispatch, ikke overskrive den. Sprout-oppgaven rapporterte separat at staging sin tekniske trust-root-descriptor var utløpt; fornyelse/deploy eies og godkjennes der, uten trust-bypass. Dette funnet sier ikke alene at personens QR-seremoni eller HTTPS er ugyldig.

Den eksisterende AppleBridgeTransport kan ikke bare få en autentiseringsheader: setup erstatter injisert forbindelse, mens utelatt setup mangler lokal identitet/vault. Dataoppgaven lager derfor en avgrenset Binding-transport med eksisterende BridgeInboundPayloadValidator/BridgeBase og eksakt personidentitet. Verifiser den faktiske signeringshandshaken, omstart og manglende nøkkel; ingen ny identitet skal opprettes for å få en gjenåpning til å virke. Dette er fortsatt arbeid under implementasjon, ikke en produksjonsklar rute.

## Avklaring av verifikasjonsmandat — 2026-09-11 23:06 CEST

Formuleringen «ingen ekstra CI ønskes fra min side» gjaldt å unngå en duplisert serverkjøring bestilt fra koblingsoppgaven. Den begrenser ikke nødvendig native klientverifikasjon i dataoppgavens eksisterende mandat fra Kjetil. Dette er presisert til oppgave 01a090e0-cced-7351-a2b1-f82408848442: én avgrenset macOS-jobb, maks 40 minutter, Swift-parallellitet 2 og de sju PersonEntityReadClientTests, med eksakte kildeversjoner og eksisterende legitim FileUtils-c-checkouttilgang. Ingen nye secrets/tokenrettigheter, signeringsnøkler, deploy eller budsjettendring. Hard budsjettstopp beholdes; rapportert forbruk kan etterslepe. Dette er nødvendig testarbeid under opprinnelig bestilling, ikke ny godkjenning av core-authority, kjøp eller produksjonsutrulling.

Dataoppgaven rapporterer at samlet serverrun 34646150071 fortsatt går. Native klientjobben var ikke startet ved forespørselen om denne avklaringen. Ingen native testresultater eller fysisk enhetsbevis er dermed registrert her ennå.

## Korrigert native preflight — 2026-09-11 23:52 CEST

Dataoppgaven rapporterte at native CI34650873713 stoppet etter ca.14sekunder før bygg/test fordi preflight feilaktig krevde samme CP-pin i prosjekt og ytre workspace. Lokal retting258d70776c8138b52cf3b1743f2a32dca90844e6 er avgrenset til native-workflow, preflightscript, tester og dokumentasjon; ingen låsefil ble endret. Root har kontrollert de faktiske tidligere kommandologgene: både macOS12-testpass og signert b12-iOS-bygg brukte `-project Binding.xcodeproj`, ikke ytre workspace.

Det korrigerte forsøket kan kjøres med maks39minutter, samme sju tester/parallellitet2/eksakte Binding4b0b1959/pins/eksisterende tilgang og hardt budsjett. Root presiserte sin egen ramme som én samtidig native-jobb og samlet runner-tid innen40minutter for runden, ikke et forbud mot feilbegrunnede preflightrettinger innen resttiden. Dette er nødvendig testarbeid under opprinnelig mandat; ingen ny brukeravklaring kreves for det.

Ingen generell server-CI-policy skal svekkes. Hvis akkurat den avgrensede native-rettingen automatisk utløser en ny redundant serverjobb, kan dataoppgaven identifisere og kansellere kun den nye jobben på eksakt ny commit før tung bygging. Serverrun34650846164 og andre kjøringer skal være urørt. Kansellert/utelatt er aldri grønt; alle merge/deploy-gater gjelder fortsatt.

## Verifikasjonsoppfølging — 2026-09-13

Den integrerte serverkandidaten `44f7739738fce0f7acb43469f074322ac4f84357` har bestått [CI34650846164](https://github.com/Digipomps/CellScaffold/actions/runs/34650846164). Root kontrollerte GitHub-resultatet direkte: kjøringen er avsluttet med `success`; «Focused control-plane gates», bygg av alle mål, testdekning, fokuserte Swift-gater og Admin-nettgatene besto. Publisering av signert kilde-/imagepar var `skipped`; dette er ikke en utrulling. Dataoppgaven rapporterer at alle 25 Swift-bolker, Thursday P0 og den faktiske live-dokumentprøven besto, inkludert syntetisk personrute, eldre bridge og HTTP-completion med eksakte scopes. De opprinnelige røde resultatene på `746e66ee` beholdes nedenfor som historikk for den tidligere kandidaten.

Den separate native dataklienten er fortsatt under verifikasjon. Dataoppgaven rapporterte at CI34651573192 besto preflight/avhengighetstilgang, men feilet ved kompilering etter 3m11s. Binding `6159733c93ab2933d485b739d8d4dc6575b019bb` retter tilordningen til `self.deadline`; korrigert kjøring av de samme sju testene er fortsatt avventet her. Ingen ny kildepinne eller koblings-IPA er innført av denne oppfølgingen. Den signerte telefonkandidaten er fortsatt `b12b0414`.

Dette beviser serverens automatiserte testgater. Fysisk Binding/TLS/passkey-seremoni, radio mellom to enheter, faktisk personkobling og utrulling er fortsatt ikke verifisert eller utført av denne oppgaven. Dataoppgaven «Entitetsdata på tvers av scaffolds» eier videre klientverifikasjon og serverpromotering. Koblingen tilhører menneskets entiteter; scaffold-/administrator-/agentnøkler gir ingen personmyndighet.

## Native verktøykjedeoppfølging — 2026-09-13

[Native CI34779171932](https://github.com/Digipomps/CellScaffold/actions/runs/34779171932) på workflow-revisjon `f8c6902578ca119f4eb2088f0627d8dbba1abd73`, med Binding-klient `6159733c93ab2933d485b739d8d4dc6575b019bb`, er avsluttet med `failure` etter 3m32s. Resultat og jobbvarighet er kontrollert direkte gjennom GitHub. Dataoppgaven rapporterer at `deadline`-feilen er borte, og at Xcode26.2 nå stopper i tre `nonsending`/`ValueType`-konverteringer i den uendrede FullLibraryView.swift. Native klienttester er dermed fortsatt ikke bestått.

Root kontrollerte Info.plist i den tidligere beståtte lokale testverten `/private/tmp/haven-person-link-cancel-products/HAVEN.app`: DTXcode2630, DTXcodeBuild17C519, macosx26.2, SDK25C58. Dataoppgaven tilpasser derfor kun CI-verktøykjeden til Xcode26.3; oppgitt runner-build17C529 er ikke identisk med lokal17C519. Om dette løser kompileringen er fortsatt uverifisert. Binding6159733c, avhengighetspinner, sju tester og parallellitet2 beholdes; ingen bibliotekendring eller omgåelse av Sendable-kontroller er avtalt.

Det feilbegrunnede forsøket følger eksisterende mandat og samlet40minutter/hardt60USD budsjett. Rapportert brukt runnertid417s pluss ny maks32minutter gir38m57s totalt. Bare en eventuelt ny, redundant serverjobb på den eksakte workflow-rettingen kan kanselleres før tungbygg. Grønn serverrevisjon44f77397 og CI34650846164 bevares. Ingen ny root-kjøring, personkobling, telefoninstallasjon eller utrulling.

## Native byggproveniens — 2026-09-13

[Native CI34779657343](https://github.com/Digipomps/CellScaffold/actions/runs/34779657343), workflow `e3dd2f40641334ccf899b15a80f4b3f0a240d7a1` med uendret Binding6159733c/pins, er avsluttet med `failure` etter4m40s. Resultat og varighet er kontrollert direkte. Dataoppgaven rapporterer at Xcode26.3 kom forbi FullLibraryView-feilene, kompilerte de nye filene og linket HAVEN. Ingen tester kjørte: Embed Build Provenance stoppet før testene.

Root kontrollerte jobbloggen: TOOLCHAIN_DIR peker på runnerens Metal.xctoolchain; feilen er manglende `Metal.xctoolchain/usr/bin/swiftc`. Kildeklonens `Scripts/generate_binding_build_provenance.sh:21` bruker TOOLCHAIN_DIR til dette oppslaget og senere til kompilatorens versjon/hash. Dataoppgaven undersøker en avgrenset retting som identifiserer den faktisk valgte Swift-kompilatoren. Provenienskontroll, kontrollert avslag ved manglende input og Xcode-sandbox skal bevares. Rettelse og tester er fortsatt ikke verifisert.

Rapportert akkumulert native runnertid er697s (11m37s). En konkret neste retting kan testes med maks27minutter innen eksisterende samlet40minuttersramme (38m37s totalt); hardt60USD-budsjett gjelder fortsatt. Rapportert forbruk52.348USD har sistepost19:59:19Z og er ikke et endelig kostnadsregnskap for de senere kjøringene.

[Duplisert server-CI34779622138](https://github.com/Digipomps/CellScaffold/actions/runs/34779622138) på samme workflow-revisjon er kontrollert terminal `cancelled`. Den rakk å starte «Build every target»20:05:52UTC, før kansellering20:08:37UTC. Denne kjøringen var dermed ikke stoppet før tungbygg og har brukt byggetid. Den tidligere grønne serverrevisjonen44f77397/CI34650846164 bevares. Ingen testpass, personkobling, telefoninstallasjon eller utrulling følger av denne oppdateringen.

Oppfølging av kompilatoroppslaget: Root kontrollerte at CI-loggens DT_TOOLCHAIN_DIR er `/Applications/Xcode_26.3.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain`, og at de kontrollerte SwiftDriver-invokasjonene bruker `usr/bin/swiftc` der. Dataoppgaven prøver en avgrenset unsigned-test-wrapper med det bokstavelige Xcode-byggargumentet `TOOLCHAIN_DIR=$(DT_TOOLCHAIN_DIR)`, slik at Binding6159733c og selve provenance-scriptet kan forbli uendret. Argumentets skallhåndtering skal testes, og faktisk Xcode-resolvert kompilator/proveniens skal kontrolleres i neste bygg. Et lokalt argumenttestpass alene beviser ikke at byggproveniensen eller de sju native testene består. Dette er fortsatt en planlagt retting, ikke et testresultat.

## Native klienttester bestått — 2026-09-13 20:24 UTC

[Native CI34780399412](https://github.com/Digipomps/CellScaffold/actions/runs/34780399412), jobb103786246272, besto på workflow/wrapper `a5737b9e6ce9b08f9b2214cd913e087deea7faaf` med eksakt Binding-klient `6159733c93ab2933d485b739d8d4dc6575b019bb`. Root kontrollerte GitHub-resultatet og den faktiske testloggen: alle sju PersonEntityReadClientTests besto, med0feil; gaten som krever nøyaktig sju beståtte tester og kontrollen av attestert kompilator mot faktisk Swift-invokasjon besto også. Jobben varte286s (20:19:25–20:24:11UTC). Dataoppgaven oppgir uendrede pins, Binding-kilder og provenance-script, samt samlet native runnertid983s (16m23s).

Testene dekker eksakt opprinnelse/kvittering/nøkkel/scopes, avvisning av endret bevisreferanse og feil/manglende nøkkel, og kontroll av komplette/delvise/avviste datasvar. Dette er klientkontraktprøver, ikke bevis for en faktisk native socket-/TLS-forbindelse eller fysisk passkey-godkjenning. Disse brukerløpene og koordinert utrulling gjenstår hos «Entitetsdata på tvers av scaffolds». Serverkandidaten44f77397 har tidligere bestått CI34650846164. Ingen faktisk personkobling eller dataflytting er utført av root.

Den eksisterende signerte telefon-IPA-en b12b0414 er uendret. Den skal ikke omtales som et nytt signert bygg som inneholder dataklient6159733c. Dataoppgaven rapporterer at ny duplikatserverjobb34780370564 ble kansellert under containeroppsett mens bygg ennå var avventet; dette er separat fra den forrige jobben34779622138, som faktisk rakk å bygge. Hostens kapasitetskontroll avviser fortsatt nye lokale bygg ifølge dataoppgaven; den skal bevares.

## Neste prøve: faktisk native TLS — forberedt, ikke kjørt

Dataoppgaven har forberedt [TLS-prøveoppskriften](/Users/kjetil/.codex/worktrees/c8a4/CellScaffold/Documentation/Person_Entity_Native_TLS_Proof_2026-09-13.md). Root har lest oppskrift og konkret foreløpig workflow/harness/Swift-test. Den uendrede production-klienten PersonEntityReadClient og URLSession skal snakke med den eksisterende faktiske serverruten i en separat testprosess: signert HTTPS-discovery, WSS, to lesinger, tilbakekalling på åpen forbindelse, avvist ny discovery og avvist feil TLS-vertsnavn. Identitetene og WebAuthn-verifikasjonen er syntetiske. En kortlivet test-CA og staging-vertsnavn mappet til127.0.0.1 brukes bare på en disponibel hosted CI-VM; testen skal avvise øvrig DNS. Dette er ikke trafikk mot faktisk staging eller en fysisk passkey-prøve.

Review fant avgrensede harness-punkter som er sendt til dataoppgaven før kjøring: sørg for at SIGTERM utløser opprydding av egne prosessgrupper; valider den dedikerte RUNNER_TEMP-banen også i Swift-testen; avbryt ved ugyldig setup-marker før nettverk. CA-opprydding som ignorerer feil må beskrives som best-effort eller verifiseres, med VM-destruksjon som siste grense. Workflowens endelige uforanderlige Binding-testrevisjon og negative harness-kontroller er fortsatt under ferdigstilling.

Planlagt ramme er én jobb med20minutters hard timeout, sekvensielt serverbygg og Binding-bygg, deretter prebygd server med --skip-build mens testen kjører. Dette gir høyst36m23s sammen med den tidligere native-rundens983s. Kapasitetskontroll40GiB/10%, parallellitet2, eksisterende avhengighetspinner/tilgang og hardt60USD-budsjett beholdes. Målte22m25s for Linux-serverbygg er ikke et anslag for denne macOS-jobben; timeout kan gi ufullført prøve. Ingen TLS-kjøring eller lokale trust-/hosts-endringer er utført av root. De sju native klienttestene og tidligere server-CI er fortsatt bestått; faktisk TLS-brukerløp er avventet.

## TLS-forhåndskontroll stoppet på port443 — 2026-09-13 21:04 UTC

[TLS CI34782683026](https://github.com/Digipomps/CellScaffold/actions/runs/34782683026), workflow809a2256d02612502f431aee37749dce80abf9b1 og jobb103792441400, feilet etter28s. Root kontrollerte resultat og logg. De fem harness-kontrollene besto: avvisning uten hosted-markører, dedikert bane/symlink-kontroll, avvisning av lokale trust-/runtime-handlinger, kontroll av mislykket CA-opprydding, og SIGTERM-opprydding av egne stubprosesser uten å berøre uvedkommende prosesser. Portprøven127.0.0.1:443 fikk deretter PermissionError13. Serverbygg, trustoppsett og native TLS-test ble ikke kjørt. Cleanup besto og bekreftet at ingen syntetisk CA var opprettet.

Dataoppgaven forbereder en avgrenset retting i CI-hjelperen: bind bare127.0.0.1:443 med nødvendige rettigheter, og slipp til verifisert runner-UID/GID før sertifikater leses eller TLS håndteres. Root har lest foreløpig kilde; dette er fortsatt uverifisert. Negative kontroller av eier/sudo-opphav og mislykket rettighetsreduksjon samt opprydding gjennom den nye sudo-starten er sendt som konkrete reviewpunkter. De tidligere grønne avbruddstestene med vanlige stubprosesser beviser ikke alene opprydding gjennom sudo-monitor/prosessgrupper.

Samlet rapportert brukt native/TLS-runnertid er1011s. En konkret korrigert jobb med20minutters timeout gir høyst36m51s innen eksisterende40minuttersramme; budsjett og øvrige kapasitets-/kildekontroller beholdes. Binding/server skal ikke kjøre som root. Ingen ny rettet TLS-kjøring er meldt startet i denne oppfølgingen, og ingen lokal trustendring eller privilegert prøve er utført av root. De sju native klienttestene og tidligere server-CI er fortsatt bestått; selve TLS-prøven mangler fortsatt et resultat.

## TLS-preflight og lokal accept-prøve — 2026-09-13

[TLS CI34783927301](https://github.com/Digipomps/CellScaffold/actions/runs/34783927301), jobb103795838672, feilet etter28s på CellScaffold9e57f3bdfc7716ca1f63dccb931983821aee56f7 med Binding71f916e998c7d256b3eda7bc158b98a093cddf9f. Root kontrollerte GitHub-resultat og artefakter: alle14 harness-kontroller besto på5.633s, den kortlivede bind-hjelperen slapp rettighetene og overførte deskriptoren, men mottakeren stoppet på SO_ACCEPTCONN med ENOPROTOOPT42. Serverbygg, trustoppsett og native TLS-test ble utelatt; cleanup og uendrede pins besto. Dette er fortsatt ingen utført TLS-prøve.

Dataoppgaven har konkretisert rettingen til en ikke-blokkerende accept-prøve etter kontroll av IPv4, eksakt127.0.0.1:443 og TCP-type. Bare EAGAIN/EWOULDBLOCK godtas. EINVAL/andre feil avvises; en uventet akseptert forbindelse lukkes og avvises. Root har lest denne foreløpige funksjonen og kontrollert [Apples accept(2)-dokumentasjon](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/accept.2.html): en tom ikke-blokkerende lyttekø gir EWOULDBLOCK, mens en socket som ikke kan akseptere gir EINVAL.

Root kjørte også en reell, liten Python/socket-prøve på lokal macOS26.5.1, uten sudo, sertifikater eller bygg, kun på en OS-valgt ledig127.0.0.1-port. Bundet ikke-lyttende TCP ga EINVAL22; SO_ACCEPTCONN på lyttende TCP ga ENOPROTOOPT42; tom ikke-blokkerende lyttekø ga EWOULDBLOCK35; en opprettet loopback-forbindelse ble akseptert og lukket. Alle sockets ble lukket. Den første sandboxede kjøringen ble nektet ved bind; vanlig nettverkstilgang via godkjent verktøyeskalering lot den samme avgrensede prøven kjøre. Ingen automatisk godkjenningsavvisning. Evidensen ligger i `Implementation/EntityContinuity-20260911/Artifacts/MacOS-Accept-Probe-20260913.json`. Dette verifiserer syscall-oppførsel på lokal høy port, ikke korrigert hosted FD-overlevering, TLS eller en personseremoni.

Dataoppgaven fortsetter innen rapporterte1039s brukt pluss neste maks20minutter, altså høyst37m19s av40minuttersrammen, med uendret hardt budsjett. Ingen korrigert kjøring er rapportert startet her. Tidligere grønn server44/CI34650846164 og grønn615-klient med sju tester/CI34780399412 beholdes. Phone-IPA b12 inneholder fortsatt ikke den separate dataklienten.

## TLS-runtime nådd; native-steg feilet og cleanup uavklart — 2026-09-13

Ett direkte GitHub-snapshot av [TLS34784197977](https://github.com/Digipomps/CellScaffold/actions/runs/34784197977), jobb103796582540, bekrefter CellScaffoldc3aaaf1592a73e7b2e81f4a8415118f49631f43c. Binding-testkandidaten er ifølge dataoppgaven uendret71f916e998c7d256b3eda7bc158b98a093cddf9f. Faktisk FD-preflight besto. Server-testbundle besto etter449s (21:34:18–21:41:47UTC), og syntetisk trustoppsett besto. Steget for native TLS mot separat serverprosess feilet etter333s (21:41:47–21:47:20UTC). Testsummary/proveniens-gaten ble utelatt. Jobben og CA-/hosts-oppryddingen var fortsatt pågående ved dette snapshotet; dette er ikke et terminalt samlet jobbresultat.

Dataoppgaven rapporterer at native-testen produserte input og at serverstartstien ble nådd, men de konkrete testassertionene og serverloggen er ennå utilgjengelige. Rapporterte unntak er «Native TLS test failed», fulgt av «Fixture cleanup incomplete: cannot inspect owned process group26293». Årsaken til native-feilen er derfor ikke fastslått. EPERM ved prosessgruppeinspeksjon gjør opprydding uverifisert; det beviser ikke alene at en prosess fremdeles lever. Verken TLS-pass, CA-/hosts-fjerning eller sluttproveniens kan hevdes.

Konkret videre arbeid hos dataoppgaven: hent terminale logger hvis de blir tilgjengelige; sikre avgrensede ufølsomme loggartefakter før OS-cleanup; gi hver cleanup-operasjon en egen kort deadline, fortsett med øvrige egne ressurser ved feil, og behold original native-feil separat. Logg navn/PID/PGID/eier for egne prosesser uten kommandoargumenter eller secrets, slik at feil kan knyttes til riktig proxy/klient/server/hjelper. Ingen ny root-watcher, CI, lokal trustendring eller fullbygg.

Før denne jobben var1039s brukt. Om den bruker hele20minutter, blir summen2239s (37m19s), med161s igjen av40minuttersrammen. Dette er kortere enn den nå målte serverbyggetiden på449s; en ny full TLS-runde passer derfor ikke automatisk i gjenværende ramme. Sluttid og kostnader må registreres før et konkret nytt testbehov vurderes. De tidligere grønne server- og sju native klienttestene gjelder fortsatt sine eksakte revisjoner, men sertifiserer ikke denne TLS-brukerreisen.

## Timeout håndhevet ikke stopp; rammen passert — 2026-09-13 21:57 UTC

Dataoppgaven rapporterte at ordinær kansellering av akkurat TLS34784197977 ikke stoppet jobben, og at force-cancel ble akseptert medHTTP202 kl.21:55:46UTC. Root kontrollerte status én gang ved omtrent21:57:20UTC: kjøringen var fremdeles `in_progress`, uten completedAt, og CA-/hosts-cleanup fortsatt aktiv. En akseptert kanselleringsforespørsel er ikke terminalt bevis.

Den konfigurerte20minutters timeouten fungerte dermed ikke som dokumentert hardstopp gjennom always-cleanup. Alle tidligere formuleringer om «hard grense» og beregnede maksimaltider må leses med denne korreksjonen; de beskrev planlagt begrensning, ikke faktisk håndhevet avslutning. Fra jobbstart21:33:54 til observasjonen21:57:20 er1406s. Med tidligere1039s gir dette2445s (40m45s) registrert jobbperiode,45s over40minuttersrammen ved observasjonen. Dette er ikke en bekreftet endelig fakturering: faktisk avslutning, kontrollplanetterslep og kostnad gjenstår å avklare.

Ingen ny CI er startet eller bestilt av root. Dataoppgaven følger kanselleringen av den eksisterende jobben til terminalstatus og skal registrere endelig completedAt, tilgjengelige logger, faktisk/rapportert kostnad og verifisert kontra uverifisert opprydding hver for seg. CA-/hosts-fjerning og native testdiagnostikk er fortsatt uavklart. Videre kodearbeid kan begrenses til lokal, ikke-privilegert utbedring av loggbevaring og korte deadlines for cleanup; dette utvider ikke CI-tids-/kostnadsrammen. Ingen lokal CA-/hosts-endring eller serverutrulling er gjort av root.

## TLS-jobben terminalt kansellert — kontrollert 14. september 2026

Root bekreftet direkte gjennom GitHub API at [TLS34784197977](https://github.com/Digipomps/CellScaffold/actions/runs/34784197977) er `completed/cancelled`, med jobb103796582540 registrert21:33:54–21:58:54UTC den13.september. Jobbperioden er1500s (25minutter). Med tidligere1039s er rundens samlede registrerte jobbperiode2539s (42m19s),139s over40minuttersrammen. Dette er endelig registrert jobbperiode, ikke bekreftet endelig fakturert forbruk. Force-cancelHTTP202 kl.21:55:46 var en mottatt forespørsel; denne oppføringen tilskriver ikke alene avslutningen den forespørselen.

Artifacts-API returnerer `total_count:0`. CA-/hosts-cleanup, siste pin-kontroll og artefaktsteget har ingen bestått sluttkonklusjon. Faktisk opprydding er derfor fortsatt uverifisert. FD-preflight, server-testbundle og syntetisk trustoppsett besto tidligere i jobben; native-steg feilet, mens eksakte XCTest-/serverfeil fremdeles mangler. Ingen TLS-pass eller sluttproveniens kan hevdes.

Dataoppgavens watcher er ifølge dens rapport avsluttet. Videre arbeid er lokalt og konkret: separate primaryFailure/cleanup-rapporter, identifiserte egne prosesser og endelig gone/present/unverified-tilstand, bevaring av ufølsomme logger/testsummary før OS-cleanup, samt korte deadlines per cleanup-operasjon. Tilgjengelig eksisterende rålogg undersøkes uten ny CI. Hvis de opprinnelige test-/serverfilene ikke finnes, beholdes årsaken som utilgjengelig fremfor å gjette. Root har oppdatert testoppskrift, handoff og maskinlesbar evidens; ingen ny jobb, lokal trustendring, telefoninstallasjon, personkobling eller utrulling er gjort.

## Review av lokal cleanup-retting og neste diagnoseramme — 14. september 2026

Root har lest den rene, lokale CellScaffold-committen7215052835c310d5d69197780d63b8bafb615fde over c3aaaf1592a73e7b2e81f4a8415118f49631f43c. Den flytter eksplisitte loggartefakter/testsummary og pin-kontroll foran OS-cleanup, beholder primaryFailure separat fra cleanup og gir faste privilegerte OS-kommandoer10s frist pluss2s termineringsventing. Dataoppgaven rapporterer19 lokale regresjoner bestått på6.608s og28 uendrede baseline-kontroller. Root har ikke gjentatt disse testene. Koden er ikke pushet, og ingen ny CI er startet.

Review fant et faktisk gjenværende hull: run_bounded håndterer kommando-timeout, men SIGTERM til selve helperen kan avslutte supervisoren uten å rydde dens barn. Root reproduserte med en vanlig separat Python-helper og en egen15s-sleep-prosess, uten sudo/trust/nettverk/bygg. Helperen gikk ut med-15 etter SIGTERM; dens nyopprettede barn levde fortsatt. Root sendte deretter KILL kun til denne eksakte stubgruppen og reapet helperen. Evidens: `Artifacts/Cleanup-Helper-SIGTERM-Review-20260914.json`. Dataoppgaven har fått konkret retting/regresjon: supervisoren må terminere/reape egne kommandoer også ved avbrudd innen en kort samlet frist og bevare feilstatus. Dette er en rød regresjon, ikke en verifisert retting.

Mandatavklaring:40min var roots ramme for den avsluttede prøverunden; overskridelsen42m19s beholdes og omdefineres ikke. Under Kjetils opprinnelige bestilling har root allokert en separat diagnostisk runde med én samtidig jobb og konfigurert maks20min. Dispatch er betinget av rettet signalhull med bestått regresjon og et ferskt, konservativt kostnadsgrunnlag som inkluderer uregistrerte tidligere jobber og avbruddsforsinkelse og viser plass under eksisterende60USD. Stale54.442USD med sistepost19:59:19 eller billable0 alene oppfyller ikke dette. Hvis kostnadsrommet ikke kan underbygges, skal ingen jobb startes; lokalt arbeid fortsetter og konkret ressursmangel rapporteres. Dette er ingen budsjettutvidelse, ny signerings-/core-myndighet, pin-endring eller generell testsløyfe. Interne frister skal reservere tid til logger og cleanup; GitHub-timeout skal fortsatt ikke beskrives som garantert hardstopp.
