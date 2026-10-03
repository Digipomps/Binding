# Runde kl.05 — fullført

Samme isolerte Binding/CellProtocol-kandidater som kl.03. Ingen endringer i originalenes kildefiler, ingen CI/deploy, ingen personlig autentisering eller kobling. Baseline-bilder fra kl.03 er bevart i `phase2-final/`, `ios-after/` og `ios18-after/`.

## Endringer som nå kontrolleres

- CellApple: standard HStack/VStack/Section følger leading-justering og respekterer eksplisitt hAlignment/vAlignment. VStack med fast høyde plasserer innhold øverst som standard. Text har intrinsisk bredde, slik at små badges ikke tar halve raden; eksplisitt hAlignment og fontWeight respekteres.
- Standardfelt og -knapper uten egen bakgrunn/border har tydelig avgrensning. På iOS er standardkontrollen minst44punkter høy. Eksplisitt konfigurasjonsstil beholdes. Knappens konfigurerte padding/bakgrunn ligger nå inne i knappens reelle treffområde.
- Plain TextArea bruker skjult måletekst og en overliggende ekte TextEditor. Høyden følger innhold innen minLines/maxLines. TextEditor beholder redigering og scrolling. RichMarkdown-editoren er ikke byttet ut.
- TextField/TextArea bruker levert lokal state ved relative sourceKeypaths, oppdateres når kilden endres og tømmes når kilden fjernes. De går ikke videre til global resolver for den samme leverte lokale kilden. TextField refresher på faktisk kildesignatur, så en feilet knapp ikke gjenoppretter gammel tekst over et nytt lokalt utkast. Ekte cell://-tilgang og skriveautorisasjon beholdes.
- FullLibraryView eksponerer viewmodelens eksisterende bootstrapRuntime-injeksjon, med uendret produksjonsdefault. Testverten injiserer authenticationUnavailable og tomme kataloger, uten vault/resolver. Dette gjør bibliotekets faktiske feil-/retry-/lukkeflate testbar; det er ikke et fungerende autentisert bibliotek.

## Testvert og plan

`Binding/Binding/ParityInteractiveHarness.swift` er kun isolert testvert. Flagget `--parity-interactive-library` åpner ekte FullLibraryView som sheet; bootstrap teller forsøk og avviser alltid. `--parity-interactive-form` åpner ekte BindingSkeletonView med offentlig, lagret form-fixture. Ingen nettadapter eller personlig identitet finnes.

`Binding/BindingUITests/ParityNightUITests.swift` har to reelle iOS UI-forløp: bibliotek stopp → Oppdater → Lukk, og redigering i TextField/TextEditor med tastatur → knappetrykk i paddingen → eksplisitt Failed uten identitet, med bevart utkast. Skjermbilder lagres i xcresult.

Første bygg feilet på manglende Combine-import i testverten (rettet). Andre bygg feilet på eksisterende `RemoteSurfaceRenderAuditXCTest` som kaller en Mac-spesifikk renderReport fra iOS. Ingen app-/rendererfeil ble funnet i disse kompileringene. En egen isolert `HAVEN-Parity-UI.xctestplan` inneholder bare BindingUITests. Den brede Mac-planen kjøres separat med eksisterende regresjoner og en ny faktisk renderingstest for feltoppdatering, tømming, justering og begrenset editorhøyde.

Aktiv ved første notat: exec49276 kjører UI-only-planen. Kommando startet fra nattmappen, så loggene ligger midlertidig i `../phase3-ui-only-test-logs/` og konsollen i `phase3-ui-only-test-console.log`. Dette er innen Binding-arbeidsområdet, men utenfor nattmappen. Hent endelig utfall før nye bygg. Ingen parallelle Xcode-bygg.

Mac-chat bruker nå samme frosne konfigurasjon/state som web/iOS. Den forrige Mac-eksporten med egne UUID/tidsstempler er bevart i `phase2-final/chat-*.json`. Ingen nye RAM-identiteter genereres under senere capture.

## Neste

Få reelle UI-testutfall og bilder, rett avvik i produkt eller testvert etter konkret bevis. Kjør deretter Mac-regresjoner og nye Mac/iOS-bilder. Regenerer scoped patcher, oppdater matrise/VERIFICATION og sjekk originalhashene. Ikke rapporter disse endringene som bestått før test og bilder foreligger.


## Oppdatert etter første reelle UI-runde

Tre iOS UI-tester består (`phase3-library-tabs-test-logs/parity-ui-tests.xcresult`), og15 Mac-regresjoner består (`phase3-mac-test-logs/parity-tests.xcresult`). UI-bilder i `phase3-ui-images/` viser hele bibliotekfaner, valgt «For mine formål», feil/retry/lukk, ekte tastatur og bevart utkast etter avvist lagring. Den første UI-testverten dekodet konfigurasjonen på nytt i body og gjenskapte tilfeldige UI-ID-er etter klikk. Frosset fixture løste testvertsfeilen; første feillogger er bevart. Kompakt bibliotek bruker nå en rullbar fanelinje med hele titler; bredt bibliotek beholder segmented picker.

Fem nye iOS26.2-bilder ligger i `phase3-ios26/`. Chat har leading-justering, liten badge, meldinger øverst i loggen og hovedknapp til høyre. En ytterligere test med12 syntetiske meldinger pågår for å kontrollere at en materialisert liste med fast høyde fortsatt kan rulles. Capture12445 bruker en midlertidig chat-state og gjenoppretter frosset state via EXIT-trap. Førbilder kopieres til `phase3-long-chat-before/`. Ikke kall dette bestått før bildet er inspisert.

Alle UI-loggmapper er flyttet inn i nattmappen etter fullføring. xcresulttool export attachments krever legitim eskalering for Apples midlertidige TestReport-mappe. Ingen auto-review-avvisning i denne runden.


## Lang samtale

Førbildet `phase3-long-chat-before/native-chat-compact.png` viser bare de første tre av12 meldinger. Kilden viste at Binding materialiserte listen til en klippet VStack uten rullecontainer. Kandidaten beholder nå en vertikal SkeletonScrollView rundt rader når listen har eksplisitt høyde eller maxHeightInfinity. Vanlige materialiserte lister uten slik begrensning beholder forrige form.

Fire iOS UI-tester består i `phase3-chat-scroll-test-logs/parity-ui-tests.xcresult`. Den nye testen når Transcript row12 gjennom loggens egen scrolling og bekrefter at pilknappen blir stående på samme vertikale plass. Den er utvidet med virkelig typing i chat og kontroll av pilknappen med tastaturet oppe; kun den testen kjører i exec19788 / `phase3-chat-keyboard-test-logs/`. Hent utfallet før nye bygg. Mac15 må kjøres igjen etter denne siste Binding-endringen, deretter sluttbilder og patcher.

Frossen lang-chat-fixture er bundlet i ParityFixtures som `chat-long-configuration.json`/`chat-long-state.json`. Testvertens `--parity-interactive-chat-long` er eksplisitt syntetisk. `phase3-long-chat-browser.js` og `phase3-web-chat-long.png` sammenligner samme12-meldingsstate i staging-rendereren uten handlingsadapter. Webrapport: viewport390, scrollWidth390, logghøyde258/scrollHeight1569, scrollTop0.


Tastaturutvidelsen feilet i `phase3-chat-keyboard-test-logs`: pilen var ikke hittable. Det er en faktisk produktfeil, ikke testvertsfeilen fra tidligere. Feilvideo og tidligere bilder ligger i `phase3-keyboard-failure-attachments/`. Ny privat UI-fokusmekanisme i CellApple grupperer editor med den allerede deklarerte sendeknappen og ruller gruppen samlet over tastaturet. Kun chatforløpet kjøres nå i exec67136 / `phase3-chat-focus-test-logs/`. `CHECKPOINT.md` har oppdatert neste steg.


## Endelig resultat ca.05:50

Alle eldre aktive sesjoner nevnt i historikken er avsluttet. **15 Mac-regresjoner og4 iOS UI-forløp består** mot sluttkandidaten. Siste resultater er `phase3-toolbar-mac-test-logs` og `phase3-toolbar-ui-test-logs`;15 tester tok4.591s,4 UI-tester31.341s. Senere eksakt OCR-kontroll leste «Apne forslag» på kompakt Mac, mens bildet viser «Åpne forslag»; dette er markert som OCR-mismatch og manuell bildebekreftelse, ikke normalisert til grønt OCR. Seks liste/grid/relative-kontroller består eksakt.

Tastaturrettingen består med faktisk typing og hittable sendepil. Bildekontroll viste deretter to tastaturskjul-knapper. CellTabsView var årsaken: hvert innvendig SkeletonView la til en egen keyboard-toolbar. Disse interne barna bruker nå showsKeyboardToolbar:false, mens den ytre rendereren beholder verktøylinjen. En eksakt UI-assert krever én knapp; hele UI-suiten og Mac-regresjonene er kjørt etter rettingen.

Sluttbilder:20 Mac i rotmappen;5 iOS26.2 i `phase3-final-ios26`;5 iOS18.6 i `phase3-final-ios18`;10 UI-forløpsbilder i `phase3-ui-images`. Chatpayload er nå byteidentisk på web/Mac/iOS. Mac capturemetadata beskriver den frosne ekte chatfactory/Cell-fixturen korrekt. Små borderartefakter på Mac rundt sirkulær badge/pil er fortsatt synlige og registrert som åpne.

`PARITY_MATRIX.md`, `VERIFICATION.json`, `TEST_RUNBOOK.md` og `CHECKPOINT.md` har sluttstatus og konkrete grenser. Patcher er regenerert av `prepare_scoped_patches.py` og apply-check/whitespace passer mot originalkildene. Ingen opprinnelig kildefil er endret. Bibliotekets autentiseringsstopp og formens action-avvisning er tilsiktet isolasjon, ikke bevis for fungerende autentisert tilgang. Ingen fysisk telefon, personkobling, dataoverføring, CI eller deploy i denne runden. Begge testapper er terminert og browserinjeksjonen fjernet.
