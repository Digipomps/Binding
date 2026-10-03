# HAVEN — morgenrapport 15. september 2026

**Vanlig HAVEN er fortsatt ikke klar for å prøve hele entitetskoblingen.** Nattens kandidat kan brukes til avgrenset UI-testing i simulator, men rettingene er ikke integrert i den vanlige appen eller i den eksisterende signerte telefonpakken.

## Hva natten ga

| Område | Status | Hva som faktisk er bevist |
| --- | --- | --- |
| Rendererregresjoner på Mac | **15/15 bestått** | Lister, grid, dynamiske faner, lokale felt, editorhøyde, synlighet og knappestøtte |
| Brukerforløp på iOS26.2 | **4/4 bestått** | Hele bibliotekfaner og valg; autentisering stopp → prøv igjen → lukk; redigering og avvist lagring med bevart utkast; lang chat med scrolling og synlig sendepil over tastaturet |
| Rendering på iOS18.6 og26.2 | **5/5 flater på hver** | Faktiske bilder av tekst, liste, grid, form og chat. iOS18.6 har ikke de fire interaktive testene |
| Visuell likhet med Porthole | **Forbedret, ufullstendig** | Justering, badges, felt, knapper og editor er rettet. Tema/typografi, enkelte borderdetaljer og flere komponenttyper gjenstår |
| Fysisk QR/nærhet, eierskapsbevis og entitetsdata | **Ikke ende-til-ende verifisert** | Ingen personlig entitet er koblet eller flyttet. Autentisert bibliotek/chat og native datatransport er ikke bevist av nattens UI-tester |

De konkrete rettingene omfatter manglende/duplisert listeinnhold, grid som overså levert state, tomme dynamiske faner, uønsket sentrering, felt som brukte for mye høyde, små knappetreffområder, avkuttede bibliotekfaner og en chatlogg som klippet senere meldinger. Tastaturforløpet avdekket at sendepilen forsvant; nå rulles editor og dens eksisterende sendeknapp samlet inn i synsfeltet. Innvendige faner deler én tastaturverktøylinje.

## Før og etter på iOS26.2

Samme frosne chatkonfigurasjon og state, ekte Binding/CellApple-rendering. Dette er bilder fra isolert testvert, ikke en innlogget samtale. Ingen melding er sendt til noen person eller modell.

| Før nattens visuelle rettinger | Kandidat etter rettingene |
| --- | --- |
| ![Chat før retting](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/ios-after/ios-chat.png) | ![Chat i sluttkandidaten](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/phase3-final-ios26/ios-chat.png) |

| Sendepil og editor med tastaturet oppe | Bibliotekfaner med hele titler |
| --- | --- |
| ![Lang chat med tastatur](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/phase3-ui-images/chat-composer-and-send-with-keyboard.png) | ![Hele fanetitler i biblioteket](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/phase3-ui-images/library-compact-full-tab-labels-selected.png) |

Bibliotekets autentiseringsstopp er bevisst injisert i testverten. Skjemaets lagring avvises fordi ingen identitet/resolver er tilgjengelig. Det er vellykkede tester av avvisningsforløp, og skal ikke tolkes som fungerende innlogging eller lagring.

## Hva som kan prøves nå

Den separate simulatorappen `org.digipomps.haven.parity-night-test` kan åpne chat med12 syntetiske meldinger, redigerbart skjema og bibliotekets faner/feilforløp. [Testoppskriften](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/TEST_RUNBOOK.md) har nøyaktige kommandoer. Vanlig HAVEN er bevart. Den eksisterende b12-IPAen for fysisk telefon finnes fortsatt med riktig SHA256, men inneholder verken nattens paritetsrettinger eller den nyere dataklienten.

Neste nødvendige produktsteg er å samle personkobling, dataklient og de verifiserte UI-rettingene i én normal appkandidat, og deretter prøve den autentiserte reisen på fysisk telefon. Eierskapsbeviset skal gjelde menneskets entiteter; dette nattarbeidet har ikke gitt agenter eller scaffolds ny personmyndighet.

## Kilder, patcher og grenser

Kandidaten bygger på Binding775fc93d og CellProtocol4096760f med de opprinnelige arbeidsendringene bevart i isolerte snapshots; en smal CellScaffold-kandidat bygger på1dbdee23. Patchene er laget mot nøyaktige førkilder, ikke som en eksport av andres WIP. Sluttkontrollen kl.07 bekrefter uendrede originalkilder, korrekte patchhasher, apply-check uten konflikt og eksisterende testresultater. Ingen nye tester ble gjentatt i denne sluttrunden siden produktkoden var uendret.

- [Binding: visning, bibliotek og regresjonstest](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/Binding-renderer-fixes.patch)
- [CellProtocol/CellApple: rendererrettinger](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/CellProtocol-renderer-fixes.patch)
- [CellScaffold: tekstbryting på smal skjerm](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/CellScaffold-compact-text.patch)
- [Full paritetsmatrise med åpne komponenter](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/PARITY_MATRIX.md)
- [Testresultater, bilder og SHA256](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/VERIFICATION.json)
- [Frisk sluttkontroll kl.07](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/MORNING_FINAL_CHECK.json)

Testvert, app-ID, fixtures og Xcode-testplan er holdt utenfor produktpatchene. Nattarbeidet har ikke commitet, pushet, startet CI, deployet eller installert over brukerens app. Det finnes20 Mac-bilder,10 statiske iOS-bilder og10 bilder fra UI-forløp, samt webbevis fra staging. Full semantisk/visuell paritet for alle komponenter, autentisert bruk og fysisk telefon er fortsatt åpent.

Nattplanen14.–15.september er avsluttet og automasjonen er satt på pause. Den fortsetter ikke automatisk neste natt.
