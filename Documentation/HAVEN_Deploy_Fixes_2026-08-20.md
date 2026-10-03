# HAVEN — rettelser klare for neste deploy

Dato: 20. august 2026
Verifisert på: iOS 18.6-simulator (iPhone 16 Pro), signert Debug-build, kald og varm start.

---

## 1. Rotårsaken — funnet, ikke gjettet

Feilen var **ikke** treghet, og ikke autorisasjon. Den var en deterministisk `notFound`.

Med diagnostikk påslått ga probe-grenen dette:

```
[CellBase][skeleton] Root binding probe failed for Co-Pilot: perspective.perspective: notFound
```

Tidsstemplene for de fem forsøkene lå 309–359 ms fra hverandre — nøyaktig `retryDelayNanoseconds = 300_000_000` pluss noen få millisekunder arbeid. **Selve lesningen tok single-digit millisekunder.** Retry-løkka bidro kun med 1,3 sekunder forsinkelse foran et garantert nederlag, akkurat som du sa.

### Kjeden

1. Co-Pilot-skeletonet binder `perspective.perspective.state.activePurposeCount` (`ConfigurationCatalogCell.swift:9167` og `:9171`) — label `perspective`, keypath inne i cellen `perspective.state.activePurposeCount`.
2. `SkeletonBindingProbeSupport.rootProbe` kutter til rot: label `perspective`, rootKeypath `perspective` → proben leser `perspective.perspective`.
3. Porthole videresender `get("perspective")` til Perspective-cellen.
4. `PerspectiveCell` registrerte intercepten på **`perspective.state`**, ikke på rotnøkkelen `perspective`. `GeneralCell.get` fant ingen exact intercept, ingen rootValue-intercept og ingen rootGet-intercept for `perspective` → `throw KeyValueErrors.notFound`.

Det betyr at også den *faktiske* bindingen `perspective.state.activePurposeCount` var uten dekning, fordi `GeneralCell`s nested-fallback (`resolveNestedValue`) forutsetter at rotnøkkelen serveres.

### Fiksen

`CellProtocol/Sources/CellApple/PurposeAndInterest/Cells/PerspectiveCell.swift` — intercepten er flyttet fra `perspective.state` til rotnøkkelen `perspective`, og returnerer `.object(["state": perspectiveStatePayload()])`.

Da løses alle tre nivåene gjennom samme intercept:

| Lesning | Før | Etter |
|---|---|---|
| `perspective` | `notFound` | objekt ✅ |
| `perspective.state` | payload ✅ | payload via nested-fallback ✅ |
| `perspective.state.activePurposeCount` | `notFound` | verdi via nested-fallback ✅ |

Explore-kontrakten er flyttet tilsvarende, slik at kontrakten beskriver det cellen faktisk serverer.

### Verifisert

```
[CellBase][flow] attach label=perspective connectState=connected
[CellBase][flow] INTR:get:perspective:...
[CellBase][flow] INTR:get:perspective.activePurpose:...
```

Begge prober svarer på **første forsøk** — ett tidsstempelkluster, ingen retries. Null `Root binding probe failed` på både kald og varm start. Chat-flaten rendrer nå full samtale-UI med butlerens åpningsmelding, skrivefelt og send-knapp.

**Retry-løkka er ikke rørt.** Den var aldri mekanismen som fikset noe, og med rotårsaken borte utløses den ikke. Jeg vil ikke justere den uten en reell infrastrukturfeil å kalibrere mot.

---

## 2. Hvorfor den slapp gjennom testene

`testPersonalCopilotLocalSurfacesLoadWithoutReferenceFailures` kjører ni Personal Co-Pilot-konfigurasjoner gjennom `CellConfigurationVerifier` — men **`personalInviteChatMenuConfiguration()` (Co-Pilot) stod ikke i listen.** Hovedflaten var den ene som ikke ble testet.

Co-Pilot er nå lagt til i den listen, med en kommentar om hvorfor.

---

## 3. Om `identityUnique` — den er allerede satt, og skal være det

Perspective er registrert som `.identityUnique` + `.persistant` begge steder:

- `Binding/Binding/BootstrapView.swift:413-420`
- `CellProtocol/.../AppInitializer.swift:235-242`

Det er riktig scope og bør ikke endres. Perspective holder eierens private formåls- og interessemodell; den skal aldri deles på tvers av identiteter, og `identityUnique` er nettopp garantien for det.

**Men scopet betaler seg først når identiteten er stabil.** Loggene viser at eier-UUID fortsatt er ny ved hver oppstart:

| Kjøring | Eier |
|---|---|
| run1 | `2EDB14CD-7B71-45D7-ABC5-B8E9E854A534` |
| run2 (samme install) | `75EF71B7-9E64-4F01-9F24-E7B2579D7B60` |

Ny identitet → ny celle-UUID → `.persistant` får aldri noe å gjenopprette. `Perspective.json` skrives fortsatt aldri.

Svaret på spørsmålet ditt er derfor: **ikke endre scopet — fiks identiteten.** Kilden er `BindingStartupIdentityVault` (rent minne, nye P256-nøkler per prosess), som er aktiv gjennom `ensureInfrastructureBaseline()`. Overgangen til den Keychain-baserte `IdentityVault.shared` skjer først i `ensureBaseline()`, kalt fra `ContentView`. Det er den samme defekten som gjør at butleren ikke kan huske navnet sitt.

Den fiksen er større enn resten her og bør være sin egen, verifiserbare endring — ikke smettes inn i denne deployen.

---

## 4. Øvrige rettelser i denne runden

**Rå `NSError` ut av brukerflaten.** `NotificationEnrollmentManager` la `error.localizedDescription` rett inn i tekst som vises til brukeren, som ga den røde «APNS registration failed: fant ingen gyldig «aps-environment»-godkjenningsstreng for appen» i banneret. Tre strenger er erstattet med menneskelig tekst som ikke lekker systemfeil. Teknisk detalj printes fortsatt for utviklere i `BindingAppNotifications`.

**Diagnostikk som faktisk er lesbar.** `BindingRuntimeDiagnostics` installerer en handler som svelger alle `CellBase.diagnosticLog`-meldinger med mindre debugpanelet er synlig — derfor var loggene tomme. Ny flaggstyrt oppstartsdiagnostikk aktiverer domenene `resolver`, `identity`, `agreement`, `flow`, `skeleton` og installerer en skrivende handler:

```
xcrun simctl launch --console-pty <udid> org.digipomps.haven --haven-runtime-diagnostics
# eller: HAVEN_RUNTIME_DIAGNOSTICS=1
```

Av som standard, ingen effekt i vanlige kjøringer.

**Teknisk feildetalj logges nå ved probe-feil.** `ContentView` logger `summarizeBindingFailures(...)` i `.failed`-grenen. Det var fraværet av nettopp denne linja som gjorde feilen så vanskelig å isolere.

**`ageRatingHint`** endret fra utgått `"12+"` til `"13+"`.

---

## 5. Endrede filer

**CellProtocol**

- `Sources/CellApple/PurposeAndInterest/Cells/PerspectiveCell.swift` — rotårsaken

**Binding**

- `Cells/ConfigurationCatalogCell.swift` — `ageRatingHint`
- `Binding/NotificationEnrollmentManager.swift` — brukervendte feiltekster
- `Binding/BindingAppNotifications.swift` — flaggstyrt diagnostikk
- `Binding/ContentView.swift` — logging av probe-feildetalj
- `BindingTests/CellConfigurationVerifierXCTest.swift` — Co-Pilot inn i flatetesten
- `Binding/Info.plist`, `Binding/Binding.entitlements`, `Binding.xcodeproj/project.pbxproj` — fra forrige runde (iOS 18.0, `_haven-radar._udp`, visionOS fjernet)
- `Binding/PrivacyInfo.xcprivacy` — ny, **må fortsatt legges til targetets Resources build phase i Xcode**

---

## 6. Nytt funn i denne runden

Når Chat-flaten endelig rendrer, vises tekstverdier **med anførselstegn**: `"HAVEN Co-Pilot"`, `"Hva vil du få gjort? …"`, `"Klar"`. Bundne strengverdier blir stringifisert med sine JSON-anførselstegn i stedet for å rendres som ren tekst.

Kosmetisk, men det er det første brukeren ser, og det leser som uferdig. Jeg har ikke sporet den — den lå utenfor det du ba om, og jeg vil ikke shippe en gjetning i samme deploy som en verifisert fiks.

---

## 7. Ikke verifisert

- **Testen er ikke kjørt.** `xcodebuild build` bygger ikke testtargetet. Kjør `Scripts/test_binding.sh -only-testing:BindingTests/CellConfigurationVerifierXCTest/testPersonalCopilotLocalSurfacesLoadWithoutReferenceFailures` før deploy — den skal nå dekke Co-Pilot.
- **Kun simulator.** Ingen fysisk enhet, ingen eldre maskinvare.
- **Andre flater med samme mønster.** `profileDraft` (13 bindinger), `privacyAudit` (9) og `graph` (12) bruker samme label-relative mønster mot `subscribeFeed: false`-referanser. De var grønne i den eksisterende testen, men jeg har ikke inspisert dem manuelt for samme rot-intercept-gap.
- **`.vision-preview/`** i repoet inneholder logger, skript og skjermbilder fra denne økten. Usporet i git, trygt å slette. Jeg får ikke slettet mapper herfra.
