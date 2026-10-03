# Runde kl.03 — reell iOS og chat

Denne runden fortsetter den samme nattbestillingen. Ingen ny oppgave, agent, CI, deploy eller kobling av personer.

## Bevis og begrensninger

- Offentlig staging `/porthole` omdirigerer til `/login`. Ingen passkey, konto eller personlig identitet er brukt. Full autentisert oppstart/bibliotek/chat er derfor fortsatt ikke bekreftet.
- iOS Simulator26.2 iPhone16e, allerede startet før vårt arbeid: `1F9CB294-13BC-4D49-B8C7-E969D4BFFA11`. Samme bygg er også kjørt på allerede startet iOS18.6 iPhone16Pro (402×874punkter). Alle fem flater ble fanget; chatbildet er visuelt kontrollert. Appens nåværende MinimumOSVersion er18.0, selv om Network-framework-pakkens tilgjengelighet kan være eldre. Dette er ikke bevis for QR/nærhet på iOS18.6. Ingen nedlasting eller simulatoroppstart nødvendig.
- Isolert HAVEN-app med bundle-ID `org.digipomps.haven.parity-night-test` er bygget for simulator og installert bare der. Vanlig HAVEN er ikke erstattet. iOS-bygget besto; `ios-build-logs/xcode-ios-build-latest.log` og `ios-build-console.log`.
- `ios-before/` har fem faktiske UIKit/SwiftUI-bilder,1170×2532piksler /390×844punkter. Testverten kjører virkelig BindingSkeletonView med lagrede konfigurasjoner/state, uten defaultIdentityVault eller resolver. Dette er ikke fysisk telefon, vanlig appoppstart, tastaturtest eller faktisk QR/nærhet.
- Chat-konfigurasjonen er den virkelige `ConfigurationCatalogCell.personalInviteChatMenuConfiguration()` («Butler Chat»). State ble eksportert fra virkelig BindingPersonalChatHubCell med identitet i EphemeralIdentityVault (kun RAM). Historikk er av/utilgjengelig fordi resolver mangler. Ingen prompt er sendt til noen modell, agent eller person.
- Første testvert fylte begge referanselabels med samme state. Det er rettet: chat-state tilhører bare `chatHub`; ingen `perspective`-state er eksportert. Førbildene har den gamle testvertsbegrensningen, men fanefeilen er uavhengig av Perspective.
- `web-chat-390.png` og `web-chat-1200.png` bruker nøyaktig eksportert lokal chatkonfigurasjon/state i den allerede lastede staging-rendereren og dens CSS. Dette er en renderer-sammenligning i nettleserminne, ikke en autentisert serverchat. Ingen handlingsadapter har transport; en eventuell handling avvises eksplisitt. Nettleserkoden ligger i `chat-render-browser.js`.
- `phase1-final/` bevarer de siste01-bildene før03-runden oppdaterer rotens macOS-bilder.

## Funn og retting

Native CellTabsView overså levert userInfoValue og hentet alltid gjennom global resolver. Tom eller manglende dynamisk faneliste falt tilbake til alle panelene. Chat viste derfor inaktive hjelpeflater, og etikettnavn kom fra panel-ID i stedet for state.

Den isolerte CellApple-kandidaten bruker levert lokal state for relative keypaths, respekterer tom/manglende liste, og velger bare paneler som finnes i fanelisten. Oppdatert lokal valgt fane nullstiller gammel lokal selection. Uten dynamisk tabsKeypath beholdes statiske paneler. Eksplisitte cell://-lesninger og ekte handlingsautorisasjon beholder resolverbanen. Ingen ny wirekontrakt.

Regresjonen rendererer virkelig NSHostingView og bruker Vision-OCR til å kontrollere etiketter, valgt panel, tom liste, fjernet kilde og gjeninnsatt state. Bilder legges i xcresult. De to første testkjøringene feilet fordi Vision tolket «BETA TAB» med kyrilliske tegn; øvrige tilstandsasserts besto. Engelsk språkinnstilling alene løste ikke dette. Testetikettene er nå «Alpha choice» og «Bravo choice», med eksplisitt engelsk og deaktivert automatisk språkdeteksjon. Feilloggene beholdes; ingen glyph-normalisering skjuler resultatet.

`web-tabs-transitions.md` viser et separat restavvik: web respekterer tom liste, men manglende kilde gir standardpaneler. Native-kandidaten forblir tom for manglende levert dynamisk data. Dette skal ikke kalles full paritet.

## Videre etter denne runden

Fortsatt tydelige visuelle avvik: native standardtekst/seksjoner er sentrert, felt/enkle knapper mangler avgrensning, formeditor tar mye høyde, fast chatlogg sentrerer meldingen vertikalt. Web-chat har også lav kontrast i aktiv fane og kombinerer mørk fixture-CSS med lys chatkonfigurasjon. Det er feil å kopiere slike websvakheter ukritisk. Bruk samme kontrakt og sjekk begge faktiske visninger.

FullLibraryView krever bootstrapRuntime via egen viewmodel. Kjøring av vanlig RootView vil starte ekte vault/resolver; ikke gjør dette i testverten. Eventuell auth-/feilflate kan testes ved å eksponere eksisterende injeksjon gjennom View-initializer i isolert testkode. Et reelt bibliotek med data og normal innlogging gjenstår.

## Sluttstatus kl.03:25

14 tester består,0 feil: `phase2-tab-ocr-test-logs/parity-tests.xcresult`. Begge iOS-bygg og alle bildesesjoner er avsluttet. Fem etterbilder finnes i hver av `ios-after/` (26.2) og `ios18-after/` (18.6). `ios-simulator-final.png` er skjermbildet med statuslinje fra26.2. Begge isolerte simulatorapper er terminert, eksisterende simulatorer står fortsatt på. Browser er lastet på nytt, så den midlertidige chatvisningen er fjernet. Ingen aktive bygge-/testsesjoner igjen.

Mac-bildene har fått regenererte UUID-er/tidsstempler fra samme factory under siste capture. Web og begge iOS-kjøringer bruker identisk frosset chatkonfigurasjon/state; dette er verifisert objekt for objekt i `chat-fixture-provenance.json`. Ikke påstå byte-identitet mellom Mac og web. Fremover bør chat-fixturen eksporteres én gang og gjenbrukes også på Mac.

Begge native patcher er regenerert mot eksakte førkilder. `git apply --check` passer mot originale Binding og CellProtocol. `git diff --check` passer for begge kandidater. Hashsjekk av alle opprinnelige snapshotkilder viser0 endringer (`phase2-original-source-change-check.json`). Patcher er ikke anvendt på originalene.
