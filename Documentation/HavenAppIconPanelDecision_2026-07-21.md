# HAVEN appikon – panelbeslutning 2026-07-21

## Oppdrag og formål

- Eier: Kjetil Hustveit
- Formål: `purpose://gui.quality.functional-accessible`
- Oppdrag: Erstatt det detaljerte AI-/nettverksikonet med et appikon som er tydelig avledet av HAVEN-logoen, og vurder hvor langt formspråket bør påvirke Binding.
- Ramme: Endringen skal være reverserbar, bygge på eksisterende HAVEN-farger og ikke endre portable Skeleton-flater uten egen produktbeslutning.

## Mål og status

| Mål | Målekriterium | Status | Evidens / eier |
| --- | --- | --- | --- |
| G1: Gjenkjennelig HAVEN-ikon | De to karakteristiske buene er lesbare ned til 16 px; ingen tekst eller detaljstøy | Oppfylt teknisk | `gfx/HavenAppIconSource.svg`; visuell kontroll av 16 px-rendring |
| G2: Komplette native ressurser | iOS default/dark/tinted og alle deklarerte macOS-størrelser finnes, er RGB og uten alfa | Oppfylt | `Binding/Assets.xcassets/AppIcon.appiconset`; `sips`-kontroll |
| G3: Trygg påvirkning på apputtrykket | Merkevareform og aksent brukes i native skall/lasting uten å overstyre semantiske komponenter eller portable Skeleton-flater | Oppfylt | `Binding/HavenArcMark.swift`; `Binding/RootView.swift`; `AccentColor.colorset` |
| G4: Plattformbygg | macOS og iOS Simulator bygger med de nye ressursene | Oppfylt | `xcodebuild` 2026-07-21; eksisterende, ikke ikonrelaterte Swift 6-advarsler gjenstår |
| G5: Native visionOS-vurdering | Lagdelt ikon og bygg valideres i installert visionOS SDK | Blokkert lokalt | visionOS 26.2 er ikke installert. Eier: Kjetil; neste handling: installer Xcode-komponenten og vurder Icon Composer-lag |
| G6: Menneskelig gjenkjennelighet | HAVEN-brukere skiller ikonet fra generiske ring-/smilemerker i en ikonhylle | Åpent for produkteier | Eier: Kjetil; anbefalt før publisering: rask 5-sekunders gjenkjenningstest |

## Påstander og panelvurdering

| Påstand | Type | Panelresultat | Begrunnelse |
| --- | --- | --- | --- |
| `claim.haven-icon.arc-direction` – HAVEN-buene er sterkere som appikon enn tidligere AI-/nettverksgrafikk | Normativ/design | Støttet med vilkår | Mer særpreget og enklere i små størrelser, men må beholde nøyaktig geometri og testes mot generiske ringmerker |
| `claim.haven-icon.imagegen-production` – det genererte rasterkonseptet kan brukes direkte i produksjon | Prosjektkapabilitet | Avvist | Konseptet hadde en ny korallprikk, innbakt squircle og utilstrekkelig presis geometri |
| `claim.haven-icon.native-shell-only` – formspråket bør først påvirke native skall og lasting | Normativ/arkitektur | Støttet | Gir sammenheng uten å gjøre merkevarefarge til semantikk i alle kort, Cells eller portable Skeleton-flater |

## Rådgiverkomposisjon

- Merkevarerådgiver: støttet to-bue-retningen, krevde eksakt vektor, full-bleed master, komplette varianter og småstørrelsestest.
- Skeptiker/tilgjengelighet: påpekte risiko for et generisk ring-/smileuttrykk og at et statisk merke aldri må erstatte en semantisk `ProgressView`.
- Implementeringsrådgiver: anbefalte minimumsendringen appikoner + reell `AccentColor` + kodebasert `HavenArcMark` i eksisterende lastetilstand; frarådet bred endring av den allerede endrede `ContentView`.
- Moderatorbeslutning: behold kun de to eksisterende buene, uten korallprikken; bruk eksisterende sterk lilla `#433C98` og varm krem `#FFF8EE`; begrens første designpåvirkning til native skall.

Alle tre Codex-rådgiverne hadde tilgang til samme lokale skill-katalog som hovedagenten og fikk beskjed om å lese den relevante panel-skillen. Eksterne modellflater arver ikke lokale skills automatisk; nødvendige kontrakter må legges inn i oppdraget deres.

## Modelltilgjengelighet og avgrensning

- Kimi viste K3 som tilgjengelig modell, ikke «Kimi R3», men krevde innlogging før et svar kunne innhentes.
- Z.ai viste GLM-5.2, men modellen var deaktivert uten innlogging.
- Disse modellene er derfor ikke ført som rådgiverstemmer. Det ville vært uriktig å tilskrive dem designvurderinger de ikke leverte.

## Implementert beslutning

- Kanonisk, redigerbar kilde: `gfx/HavenAppIconSource.svg`.
- Deterministisk generator: `Scripts/generate_haven_app_icons.swift`.
- Native ikonressurser: `Binding/Assets.xcassets/AppIcon.appiconset`.
- Kodebasert merke: `Binding/HavenArcMark.swift`.
- Lastetilstand: statisk HAVEN-merke sammen med fortsatt semantisk `ProgressView` i `Binding/RootView.swift`.
- Appaksent: lys `#534AB7`, mørk `#7066D5` i `AccentColor.colorset`.
- iOS-lansering: fjernet ugyldig `UILaunchStoryboardName = AppIcon`; prosjektets genererte `UILaunchScreen` beholdes.
- Portable Skeleton-flater og øvrige korttemaer er bevisst ikke endret.

## Beslutningslogg og neste kontrollpunkt

1. Imagegen-konseptet ble brukt til utforsking, ikke som produksjonsoriginal.
2. Ny korallprikk ble forkastet fordi den tilfører semantikk som ikke finnes i HAVEN-logoen.
3. Produksjonsikonet ble bygget fra geometriske baner og eksportert uten innbakt hjørnemaske; operativsystemet maskerer ikonet.
4. Eksisterende detaljert ikonressurs ble fjernet fra asset-katalogen og kan gjenopprettes fra git ved behov.
5. Før publisering bør Kjetil godkjenne ikonhylletesten og avgjøre om en lagdelt Icon Composer-variant for visionOS/nyere Apple-uttrykk skal produseres.

## Kilder for plattformkrav

- Apple Human Interface Guidelines, App icons: <https://developer.apple.com/design/human-interface-guidelines/app-icons>
- Apple, Configuring your app icon: <https://developer.apple.com/documentation/xcode/configuring-your-app-icon/>
- Apple, Icon Composer: <https://developer.apple.com/icon-composer/>
