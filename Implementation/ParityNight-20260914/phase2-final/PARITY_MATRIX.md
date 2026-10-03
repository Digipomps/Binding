# Paritetsstatus 15. september, kl. 03:25

Dette er en delrapport fra nattarbeidet. Kandidaten er installert kun som en isolert simulatorapp med eget app-ID. Vanlig HAVEN er ikke erstattet eller deployet. Full entitetskobling på fysisk telefon og tilgang til entitetsdata er fortsatt ikke verifisert.

Native betyr her den virkelige `BindingSkeletonView`/`SkeletonView` i en isolert macOS-testvert, med lagret offentlig fixture-konfigurasjon og state. Kompaktformatet er 390 × 844 punkter på Mac, **ikke en fysisk iPhone**. Runde03 har i tillegg kjørt en virkelig iOS26.2-simulator på390×844punkter med fem fixtures, inkludert chat. Web ble kjørt mot staging i 390 × 844 og 1200 × 900. Begge bruker samme navngitte fixture-kontrakt; separat HTTP-henting kan gi forskjellige konfigurasjons-UUID-er. Testverten har ingen identitet eller resolver. Dette beviser rendereratferd, ikke fungerende native fjerntransport.

| Scenario | Frisk web-evidens | Native før → kandidat | Handlinger / gjenstående |
| --- | --- | --- | --- |
| Tekst, badge, divider | Innhold og bilder i begge bredder | Innhold synlig; stort tomrom over flaten → starter øverst | Font, venstrejustering, seksjonshierarki og knappeutseende avviker fortsatt |
| Liste | Alpha/Beta/Gamma vises | «Ikke tilgjengelig» → første retting dupliserte Alpha → nå tre korrekte rader | Stabile separate rad-ID-er og oppdatert radtekst har regresjonstester; native klikk ikke utført |
| Grid | Tre kort vises | Alle kort manglet → tre kort vises i begge bredder | Native bruker nå levert lokal state. Ingen bevis for live resolver-fallback |
| Relative keypaths | Begge rader vises | Manglende/duplisert radinnhold → A/B og 11/22 vises | Seks OCR-kontroller samlet for grid/liste/relative bestått |
| Form | Fyll → lagre → last på nytt → reset bestått; data og synlig tilstand kontrollert | Begge felt vises | Native lagring ikke testet; editor tar for mye høyde, knapper er lite tydelige |
| Markdown | Source og HTML-tekst fotografert | Source og HTML-tekst fotografert | Ikke bevis for full markdown/HTML-paritet |
| To referanselabels | Felt fra begge labels vises | Felt fra begge labels vises | Fixturen tester flate Text-keypaths, ikke et faktisk Reference-element eller transport |
| Remote bridge metadata | Lange adresser gav 661 px sidebredde i 390 px viewport | Adresser synlige | CSS-kandidat gir 390 px uten innholdstap, også kontrollert ved 320/768/1200. Gammel bridgehead-adresse i fixture er metadata, ikke transportbevis |
| Unavailable/loading | Tydelig placeholder fotografert | Tydelig placeholder fotografert | Bare initial tilstand; native toggling ikke utført |
| Invalid | HTTP 422 med eksplisitt diagnostikk; feilside fotografert | Ikke renderert som gyldig konfigurasjon | Native feilsurface må fortsatt verifiseres |
| Oppstart og bibliotek | Porthole omdirigerer til innlogging; ingen konto brukt | Vanlig bootstrap ikke kjørt | Autentisert brukerreise gjenstår |
| Chat | Eksakt eksportert chatkonfigurasjon/state i staging-rendereren, uten transport | Mac og iOS: inaktive hjelpeflater synlige → fjernet ved korrekt tom faneliste | Rendererbevis. Ingen prompt sendt; ingen persistert personhistorikk |
| Tabs | Dynamiske etiketter, valgt panel og tom liste kjørt | Ny faktisk renderingstest: oppdatert state, tom/manglende liste og gjeninnsatt state består | Web viser fortsatt standardpaneler ved manglende kilde; native-kandidaten forblir tom. Handlingsbanen er ikke ende-til-ende testet |
| NavigationBar, Picker, Toggle, ekte Reference, FileUpload/Attachment | Ikke dekket av dette corpus | Ikke dekket | Skal ikke telles som bestått |
| QR/nærhet/personkobling | Tidligere isolert kandidat finnes | Ikke fysisk prøvd i natt | Ingen personkobling eller datamigrering utført |

14 målrettede native tester besto: seks nye regresjoner og åtte eksisterende renderer-/synlighets-/knapptester. Første runde på 11 tester var også grønn, men bilder avdekket en ekstra rad-ID-feil. Den historikken er beholdt. Skjermbilder og OCR ble kontrollert etter siste retting; AX-uttrekket ga bare roten og teller ikke som et fullstendig semantisk tre.

Kilder og kandidater: `source-manifest.json`, `fixtures/fetch-report.json`, `web-metrics.json`, `web-form-action-complete.json`, `web-overflow-verification.json`, `render-assertions.json`, `test-logs-scalar-rows/parity-tests.xcresult` og de tre `*-*.patch`-filene. Førbilder ligger i `native-before/`; første delvis mislykkede retting i `native-first-fix/`.

Eksempel fra den kompakte native listeflaten. Før mistet alle rader verdiene sine; kandidaten viser Alpha, Beta og Gamma og starter øverst. Farger, typografi og knappeutforming er fortsatt ikke lik web.

| Native før | Native kandidat |
| --- | --- |
| ![Manglende radverdier og tomrom](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/native-before/native-list-compact.png) | ![Tre riktige rader i kandidaten](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/native-list-compact.png) |

Web-eksempel ved 390 px: lange adresser sprengte bredden. Den lokale CSS-kandidaten bryter adressene uten å endre teksten.

| Web før | Lokal CSS-kandidat |
| --- | --- |
| ![Horisontal overflow](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/web-overflow-before.png) | ![Adressteksten holder seg innenfor skjermen](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/web-overflow-after.png) |


Runde03: Fanene brukte feil datakilde. Før viste iOS alle hjelpefaner selv om ingen hjelper var aktiv; etter bruker den samme tomme faneliste som web. Begge bilder er faktiske iOS26.2-renderinger med syntetisk state. Alle fem iOS-flater ble også bygget og fanget på nytt etter rettingen. Se [runde03-notater](PHASE2_NOTES.md) for presis isolasjon, testhistorikk og resterende visuelle avvik.

| iOS før fanerettelse | iOS kandidat |
| --- | --- |
| ![Inaktive hjelpefaner vises](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/ios-before/ios-chat.png) | ![Tom hjelperliste respekteres](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/ios-after/ios-chat.png) |

[Simulatorens faktiske skjermbilde](ios-simulator-final.png) viser statuslinje og appen på iPhone-format. [Web med samme chatkontrakt](web-chat-390.png) viser at typografi, justering, feltutforming og deler av fargetemaet fortsatt avviker. Ingen full visuell paritet er erklært.

Samme isolerte bygg er også kjørt på iOS18.6 (402×874): fem bilder i `ios18-after/`. Appens nåværende minimum er iOS18.0. Dette bekrefter rendereroppstart på disse simulatorene, ikke nærhetstransport eller fysisk maskinvare. Web og iOS brukte identisk frosset chatpayload; Mac regenererte UUID-er/tidsstempler fra samme factory. Se `chat-fixture-provenance.json`.
