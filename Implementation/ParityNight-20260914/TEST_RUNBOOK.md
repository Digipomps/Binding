# Test av isolert paritetskandidat

Dette er UI-testing med syntetiske data, uten vault/resolver. Det er ikke vanlig HAVEN, et innlogget bibliotek, et fungerende meldingssystem eller en entitetskobling. Den normale appen er ikke erstattet.

Testapp-ID: `org.digipomps.haven.parity-night-test`. Produktet ligger i `/private/tmp/haven-parity-ios-products/HAVEN.app`; dette er et Simulator-bygg, ikke en telefon-IPA. Det er installert i de to simulatorene som allerede var startet før nattarbeidet. Appens minimum er iOS18.0. De fire interaktive forløpene er testet på26.2;18.6 har fem statiske renderer-captures.

## Prøv forløp på iOS26.2

Start simulatoren og vent til den er klar før du starter testappen. `bootstatus -b` fungerer også når simulatoren allerede kjører. Feilen `Unable to lookup in current state: Shutdown` betyr at dette oppstartstrinnet mangler.

```sh
xcrun simctl bootstatus 1F9CB294-13BC-4D49-B8C7-E969D4BFFA11 -b
```

Vis simulatoren i Xcode via **Xcode → Open Developer Tool → Device Hub**, og velg iPhone 16e med iOS26.2. På denne Macen er Xcode27 installert, og vinduet kan også åpnes slik:

```sh
open /Applications/Xcode.app/Contents/Applications/DeviceHub.app
```

Xcode26 bruker fortsatt **Simulator** (`open -a Simulator --args -CurrentDeviceUDID 1F9CB294-13BC-4D49-B8C7-E969D4BFFA11`). [Apple beskriver Device Hub her](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices). Oppstart fra Shutdown og den installerte chat-testen ble kontrollert på nytt22.september; bildet er lagret som `chat-launch-20260922.png`.

Kjør én av disse fra Terminal på denne Macen. Avslutt testappen før du bytter flagg. Ingen av kommandoene starter vanlig HAVEN eller kontakter en modell.

```sh
xcrun simctl launch 1F9CB294-13BC-4D49-B8C7-E969D4BFFA11 org.digipomps.haven.parity-night-test --parity-interactive-chat-long
```

Rull inne i loggen til «Transcript row12», trykk i skrivefeltet og skriv et lokalt utkast. Sendepilen skal være synlig med tastaturet oppe; én tastaturskjul-knapp vises. Sending til en modell er ikke tilgjengelig i denne testverten.

```sh
xcrun simctl terminate 1F9CB294-13BC-4D49-B8C7-E969D4BFFA11 org.digipomps.haven.parity-night-test
xcrun simctl launch 1F9CB294-13BC-4D49-B8C7-E969D4BFFA11 org.digipomps.haven.parity-night-test --parity-interactive-form
```

Rediger tittel og tekstfelt. Trykk i venstre padding på Save draft. Handlingen skal vise Failed fordi ingen identitet/resolver er koblet til; begge redigerte felter skal beholde utkastet. Det er et tilsiktet avvisningsforløp.

```sh
xcrun simctl terminate 1F9CB294-13BC-4D49-B8C7-E969D4BFFA11 org.digipomps.haven.parity-night-test
xcrun simctl launch 1F9CB294-13BC-4D49-B8C7-E969D4BFFA11 org.digipomps.haven.parity-night-test --parity-interactive-library
```

Bytt mellom Alle konfigurasjoner og For mine formål; etikettene skal være hele. Biblioteket stopper tilsiktet før autentisering. Oppdater prøver igjen, Lukk går tilbake til isolert testvert. Etter én oppdatering skal den vise Bootstrap attempts:2.

## Gjenta automatiske kontroller

Kjør fra `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Implementation/ParityNight-20260914/Binding`. Wrapperen beholder diskport40GiB og10% pluss reserve, to byggejobber, låste pakker og unikt testprodukt. Unngå parallelle Xcode-bygg og ikke bruk den gamle globale paritetsrunneren mot originalrepoet. Velg en ny LOG_DIR hvis bevis fra en tidligere kjøring skal bevares.

```sh
HAVEN_BUILD_MIN_FREE_PERCENT=10 HAVEN_XCODE_DERIVED_DATA_PATH=/private/tmp/haven-xcode-derived/Binding-Parity LOG_DIR=../repeat-ui-logs ../xcode-check.sh Binding.xcodeproj HAVEN Debug 'platform=iOS Simulator,id=1F9CB294-13BC-4D49-B8C7-E969D4BFFA11' ios-ui-tests
HAVEN_BUILD_MIN_FREE_PERCENT=10 HAVEN_XCODE_DERIVED_DATA_PATH=/private/tmp/haven-xcode-derived/Binding-Parity LOG_DIR=../repeat-mac-logs ../xcode-check.sh Binding.xcodeproj HAVEN Debug 'platform=macOS,arch=arm64' parity-tests
```

Fasit:4 iOS-forløp og15 Mac-tester, null feil. Dette er målrettet dekning, ikke hele produktets testpakke. Den separate UI-planen unngår en eksisterende iOS-kompileringsfeil i en annen Mac-renderaudit-test.

## Integrasjon

Produktpatchene er generert mot eksakt førkilde, inkludert original WIP. `prepare_scoped_patches.py` verifiserer førhashene, skriver patcher og kjører read-only apply-check mot originalrepoene. Den anvender ingen patch. Testvertens BindingApp.swift, ParityInteractiveHarness.swift, IOSParityCapture.swift, fixturebundle, prosjekt-ID og testplan er isolert testoppsett; aldri ship denne app-entrypointen.

En samlet, signert telefonkandidat med både entitetskobling, ny dataklient og disse UI-rettingene er ikke laget. Full praktisk personkobling trenger den integrasjonen og et fysisk ende-til-ende forløp med menneskets eget eierskapsbevis. Nattarbeidet gir ingen ny autoritet eller automatisk kobling av personlige entiteter.
