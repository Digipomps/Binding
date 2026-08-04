# Apple- og Arendalsuka-modenhetsvurdering — 2026-08-03

Statusdato: 3. august 2026

Mål: HAVEN tilgjengelig for deltakere ved Arendalsuka 10.–14. august 2026

Binding-revisjon undersøkt: `7884e566420cd90eb288881cc8a5df0e3685386b`

Metode: kildeaudit, rådgiverpanel, lokal Release-bygg/test, live read-only staging-prober og kontroll mot gjeldende Apple-kilder. Ingen produktkode eller stagingdata ble endret.

## Beslutning

**Ikke send dagens build til App Review eller ekstern TestFlight.**

Prosjektet er byggbart og har en sammenhengende Arendalsuka-kjerne, men er samlet sett en **integrasjonsbeta og operasjonelt pre-submission**. Det er ikke submission-ready 3. august.

Offentlig App Store før 10. august er fortsatt fysisk mulig, men bare som et høyrisiko stretch-mål dersom alle P0-er lukkes innen 24–36 timer, en komplett innsending skjer senest 5. august, og Apple godkjenner i tide. Apple oppgir at 90 % av innsendinger i gjennomsnitt blir vurdert på under 24 timer; dette er verken godkjenningsrate eller SLA. Etter manuell release kan synlighet ta opptil 24 timer.

Panelets endelige adjudikasjon skiller mellom tre handlinger:

1. **Gjør straks:** lag et signert diagnostisk archive, valider, last opp og installer via intern TestFlight for å bevise signing, provisioning, bundle-ID, App Store Connect-prosessering og fysisk installasjon.
2. **Ikke gjør med dagens build:** send til ekstern TestFlight Beta App Review eller offentlig App Review.
3. **Gjør etter P0:** lag et nytt buildnummer fra ren release-commit, dokumenter Release-inventaret og send den korrigerte kandidaten.

## Formål og mål

| Formål | Mål | Status ved audit | Terminal vurdering for denne evalueringen |
|---|---|---|---|
| `purpose://event.participation` | En installasjons- og brukerflyt som faktisk kan brukes fra 10. august | Ingen bevist offentlig distribusjonskanal; kritisk UI-flyt rød | **blocked** — eier: Kjetil/release owner |
| `purpose://test.acceptance` | Kildebasert go/no-go for Apple | Bygg, tester, staging og Apple-krav kontrollert | **satisfied** |
| `purpose://gui.quality.functional-accessible` | Prompt → forslag → deltakerprogram → lokalt lagret valg fungerer på støttet iPhone | UI-test stopper på fire dupliserte «Skjul tastatur»-knapper før prompt sendes | **blocked** — eier: Binding |
| `purpose://access.audit.privacy` | Apple privacy-, support-, konto- og UGC-gater er komplette eller ute av scope | Appmanifest og endelige support/privacy-bevis mangler | **blocked** — eier: release/privacy owner |

## Rådgiverpanel

Panelet ble satt opp med tre uavhengige roller:

- Apple-/kildeauditor: verifiserte aktuelle Apple-regler og kildepremisser.
- Skeptiker/red-team: angrep deadline, compliance og fallback-planen.
- Steelman/release-strateg: bygget den sterkeste ærlige syvdagersplanen og et smalt v1-forslag.

Hovedagenten fungerte som tekstanalyse/adjudikator A. Steelman-agenten fungerte deretter som adjudikator B og utfordret den hardeste dommen. Panelet var ikke en avstemning; Kjetil eier releasebeslutningen.

### Brief-korreksjoner

To load-bearing premisser ble korrigert i full korreksjonsrunde:

1. **Release-scope var feilaktig beskrevet som lukket.** DEBUG-/menygatene finnes, men Co-Pilot kan opprette og laste `Arendalsuka Participant Program` fra `stagingSurfaceTestingMenuConfigurations()` uten at `isAllowedInPersonalCopilotV1` håndheves ved alle innganger. Dette gjør dagens conference-free review-historie usann eller minst ufullstendig.
2. **«16 faktiske Release-flater» var for sterkt.** Det finnes tre divergerende inventarer: 11 i review-notatet, 15 navigasjonsdestinasjoner og 16 katalog-/testkonfigurasjoner inkludert `Calendar`. Faktisk synlig og nåbart Release-inventar er uverifisert.

Adjudikator B utfordret «ikke send» og fikk dommen **modifisert**: pipeline-probe/archive/upload bør skje straks, men kjent ufullstendig build skal ikke sendes til review.

## Modenhet

Skala: 0 konsept · 1 implementert · 2 lokalt verifisert · 3 miljøverifisert · 4 produksjonsklar.

| Område | Nivå | Evidens | Dom |
|---|---:|---|---|
| iOS-byggbarhet | 2 | Usignert Release passer med Xcode 26.3/iOS SDK 26.2 | Grønn lokal kompilering, ikke distribusjonsbevis |
| OS-rekkevidde | 1–2 | Prosjektet står på iOS 26.1; diagnostisk Release med target 18.0 passer | iOS 18 runtime er ikke testet |
| App Store-scope | 1 | Menygater og policy finnes, men Arendalsuka-lastesti omgår sentral gate | P0 |
| Kritisk iPhone-flyt | 1–2 | To logikktester passer; UI E2E feiler før promptsend | Ikke akseptert |
| Staging-kontrakter | 3 | Health, Arendalsuka config og chat config svarer 200 | Miljøbevis for kontrakter, ikke hele brukerreisen |
| Eventdata/drift | 1–2 | 2238 sesjoner, men programdata hentet 26. juni; state er ca. 4,03 MB og tok ca. 2,33 s | Fersk reimport, cache/degraded mode og nett-test mangler |
| Apple privacy/metadata | 1 | Review-dokumenter finnes; app-eid privacy manifest, endelige URL-er og sann inventory mangler | Pre-submission |
| Signering/App Store Connect | 0–1 | Ingen gyldig codesign identity synlig lokalt; App Store Connect kunne ikke auditeres uten innlogging | Ubevist |
| Fallback | 1 | Ekstern TestFlight krever review; AASA peker på demo-ID; anonym web går til login | Ingen robust offentlig fallback |

**Samlet modenhet: 2 av 4.** Kjernen er implementert og delvis lokalt/miljømessig bevist. Distribusjon, policyintegritet og den faktiske deltakerreisen er ikke produksjonsbevist.

## Det som er sterkt

- Release-kompilering bruker nå påkrevd Xcode/iOS 26 SDK.
- En diagnostisk iOS 18-build passer, så lavere deployment target ser ikke ut til å kreve en umiddelbar full port.
- Fire målrettede Personal Co-Pilot policy-/scope-tester passer.
- To Arendalsuka-logikk-/katalogtester passer.
- Staging publiserer aktuell Arendalsuka-konfigurasjonskontrakt og Co-Pilot-chatkontrakt raskt.
- DEBUG-only conference menus, staging seeds og agent-workbench er av utenfor DEBUG.
- Dokumentasjonen viser reell forståelse av Apple 1.2, 4.7, privacy, consent og review-behov.
- Produktkjernen kan reduseres til en forståelig historie: spør → finn → åpne → lagre eventvalg lokalt.

## P0 før review

| P0 | Krav | Akseptansebevis |
|---|---|---|
| Scopeintegritet | Alle konfigurasjonsinnganger bruker én håndhevbar Release-allowlist | Release-test enumererer alle nåbare konfigurasjoner og avviser alt uten godkjent scope |
| Smalt v1 | Konto, profilpublisering, directory, matching, person-til-person-chat, katalog/mini-app-utforsking, Workflow Studio, Entity Scanner, Butterpop og eksperimentflater fjernes fra submitted target | Release-inventar og skjermbilder viser bare godkjente flater |
| Distribusjon | Team/App ID/bundle-ID/provisioning er frosset; archive validerer og build prosesseres | Xcode Organizer/App Store Connect + intern TestFlight-installasjon |
| Privacy | App-eid `PrivacyInfo.xcprivacy`, full required-reason-audit, privacy report, korrekte labels | Upload-validering passer; policy/support er nåbar i app og ASC |
| Brukerflyt | Dupliserte tastaturkontroller er rettet; full prompt→program→detalj→lagre passer | Release/TestFlight på simulator og minst to fysiske enheter |
| Eventdata | Fersk import mot offisielt program, kilde/proveniens og degraded cache | Importtid etter auditdato; representative programtreff sammenlignet; svakt nett testet |
| Metadata | Én autoritativ inventory matcher appbeskrivelse, screenshots og review notes | Maskingenerert/observerbar Release-inventory; ingen skjulte funksjoner |
| Alder/rettigheter | Ny 2026 age questionnaire; gammel `12+`-hint migrert; eventnavn/data/tilknytning avklart | App Store Connect-svar + eventuell rettighets-/partnerdokumentasjon |
| Tillatelser | Ubrukte background modes, push, Nearby, Bluetooth, mikrofon, speech, kalender/reminders fjernes | Signert entitlements/Info.plist matcher faktisk v1 |
| Fallback | Enten godkjent ekstern TestFlight og åpen web, eller ærlig begrenset fallback | Public link testet på ikke-teamkonto; anonym web uten login hvis lovet |

### Konkrete blockers i dagens evidens

- Co-Pilot kan laste en staging-/conference-klassifisert Arendalsuka-konfigurasjon uten sentral App Store-policytest.
- Review-notat, navigasjon og katalogtest har tre ulike inventory-tall.
- Kritisk UI-test feiler: fire «Skjul tastatur»-knapper, forventet én.
- Ingen app-eid `PrivacyInfo.xcprivacy`, samtidig som appen bruker `UserDefaults`.
- `metadataHints` bruker gammel `12+`-kategori; dagens Apple-system bruker 4+/9+/13+/16+/18+.
- Final supportkontakt og final privacy policy står eksplisitt åpne i runbook.
- Lokal account-delete-handling registrerer bare en staged forespørsel; den beviser ikke full serverkontosletting.
- Programdata er hovedsakelig hentet 26. juni, selv om journalen ble lastet 3. august.
- AASA peker på `YWLW23LT6G.io.brokenhands.demos.auth.Shiny`, og app-entitlements mangler associated domains.
- Anonym `/arendalsuka` ender på login.
- Prosjektet bruker bundle-ID `org.digipomps.havenplayground`, iOS 26.1, development APNs og fire background modes uten signert produksjonsbevis.
- App Store Connect-status, agreements, DSA/trader-status, privacy labels, age rating, export compliance, screenshots, review contact og uploaded build er uverifisert.

## Anbefalt Apple-produkt

| Felt | Anbefaling |
|---|---|
| Navn | `HAVEN – Personal Co-Pilot` |
| Primærkategori | Productivity |
| Kjerneverdi | Finn relevante arrangementer fra en enkel forespørsel og lagre private valg lokalt |
| V1-flater | Personal Home, begrenset Co-Pilot/event-query, read-only Arendalsuka Participant Program, lokale favoritter/notater |
| Konto/UGC | Ingen kontooppretting, offentlig profil, matching eller person-til-person-chat i event-v1 |
| Remote innhold | Én first-party, eksplisitt allowlistet eventkonfigurasjon; ingen vilkårlig katalog eller downloaded code |
| Release | Manuell release straks godkjenning foreligger, senest 8. august for nødvendig margin |

Ikke markedsfør appen som «offisiell», «partner» eller bruk Arendalsuka-logo uten dokumentert rett. Apples expedited review for eventapper forutsetter at appen er direkte assosiert med eventen; ønsket om å være tilgjengelig er ikke i seg selv slikt bevis.

Hvis CellConfigurations fortsatt kan endre funksjonalitet etter review, må dette beskrives ærlig og vurderes mot Apple 4.7. En trygg review-forklaring forutsetter at konfigurasjonene bare er deklarative, first-party, fast allowlistet og ikke kan gi direkte native API-tilgang eller åpne videre softwareflater.

### Forslag til Review Notes etter at builden samsvarer

```text
HAVEN is a curated personal workspace with a focused Arendalsuka program experience.

No login or account creation is required in this version. The submitted build does not include public profile publishing, social discovery, matching, person-to-person chat, payments, plug-ins, or arbitrary third-party configurations.

Reviewer path:
1. Launch HAVEN.
2. Open Co-Pilot.
3. Enter “Hva skjer i Arendalsuka?”
4. Tap “Åpne forslag”.
5. Open “Arendalsuka Participant Program”.
6. Select a program item and save it locally.

The App Store build is limited to Personal Home, the event query, the participant program, and local saved items/notes. Event data is delivered from our managed HAVEN service. A bundled or cached sample remains available if the service is unavailable.

CellConfigurations are first-party declarative descriptions rendered by native app code. They do not execute downloaded code or receive native permissions. Every configuration reachable in this build is fixed by the release allowlist.

Privacy policy: <URL>
Support: <URL and email>
```

Ikke bruk teksten før hvert utsagn er verifisert mot det signerte arkivet. Dersom login eller konto beholdes, må reviewer få aktiv demo-konto eller full demo mode, og full in-app account deletion må fungere.

### Screenshots

1. Personal Home med tydelig eventinngang.
2. Spørsmålet og det kuraterte forslaget.
3. Deltakerprogrammet med fersk data og kilde.
4. Lokalt lagret valg/notat og personvernforklaring.

Ikke vis funksjoner som er skjult, uferdige eller fjernet fra v1.

## Syvdagers plan og go/no-go

### 3. august — scope og pipeline

- Utpek release owner og App Store Connect owner.
- Frys ren releasegren/commit; ikke arkiver fra dirty worktree.
- Bekreft Developer Program, App Store-record, agreements, App ID, bundle-ID og provisioning.
- Lag **diagnostisk signert archive**, valider, last opp og installer via intern TestFlight.
- Kutt v1 til eventkjernen og håndhev sentral gate ved alle lastestier.
- Start manifest/privacy/entitlement/permission-audit.
- Reimporter eventdata.

### 4. august — første kandidat

- Kjør full E2E på Release-konfigurasjon og fysiske iPhoner.
- Velg laveste fysisk testede iOS-versjon; iOS 18-kompilering alene er ikke nok.
- Last opp ny korrigert build og ta faktisk Release-inventar/screenshots.

**Go/no-go 4. august kl. 18:** uten prosessert intern TestFlight-build, lukket scope og grønn kritisk flyt stoppes offentlig App Store-spor.

### 5. august — submit

- Fullfør privacy, age rating, export compliance, rights, support/privacy URL, beskrivelse, screenshots og review notes.
- Send korrigert build til ekstern TestFlight og App Review.
- Velg manuell release.

**Go/no-go 5. august kveld:** build må være komplett og minst `Waiting for Review`. Ellers skal offentlig release ikke loves.

### 6.–7. august — review/fallback

- Test den prosesserte builden på ikke-team-enhet.
- Test eventnett/cellular, cache og backendfeil.
- Be om expedited review bare hvis direkte eventtilknytning kan dokumenteres.
- En prinsipiell 1.2-, 4.7- eller 5.1-avvisning betyr no-go for offentlig App Store i eventvinduet.
- Gjør webfallback anonym og mobilvennlig; dagens login-redirect er ikke fallback.

### 8. august — hard godkjenningsfrist

- Ved godkjenning: manuell release umiddelbart.
- Uten App Store-godkjenning: bruk bare godkjent ekstern TestFlight.
- Uten ekstern beta-godkjenning: begrens til intern/ad hoc gruppe og web.

### 9.–10. august — distribusjon og drift

- Kontroller App Store-propagering på fersk ikke-team-enhet.
- QR peker til direkte App Store-side; ikke lov universal link før AASA er grønn.
- Test installasjon på mobilnett og svakt nett.
- Ha navngitt teknisk/supportansvarlig og statisk/cachet program.

## Verifikasjonsjournal

| Kontroll | Resultat |
|---|---|
| iOS Release, SDK 26.2, usignert | **PASS** |
| iOS Release med diagnostisk deployment target 18.0 | **PASS** — kompilering, ikke runtime |
| Fire Personal Co-Pilot policy-/scope-tester | **PASS** |
| To Arendalsuka logikk-/katalogtester | **PASS** |
| iPhone UI `testArendalsukaPromptOpensParticipantProgram` | **FAIL** — 4 vs 1 «Skjul tastatur» |
| Staging `/health/build` | **200**, deploy/revisjon oppgitt |
| Staging `/arendalsuka/api/configuration` | **200**, forventet kontrakt |
| Staging chat config | **200**, forventet kontrakt |
| Staging `/arendalsuka/api/state` | **200**, ca. 4,03 MB / 2,33 s; gammel import |
| AASA | **FAIL for HAVEN** — demo-ID |
| Anonym webfallback | **FAIL** — redirect til login |
| App-eid privacy manifest | **MISSING** |
| Lokal codesign identity | **0 synlige** — organisasjonsstatus fortsatt ukjent |
| App Store Connect-audit | **UNAVAILABLE** — ingen innlogget sesjon |

## Claim ledger

| Påstand | Type | Status | Falsifikator / minste neste bevis |
|---|---|---|---|
| C1: Appen kan bygges med påkrevd SDK | capability | **supported** | Ren build på fryst commit feiler |
| C2: Dagens build er klar til Apple | assertive/allOf | **contradicted** | Signert, prosessert build med alle P0-bevis |
| C3: Release-scope er lukket | assertive | **contradicted** | Release-test viser håndhevet policy ved alle innganger |
| C4: Kritisk eventflyt er E2E-bevist | assertive | **unsupported** | Grønn Release/TestFlight-test på fysisk telefon |
| C5: Eventdata/fallback er produksjonsklar | assertive/allOf | **contradicted** | Fersk import, cache/degraded test og åpen fallback |
| C6: Offentlig App Store før 10. august er mulig | predictive | **open**, eier: Kjetil | Prosessert build + komplett submission senest 5. august; ellers missed |
| C7: TestFlight er garantert offentlig fallback | predictive | **contradicted** | Ekstern build godkjent og public link testet |
| C8: Smal no-account/no-UGC event-v1 reduserer risiko mest | normative | **supported**, ikke garanti | Fullt scope beviser moderation/deletion og passer review uten forsinkelse |

## Q1–Q10 metodekontroll

| Metric | Verdi | Evidens |
|---|---:|---|
| Q1 Position-change traceability | 3/3 | F8-korreksjon, inventory-korreksjon og adjudikator-B-modifikasjon har navngitte bevis |
| Q2 Mixed-ledger ratio | 6/8 mot optimistisk release-framing | To positive/risikoreduserende claims står; seks er motsagt, unsupported eller åpne. Ingen måltall brukt |
| Q3 Audit-status honesty | 8/8 | Alle load-bearing claims har lokal kjøring/kilde eller offisiell Apple-kilde; ASC er markert utilgjengelig |
| Q4 Narrative independence | 3/3 headline findings | Byggbar, ikke submission-ready, deadline betinget — står både i skeptiker- og steelman-framing |
| Q5 Falsifiability audit | 0 uflaggede / 8 med falsifikator | Claim ledger navngir disconfirmation/minste neste bevis |
| Q6 Natural-experiment identification | 3/3 sjekket | iOS 18-build ble faktisk kjørt; webfallback ble faktisk probet; ingen tidligere Apple-run var tilgjengelig og er logget åpen |
| Q7 Revealed-preference test | 2/2 | «Conference-free» mot faktisk kodesti; journal `loadedAt` mot eldre data-`fetchedAt` |
| Q8 Terminal adjudication rate | 8/8 | Alle claims er lukket eller åpne med eier/deadline |
| Q9 Steelman sourcing | 3/3 | Apple review-hastighet/expedite, grønne builds og staging brukes som motkilder til no-go-lean |
| Q10 Concession asymmetry | 0 | Eneste modifikasjon kom etter eksplisitt adjudikator-B-argument om pipeline-probe |

## Menneskelige beslutninger

Kjetil må eksplisitt beslutte:

1. om v1 kuttes til no-account/no-UGC eventkjerne;
2. Apple Team, produksjons-bundle-ID og hvem som kan signere/laste opp;
3. laveste fysisk testede iOS-versjon;
4. produksjonsdomene, AASA og om universal links faktisk inngår;
5. endelige privacy-/support-URL-er og ansvarlig supportkontakt;
6. rett til å bruke Arendalsuka-navn, programdata og eventuell dokumentert direkte eventtilknytning;
7. endelig go/no-go 4. og 5. august.

## Autoritative eksterne kilder

- [Arendalsuka 10.–14. august 2026](https://www.arendalsuka.no/)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple App Review-hastighet og expedited review](https://developer.apple.com/app-store/review/)
- [Apple SDK- og required-reason-krav](https://developer.apple.com/news/upcoming-requirements/)
- [Beskrive required-reason API-bruk](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Legge privacy manifest i appen](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk)
- [App Store Connect app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- [Manuell release og opptil 24 timers propagering](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option/)
- [Gjeldende age ratings](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions)
- [Arendalsuka varemerke og logo](https://www.arendalsuka.no/praktisk-informasjon/foer-festivalen/arendalsukaloven/varemerke-og-logo)

## Handoff

Denne rapporten avslutter evalueringen, ikke releasearbeidet. Neste autoriserte implementeringsoppdrag bør starte med to parallelle leveranser: (A) diagnostisk signert archive/upload/internal TestFlight, og (B) scopekutt + sentral policygate + privacy/E2E/data-P0. Offentlig review starter først når begge møtes i en ny, ren kandidatbuild.
