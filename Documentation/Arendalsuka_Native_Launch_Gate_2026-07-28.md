# Arendalsuka: native lanseringsport

Dato: 2026-07-28  
Måldato: 2026-08-10

## Konklusjon

Webflaten skal være den offentlige fallbacken uansett. Native kan enten være:

1. **TestFlight-følgeapp** for inviterte testere under Arendalsuka.
2. **Offentlig App Store-app** som alle kan finne og installere.

Dette er to forskjellige releaseporter. TestFlight er raskere, men krever at
deltakeren installerer TestFlight og mottar invitasjon eller offentlig
testlenke. En offentlig App Store-lansering krever full metadata, personvern,
review og godkjenning før 10. august.

Kodekandidaten støtter foreløpig bare:

```text
https://staging.haven.digipomps.org/arendalsuka
```

Lenken åpner en skrivebeskyttet, host-forberedt
`Arendalsuka Participant Program`-konfigurasjon. Workbench- og Personal
Copilot-invitasjonslenker er med vilje ikke universal links ennå; de skal
fortsette på web til Binding har en separat, testet native mottaker.

## Lokalt bevis 2026-07-28

- To fokuserte Binding-tester godkjenner bare den kanoniske lenken, avviser
  authority-/path-/query-/fragmentvarianter og kontrollerer at
  programkonfigurasjonen er skrivebeskyttet og sideeffektfri.
- `HAVEN`-skjemaet bygger uten feil for generisk iOS Simulator med Xcode 26.3.
- Begge entitlement-filene består `plutil -lint`.
- CellScaffold AASA-suiten består 19 Swift-tester, seks compose-kontrakttester
  og én eksplisitt miljøallowlist-test.

Testene brukte rene worktrees. Binding-testen løste CellProtocol fra
`origin/main` ved `7974030`; CellScaffold-testen brukte den låste
SwiftPM-revisjonen `0d87504`. Bygget gir eksisterende Swift
konkurranse-/isolasjonadvarsler fra `origin/main`, men ingen av dem stammer fra
denne endringen og test-/buildkommandoene returnerte 0.

Dette beviser kildekode og usignert iOS-kompilering. Det beviser ikke
provisioning, signert entitlement, Apple-CDN, TestFlight/App Store eller fysisk
universal-link-levering.

## Beslutninger Kjetil må ta

### 1. Velg distribusjonsnivå

- [ ] Web er autoritativ offentlig kanal; native er valgfri TestFlight.
- [ ] Eller: offentlig App Store-app er absolutt go/no-go.

Anbefalt risikoprofil for 10. august er web som autoritativ kanal og TestFlight
som kontrollert følgeapp. App Store kan fortsatt leveres, men skal ikke gjøre
den fungerende webreisen avhengig av Apples behandlingstid.

### 2. Lås offentlig domene

- [ ] Bekreft at `staging.haven.digipomps.org` faktisk skal være
  deltakeradressen under arrangementet.
- [ ] Hvis ikke: oppgi det endelige HTTPS-domenet før signert bygg.

Domeneendring krever samtidig endring i:

- Binding-entitlementene `applinks:` og `webcredentials:`
- CellScaffolds godkjente produksjonshost
- WebAuthn `RP_ID` og `RP_ORIGIN`
- `CELL_SCAFFOLD_PUBLIC_BASE_URL`
- domenets `apple-app-site-association`

### 3. Lås Apple-identiteten før første opplasting

Repoet bruker per 28. juli:

```text
PRODUCT_BUNDLE_IDENTIFIER=org.digipomps.havenplayground
DEVELOPMENT_TEAM=5UT5HQTCV9
```

- [ ] Bestem om `org.digipomps.havenplayground` er endelig produksjons-bundle
  ID eller om appen skal få en varig produkt-ID.
- [ ] Registrer/bekreft en eksplisitt App ID i Apple Developer.
- [ ] Aktiver Associated Domains for denne App ID-en.
- [ ] Opprett App Store Connect-record med samme bundle ID.

Bundle ID kan ikke endres på App Store Connect-recorden etter at et bygg er
lastet opp. Ikke anta at Team ID er lik appens application-identifier prefix;
les den faktiske `application-identifier` fra det signerte bygget eller
provisioning-profilen.

### 4. Velg minimum iOS-versjon

Prosjektet har nå:

```text
IPHONEOS_DEPLOYMENT_TARGET=26.1
```

- [ ] Godta at bare enheter med iOS/iPadOS 26.1 eller nyere kan installere.
- [ ] Eller: velg en lavere målversjon og gi tid til compile-, simulator- og
  fysisk enhetstest på den versjonen.

Dette er et produktvalg med direkte effekt på hvor mange deltakere som kan
installere appen.

### 5. Eier av App Store-innhold og review

- [ ] Navn, undertittel, kategori, beskrivelse og norske skjermbilder.
- [ ] Offentlig support-URL og personvernerklæring, også tilgjengelig i appen.
- [ ] App Privacy-svar for appen og alle tredjeparts-SDK-er.
- [ ] Oppdatert aldersklassifisering.
- [ ] Eksportkontrollsvar for kryptering.
- [ ] Review-notat, testinstruks og fungerende review-identitet/demo.
- [ ] Konto-sletting i appen dersom appen oppretter konto.
- [ ] Moderering/report/block dersom deltakerinnhold eller chat er med i
  review-bygget.

`origin/main` har ikke en app-eid `PrivacyInfo.xcprivacy`. Det er en åpen
releaseport: arkivet må generere en privacy report, required-reason API-er og
tredjepartsmanifest må revideres, og et nøyaktig manifest må legges til dersom
rapporten krever det. Ikke fyll manifestet med antakelser.

## Apple-/domenehandlinger

1. I Certificates, Identifiers & Profiles:
   - velg den eksplisitte App ID-en
   - aktiver Associated Domains
   - la Xcode regenerere signeringsprofilen, eller regenerer den manuelt
2. I Binding-targetets Signing & Capabilities:
   - bekreft riktig Team
   - bekreft Associated Domains
   - behold bare domenene som faktisk er godkjent
3. Lag et Release-arkiv med Xcode 26 eller nyere.
4. Kontroller det signerte arkivet, ikke bare kildefilene:

```sh
codesign -d --entitlements :- /path/to/HAVEN.app
plutil -p /path/to/HAVEN.app/Info.plist
security cms -D -i /path/to/HAVEN.app/embedded.mobileprovision
```

Det signerte resultatet må vise:

```text
application-identifier=<APP_IDENTIFIER_PREFIX>.<BUNDLE_ID>
com.apple.developer.associated-domains=[
  applinks:<PUBLIC_HOST>,
  webcredentials:<PUBLIC_HOST>
]
```

5. Sett serververdiene fra dette signerte beviset:

```text
HAVEN_AASA_TEAM_ID=<APP_IDENTIFIER_PREFIX>
HAVEN_AASA_BUNDLE_ID=<BUNDLE_ID>
CELL_SCAFFOLD_PUBLIC_BASE_URL=https://<PUBLIC_HOST>
PUBLIC_BASE_URL=https://<PUBLIC_HOST>
RP_ID=<PUBLIC_HOST>
RP_ORIGIN=https://<PUBLIC_HOST>
```

6. Deploy samme AASA-kontrakt før appen installeres. Apple henter AASA gjennom
   sin CDN; en grønn direkte `curl` er nødvendig, men ikke tilstrekkelig.
7. Installer det eksakte TestFlight/App Store-bygget på en fysisk enhet.
8. Åpne lenken fra Meldinger eller Mail, ikke ved å skrive den i Safari:
   - installert app: åpner HAVEN og Arendalsuka-programmet
   - app ikke installert: åpner samme fungerende webprogram
   - ugyldig variant: utfører ingen sensitiv handling
   - samarbeids-/Workbench-lenker: forblir på web

## TestFlight-sporet

- [ ] Last opp bygg og løs eventuell `Missing Compliance`.
- [ ] Legg inn beta-beskrivelse, hva som skal testes og feedback-epost.
- [ ] Start med interne testere.
- [ ] Opprett intern gruppe før ekstern gruppe.
- [ ] Send første eksterne bygg til TestFlight Beta App Review.
- [ ] Del offentlig testlenke eller inviter konkrete deltakere.
- [ ] Registrer installert buildnummer, enhetsmodell, OS og testresultat.

## Offentlig App Store-spor

Alt i TestFlight-sporet pluss:

- [ ] Fullfør alle obligatoriske app- og versjonsfelter.
- [ ] Velg riktig Release-bygg.
- [ ] Bekreft DSA-/handelsstatus og tilgjengelige regioner.
- [ ] Kjør account deletion-, UGC-, permission- og privacy-portene.
- [ ] Send til App Review med backend og review-fixturer tilgjengelig.
- [ ] Velg manuell eller kontrollert release; dokumenter rollback/support.

## Go/no-go

Native er grønn først når samme signerte bygg, samme bundle ID/app-prefix,
samme domene og samme AASA-payload er verifisert på fysisk enhet. Et grønt
Xcode-bygg, en grønn AASA-rute eller en fungerende webside alene lukker ikke
porten.

## Offisielle Apple-kilder kontrollert 2026-07-28

- https://developer.apple.com/documentation/xcode/supporting-associated-domains
- https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app
- https://developer.apple.com/news/upcoming-requirements/
- https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview
- https://developer.apple.com/app-store/app-privacy-details/
- https://developer.apple.com/support/offering-account-deletion-in-your-app/
- https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance
