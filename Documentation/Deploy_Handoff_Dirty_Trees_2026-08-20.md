# Deploy-handoff: skitne trær i HAVEN — 2026-08-20

Målt kl. i dag med `git status -sb` og `git rev-list --left-right --count`.
Ingen bygg kjørt. Ingen endringer gjort.

---

## Kortversjon

| Repo | Branch | Divergens | Skitne filer | Alvorlighet |
|---|---|---|---|---|
| **CellScaffold** | `codex/bridge-multiplex-host-route-20260820` | **ingen upstream** · 49 foran / **128 bak** `origin/main` | 4 endret, 6 usporet | **Høy** |
| **CellProtocol** | `main` | 2 foran / **3 bak** `origin/main` | 1 usporet | **Middels** |
| **Binding** | `codex/havenagentd-sentinel-remote-intent-icon-20260804` | 2 foran upstream | 11 endret, 7 usporet | **Høy** |

---

## 1. CellScaffold — verst

Branchen har **ingen upstream**. Ingenting er pushet, altså ingen CI, ingen
backup, ingen andre kan se den. 49 commits ligger kun på Kjetils disk.

Samtidig ligger den **128 commits bak `origin/main`**. Det er ikke en branch som
kan merges rett inn — det er en gaffel som må saneres.

Skitne filer som betyr noe:

```
 M Sources/ScaffoldKit/AdminControlPlaneRouting.swift
 M Sources/ScaffoldKit/AdminScaffoldBridgeRoutes.swift
 M Package.resolved
?? Tests/AppTests/AdminScaffoldBridgeMultiplexRouteTests.swift
?? Documentation/Operations/WO_Salvage_Main_Derived_2026-08-20.md
```

To ting å merke seg: `Package.resolved` er endret uten å være committet, så
avhengighetspinner er udefinerte for alle andre enn denne maskinen. Og det
finnes allerede et **salvage-dokument** datert i dag
(`WO_Salvage_Main_Derived_2026-08-20.md`) — noen har altså allerede sett at
main-avledningen må reddes. Les det før noe annet gjøres.

**Signifikans:** ingen deploy fra CellScaffold er reproduserbar nå. Alt arbeid på
Agreement-siden (AgreementWorkbench, AIGatewayCell) lever i dette repoet.

---

## 2. CellProtocol — divergert main

`main` er 2 foran og **3 bak** `origin/main`. Lokal main har fått en egen
merge-commit; det er ekte gaffel, ikke bare etterslep.

De tre som mangler lokalt:

```
135d3c0 Add SkeletonElement.NavigationBar for bottom-anchored app navigation (#23)
fd8c8bc Handle scaffoldUnique create/register races in createAndRegisterCell (#22)
fc259fd Add SkeletonModifiers.wrap and a FlowLayout for real flex-wrap chips (#21)
```

**Signifikans, konkret:**

- `#23` legger til en **24. skeleton-elementtype** (`NavigationBar`). To ferske
  Codex-oppdrag er skrevet med «de 23 elementtypene holder, ikke oppfinn nye» som
  premiss. Det premisset er allerede utdatert i origin. Rebase før noen bygger UI.
- `#22` fikser et race i `createAndRegisterCell` for `scaffoldUnique`. Nearby-broen
  registrerer navngitte emit-celler per peer — det oppdraget rører nøyaktig denne
  koden.
- `#21` gir `FlowLayout`/flex-wrap chips, som er relevant for enhver ny enkel
  flate.

Å starte nytt arbeid før rebase betyr at det bygges mot en renderer som er tre
commits gammel.

---

## 3. Binding — deploy-kritiske filer ucommittet

Branchen er `codex/havenagentd-sentinel-remote-intent-icon-20260804` — datert
4. august, altså 16 dager gammel — ikke `main`.

De skitne filene er akkurat de som ble endret i App Store-runden 19. august:

```
 M Binding.xcodeproj/project.pbxproj
 M Binding/Info.plist
 M Binding/Binding.entitlements
 M Binding/Binding-iOS.entitlements
?? Binding/PrivacyInfo.xcprivacy
```

**Signifikans:**

- Nedjusteringen fra iOS 26.1 til **18.0** i seks konfigurasjoner ligger
  ucommittet i `project.pbxproj`. Den er aldri bygget eller kjørt. Går den tapt,
  går hele rekkeviddebeslutningen tapt med den.
- `_haven-radar._udp` i `NSBonjourServices` ligger ucommittet i `Info.plist`.
  Uten den er MPC-oppdagelse upålitelig på iOS 14+ — altså er nearby-funksjonen
  avhengig av en fil som ikke er sjekket inn.
- **`PrivacyInfo.xcprivacy` er usporet** *og* ikke lagt til app-targetets
  Resources build phase. Det er to separate blokkere for innsending, og den ene
  krever et manuelt steg i Xcode.

---

## Anbefalt rekkefølge

1. **Commit Binding først.** Det er lavest risiko og høyest tap hvis det ryker.
   Del gjerne i to: én commit for App Store-konfigurasjonen (pbxproj, Info.plist,
   entitlements, PrivacyInfo), én for resten. Legg `PrivacyInfo.xcprivacy` i
   Resources build phase i samme runde.
2. **Rebase CellProtocol `main`** mot origin. Tre commits, hvorav én endrer
   skeleton-vokabularet. Bygg og kjør testene etterpå.
3. **CellScaffold sist, og som egen sak.** Les
   `WO_Salvage_Main_Derived_2026-08-20.md`, bestem om branchen skal pushes som
   den er eller saneres mot main, og få `Package.resolved` committet uansett.

Grønn baseline på Binding — én vellykket `xcodebuild` etter iOS 18.0-nedjusteringen
— bør være port for alt nytt arbeid. Den finnes ikke i dag.
