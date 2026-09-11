# Personens entitet på flere steder — praktisk pilot

Dato: 11. september 2026. Kandidatene er isolerte fra de opprinnelige arbeidsgrenene. Ingen av brukerens faktiske entiteter er koblet, slått sammen eller flyttet i dette arbeidet. Staging og produksjon er ikke oppdatert av denne oppgaven.

## Hva brukeren skal oppleve

«Utvid min entitet hit» kobler menneskets entiteter. HAVEN-appen, sprout og menyhjelperen åpner samme personseremoni. Et scaffold er stedet entiteten finnes; dets administrator-/tjenestenøkkel er ikke personen. En agent får tilgang gjennom en egen menneskegitt delegering.

Den native appen viser «Her» og «Der» før den ber om signering. Personen sammenligner fire kontrollord og bekrefter med sin passkey der den andre entiteten finnes. Nærhet og QR fører til den samme kontrollen. Data flyttes ikke av koblingen, og fullføring lover ikke gjensidig tilgang til alle lokale data.

## Reviewbare kandidater

| Repo | Kandidat | Review |
| --- | --- | --- |
| CellProtocol | `436b6a77d42da1317e71f3024dfc0d3e18de796f` | [PR38](https://github.com/Digipomps/CellProtocol/pull/38) |
| CellScaffold | `5ee51e68d9d29768140e9f6b6c864ff1f994b4bc` + avgrenset oppstartsretting `e3de5c24` | [PR241](https://github.com/Digipomps/CellScaffold/pull/241) |
| Binding | `codex/entity-continuity-20260911` | Lokal kandidat; endelig commit/teststatus føres under |
| sprout | `d2dcfa2` | [PR2](https://github.com/Digipomps/Sprout/pull/2) |
| HavenAgentD | `022661a` | [PR15](https://github.com/Digipomps/HavenAgentD/pull/15) |

Kildene ligger under `Implementation/EntityContinuity-20260911/` i Binding-arbeidsmappen. Disse er lokale kloner, ikke de opprinnelige søsterrepoene. Endringer i de opprinnelige, urene trærne er bevart.

## Kan prøves lokalt nå: faktisk nærhetsoppdagelse

Den lille pakken trenger ikke server, brukeridentitet eller hele CellProtocol-bygget. Kjør fra `CellProtocol/Packages/CellNearby` i kandidaten:

```sh
swift test -j 2 --disable-automatic-resolution
python3 Scripts/smoke_nearby.py
```

Røykprøven bruker en tilfeldig, syntetisk invitasjon som ikke finnes på serveren. To virkelige prosesser annonserer og finner den med Network/Bonjour. Den kontrollerer også utløp. Dette er radio-/oppdagelsesbevis, ikke eierskapsbevis.

For to maskiner: bruk `haven-nearby --help` for `advertise --offer-file` på den ene og `browse --seconds 120` på den andre. Bruk samme syntetiske offerformat fra røykprøven. Enhetene må tillate lokalt nettverk. Test både samme Wi-Fi og direkte nærhet; sistnevnte er ikke fysisk verifisert her. Ikke kopier ekte QR-, passkey- eller koblingspakker inn i logger eller Git.

Sprout bruker den samme følgesvennen:

```sh
SPROUT_NEARBY_HELPER=/absolutt/sti/til/haven-nearby sprout nearby browse --seconds 30
sprout entity connect --place staging
sprout entity connect --place app
```

Pakket distribusjon må legge `haven-nearby` ved siden av sprout, eller konfigurere den eksplisitte banen. I native sprout og menyhjelperen brukes «Utvid min entitet …». Inngangene forutsetter en installert HAVEN-app som håndterer `haven://link-devices`.

## Telefon mot personentitet i staging

Forutsetninger: reviewet serverkandidat må være installert på det betrodde HTTPS-stedet, og telefonen må ha en korrekt signert HAVEN-kandidat. Et generisk usignert iOS-bygg er ikke en installasjonspakke. Bruk Xcodes eksisterende HAVEN-team/profil for enheten; ingen nøkkelkopiering mellom apper eller bruk av Scaffold/admin-nøkkel. Kontroller appens byggproveniens og serverens `/health/build` mot avtalte revisjoner før testen.

1. Logg inn som riktig menneske på staging og åpne `/link`. Lag en invitasjon. Kontroller personens navn og stedet.
2. Åpne «Utvid min entitet» på telefonen. Velg «Skann QR-kode», eller bruk telefonens Kamera-app og åpne lenken. Ved manglende kamerastøtte kan lenken limes inn. Kamera starter bare etter et aktivt valg.
3. Les «Her», «Der» og HTTPS-stedet før «Dette er mine entiteter — fortsett». Kontroller at feil person/sted kan avbrytes uten signering.
4. Sammenlign de fire ordene på begge sider. Godkjenn med personens registrerte passkey; user verification er påkrevd i både første kontroll og serverens nye kontroll av beviset.
5. Vent på faktisk serverfullføring. Appen skiller mellom fjern godkjenning og bekreftet lokal registrering. Den skal aldri si at alle data er tilgjengelige bare fordi et transportkall lyktes.
6. Lukk og åpne appen. Kontroller at registreringen finnes på personens koblingsside. Prøv en konkret beskyttet prøveressurs som var avvist før; dette krever den separate dataoppgavens gateway/policy. En liste over koblinger er ikke bevis på fungerende dataadgang.
7. Tilbakekall fra koblingssiden der godkjenningen ble gitt. Kontroller at en ny beskyttet lesing og en gjenopptatt fullføring blir avvist. Kontroller også en allerede åpen forbindelse.

Gjenta separat for personens entitet i produksjon når staging-kriteriene er oppfylt. En vellykket staging-seremoni kobler ikke automatisk personens produksjonsentitet. Agenter må fortsatt bruke sin uttrykkelige delegering.

## Samme personseremoni via nærhet

1. På den innloggede koblingssiden: lag invitasjon, velg «Finn på telefonen», åpne HAVEN-publiseringslenken på Macen, og bekreft synlighet.
2. På telefonen: «Finn i nærheten», eventuelt tillat lokalt nettverk, og velg invitasjonen fra riktig sted.
3. Telefonen stopper lokal oppdagelse før den henter invitasjonen over HTTPS. Fullfør deretter de samme person-/kontrollord-/passkey-stegene som for QR.
4. Avbryt publisering, bakgrunnssett appen eller la invitasjonen utløpe; den skal forsvinne. Utløpte, erstattede, brukte og tilbakekalte tilbud skal ikke kunne brukes til ny kobling.

Bonjour-feltene inneholder versjon, HTTPS-origin, tilfeldig 256-bit offer-ID og utløp. Ingen navn, person-ID eller nøkler annonseres. Den som oppdager et aktivt tilbud kan hente invitasjonen og se visningsnavnet; dette krever uttrykkelig publisering. Invitasjonen gir aldri tilgang i seg selv.

## Avbrudd som skal prøves

| Avbrudd | Forventet resultat |
| --- | --- |
| Avbryt mens telefonen henter lokal identitet | Ingen signering eller forespørsel etter avbruddet |
| Avvis passkey / feil kontrollord | Ingen aktiv kobling |
| Telefonen mister svaret etter serverfullføring | Eksakt verifisert pakke er allerede lagret kryptert; åpne flyten og gjenoppta |
| Start telefonappen på nytt med ventende pakke | Vis uavklart status; send samme pakke, uten ny signatur, når personen velger å gjenoppta |
| Serveren starter på nytt etter lagret personbevis | Eksakt pakke kan gjenfinnes via kryptert serverbevis; ingen ny JTI-forbruk ved allerede fullført runtime-kobling |
| Tilbakekalling før gjenopptaking | Server avviser; klient lagrer ingen ny aktiv autoritet |
| Lokal kvitteringslagring feiler | Behold ventende pakke; ikke rapporter fullført lokal aktivering |
| Kryptert pakke er skadet / Keychain låst | Stopp; ingen ny signering og ingen plaintext-fallback |

Å forkaste den lokale ventende pakken trekker ikke tilbake en eventuell allerede godkjent fjernkobling. Serverens forberedte bevis har en begrenset retryperiode; hvis serveren aldri mottok pakken før invitasjonen utløp, kreves ny seremoni. Automatisk gjenopptaking av en ennå ikke hentet godkjenningspakke etter appkrasj er ikke implementert. Det er først den lokalt verifiserte fullføringspakken som ligger i outboxen.

## Verifikasjon og åpne grenser

- CellNearby: 3 tester og faktisk lokal toprosess-oppdagelse/utløp bestått. CellProtocol PR38 sine tre CI-gater bestått.
- Binding: macOS-bygg og 11 målrettede koblingstester bestått. Tester bruker syntetiske identiteter og eget kryptert testlager, aldri brukerens kvitteringer eller Keychain. Den fysiske Keychain-/Face ID-/telefonbanen gjenstår.
- iOS: første generiske fullbygg bestått; sluttbygg etter outbox føres under. Ingen fysisk installasjon, TestFlight eller passkey-seremoni er utført.
- Sprout: CLI og macOS-app bygger, 3 supporttester og reell kort nærhetslesing bestått. Menyhjelperens faktiske produkt bygger.
- Server: første kandidat bygde og besto Swift-, Admin- og torsdagens P0-nettlesergater i CI. Samme kjøring feilet i separat dokumentprøve: et bilde nådde ikke den andre økten. Ny evidensintegrasjon er til CI-verifikasjon; ingen grønn prod-godkjenning er gitt.
- Lokal full serverbygging er sperret av repoets eksplisitte krav om 10 prosent ledig disk etter reserve. Kravet er ikke omgått og ingen cache-/datarydding er utført.

Det er ikke bevist at personens eksisterende app-, agent-, meny-, staging- og prodrepresentasjoner allerede er samme entitet. Den nye flyten gjør korrekt bevisføring testbar; den erstatter ikke menneskets faktiske godkjenning eller en funksjonell lesetest.

## Network, eldre OS og friksjon

Ny kode bruker NWBrowser/NWListener med Bonjour, ikke Wi-Fi Aware. NWBrowser finnes fra macOS 10.15/iOS 13, som er eldre enn de berørte appenes støttede minima. Vi trenger derfor ikke en Multipeer-gren bare for de støttede OS-versjonene. Eksisterende Multipeer-scanner beholdes for eldre HAVEN-peers; dens wireprotokoll er ikke kompatibel med Network-adapteren.

Apple anbefaler Network for ny kode i [TN3213](https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework). Se også [Wi-Fi API-oversikten](https://developer.apple.com/documentation/technotes/tn3111-ios-wifi-api-overview) og [lokalt nettverk og personvern](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy). Kamera-/DataScanner-støtte varierer; QR via systemkamera eller innlimt lenke er fortsatt tilgjengelig. Apples [filbeskyttelse for iOS](https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files) supplerer outboxens egen AES-kryptering.

Nærhet kan spare kamera og sikting, men første publisering trenger en native app og lokalt-nettverkstillatelse. For en fjernserver kan QR ha færre steg. Prøv begge i byttet rekkefølge, med og uten tidligere gitte tillatelser; mål tid, feil person/sted, avbrudd og behov for hjelp før nærhet velges som standard.

## CellProtocol-forslag for Kjetils vurdering

Implementert som additiv draft: en liten separat `CellNearby`-pakke med invitasjonsformat og Apple-adapter. Den kan brukes fra sprout uten å trekke inn hele CellBase. Autoriteten forblir eksisterende CellBase/EntityAnchor-kontrakter; ingen resolver-/storage-semantikk er endret i denne kandidaten.

Foreslått neste kontraktarbeid, ikke vedtatt her: retningsbestemte personbevis for begge dataretninger, opprinnelig forfattersignatur adskilt fra stabil lagringsmyndighet, egne eksplisitte lagrings-/replikeringsrettigheter, tilbakekalling ved commit og indeks-/eksportgrenser per datafamilie. To nøkkelbevis alene gir ikke rett til å slå sammen alle avtaler og innhold.

Den bestilte Astra-oppgaven «Entitetsdata på tvers av scaffolds» eier forskning, querygateway, lesing/skriving/indeksering, robusthetstester og videre promotering mot deploy. Oppgave-ID: `01a090e0-cced-7351-a2b1-f82408848442`, data-PR240. Den har fått presiseringen om menneskets entitet og den konkrete koblingsintegrasjonen. Handoff: `Entity_Fabric_Astra_Handoff_2026-09-11.md`.
