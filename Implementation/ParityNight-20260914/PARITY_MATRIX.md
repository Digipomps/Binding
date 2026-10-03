# Paritetsstatus 15. september, kl. 05:50

**Kandidaten kan brukes til avgrenset UI-testing i simulator. Vanlig HAVEN er ikke oppdatert, og hele personkoblingen er fortsatt ikke klar til ende-til-ende testing.** Ingen personlig entitet er koblet, flyttet eller gitt nye tilganger i natt.

Sluttkandidaten består 15 Mac-regresjoner og fire iOS UI-forløp. 20 faktiske Mac-renderinger, fem iOS26.2-renderinger, fem iOS18.6-renderinger og ti skjermbilder fra UI-forløp er lagret. Dette er den virkelige Binding/CellApple-rendereren i en isolert testvert. Standard identitetsvault og resolver skal være nil. Autentisert bibliotek/chat og faktisk native fjerntransport inngår ikke i beviset.

| Scenario | Resultat i kandidaten | Bevis og begrensning |
| --- | --- | --- |
| Tekst, stacks og seksjoner | Rettet: innhold starter øverst og er leading-justert som standard; eksplisitt justering beholdes | Faktiske Mac-/iOS-bilder. Tema, typografi og noen detaljer avviker fortsatt fra web |
| Liste | Rettet: tre riktige rader og stabile separate UI-ID-er | Regresjoner + OCR av Alpha/Beta/Gamma i begge Mac-bredder; iOS-bilder |
| Grid og relative keypaths | Rettet: levert lokal state vises og manglende lokal kilde faller ikke videre til privat resolver | Tre kort og begge relative rader verifisert; seks OCR-innholdskontroller består |
| Tabs | Rettet: dynamiske etiketter/valg, tom/manglende kilde og gjenopprettet state | Faktisk Mac-rendering med bilder/OCR. Web har fortsatt avvik ved manglende dynamisk kilde |
| Skjemafelt og knapper | Rettet: synlige avgrensninger, begrenset/groende editor og treffområde som inkluderer padding | Reell iOS-typing i begge felttyper. Tapp i knappekant får eksplisitt Failed uten identitet; utkastet bevares. Ingen vellykket native lagring hevdes |
| Web-skjema | Bestått: fyll → lagre → gjenåpne → reset | Faktisk requester-skopet offentlig testflate. Uavhengig av native transport |
| Bibliotek | Rettet: kompakte faner viser hele titler og valgt tilstand | Faktisk FullLibraryView: autentisering avvist i testvert → Oppdater → Lukk, nøyaktig to bootstrapforsøk. Autentisert kataloginnhold er ikke testet |
| Chat ved åpning | Rettet: inaktive hjelpere skjules, melding står øverst, badge er kompakt og sendepil står til høyre | Samme frosne konfigurasjon/state på web, Mac og iOS. Ingen melding sendt |
| Lang chat og tastatur | Rettet: logg kan rulles til melding12 mens composer blir stående; editor og sendepil rulles samlet over tastaturet | Reelt iOS26.2 UI-forløp med typing. Én Skjul tastatur-knapp. Sendarrow er hittable; meldingshandlingen er ikke kjørt |
| Lange adresser på web | Rettet i lokal CSS-kandidat: 661px innhold blir innenfor390px viewport | Samme tekst, kontrollert ved320/390/768/1200. Ikke deployet |
| Unavailable/loading/invalid | Initiale tilstander dokumentert; ugyldig webkonfigurasjon gir422 | Ingen komplett native tilstandsovergang eller ugyldig-konfigurasjonsreise |
| Markdown og referanselabels | Fotografert, begrenset dekning | Rå markdown/HTML og flate Text-keypaths beviser ikke full markdown-paritet eller ekte Reference/transport |
| NavigationBar, Picker, Toggle, ekte Reference, opplasting | Ikke dekket | Skal ikke telles som bestått |
| QR/nærhet/personkobling og entitetsdata | Fortsatt ikke nattverifisert på fysisk telefon | Tidligere signert b12-kandidat finnes, men inneholder ikke nattens paritetsrettinger eller nyere dataklient |

## Faktiske sluttbilder

De to første bildene har samme frosne chatpayload. Forskjellig OS, fontmetrikker og ytterpadding gir ulik geometri; det er ikke erklært pikselparitet.

| iOS26.2 før nattens visuelle rettinger | iOS26.2 sluttkandidat |
| --- | --- |
| ![Før: sentrert chat og feil dimensjoner](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/ios-after/ios-chat.png) | ![Etter: leading-justert chat og kompakt badge](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/phase3-final-ios26/ios-chat.png) |

| Skrivefelt og sendepil med tastatur | Kompakt bibliotek med hele fanetitler |
| --- | --- |
| ![Lang chat med synlig sendepil](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/phase3-ui-images/chat-composer-and-send-with-keyboard.png) | ![Bibliotek, valgt fane og forventet autentiseringsstopp](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/phase3-ui-images/library-compact-full-tab-labels-selected.png) |

[Mac-form](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/native-form-compact.png), [iOS-form](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/phase3-final-ios26/ios-form.png), [iOS18.6-chat](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/phase3-final-ios18/ios-chat.png) og [den faktiske simulatorskjermen](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/phase3-final-ios26/simulator-screen.png) er også kontrollert. Mac viser fortsatt små borderartefakter rundt sirkulær badge/sendeknapp. I kompakt Mac-OCR ble «Åpne forslag» lest som «Apne forslag»; bildet ble inspisert og dette er eksplisitt merket som visuell bekreftelse, ikke et grønt eksakt OCR-resultat.

## Leveranse og neste test

[VERIFICATION.json](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/VERIFICATION.json) angir eksakte testresultater, bilder, hasher og åpne hull. [Testoppskrift](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/TEST_RUNBOOK.md) beskriver de isolerte forløpene. [Runde05-notater](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/PHASE3_NOTES.md) bevarer feilhistorikk og rotårsaker; [forrige matrise](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/phase2-final/PARITY_MATRIX.md) er arkivert.

Tre scoped patcher er klare: Binding-renderer-fixes.patch, CellProtocol-renderer-fixes.patch og CellScaffold-compact-text.patch. De kan anvendes uten konflikt mot de bevarte originalkildene. Binding-patchen har også regresjonstesten. Testvert, bundle-ID, simulatorfixtures, Xcodeplan og UI-testoppsett er bevisartefakter i snapshotet og skal ikke følge med som normal app-entrypoint. Originalenes kildehasher er uendret. Ingen commit, push, CI eller deploy er utført i nattarbeidet.
