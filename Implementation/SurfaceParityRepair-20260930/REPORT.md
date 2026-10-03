# HAVEN — flater fra andre scaffolds

Oppdatert 30. september 2026. Dette er en **lokal, isolert testkandidat**, ikke en produksjonsutrulling. Reparasjonspakken er ferdig implementert, testet og lagret lokalt. Endelige revisjoner og byggproveniens står i `candidate-manifest.json`.

## Resultat og grense

En rekke konkrete feil er implementert og testet i Binding, CellProtocol og CellScaffold. Originale Skeleton-payloads gjengis med samme frosne data i native og web. Innhold, lister, tabeller, komponentlokale handlinger og lyst Porthole-tema er vesentlig forbedret.

**Påstanden «alle flater fra alle scaffolds kjører og ser identiske ut» er fortsatt ikke dokumentert.** Den generelle sikre fjernbroen krever det separate CP53/AP5/AP7-arbeidet; noen kildebundne elementer inne i komponentmontasjer har fortsatt eksplisitte kapabilitetsgrenser. Arbitrære CSS-temaer og iOS er ikke sertifisert av macOS-testene.

Se [sammenligningsgalleriet](PARITY_REVIEW.html) og [matrisen med alle scenarioer og payload-hasher](parity-matrix.csv) for faktiske native/web-bilder. Det viser innholdskontroller og lar deg se de gjenværende visuelle forskjellene. En grønn tekstkontroll betyr ikke pikselidentitet.

## Implementert

| Del | Endring | Bevis |
| --- | --- | --- |
| Binding-host | Toppjustering; List-maler og radkontekst beholdes; Grid-synlighet løses per rad; overlay-ID-er er stabile og scopes per liste/rad; Tree/ComponentSurface presentasjonsmodifiers håndteres | Native renderer- og overlaytester |
| Tilstand | Binding bruker eksplisitt input eller observerbar `PortholeViewModel.skeletonRootData`; snapshot-testene bruker VM-veien | 70 native opptak fra faktisk BindingSkeletonView |
| Native renderer | Korrekte Reference-verdier, tabellceller, statiske/bundne lister, layout og wrapping; standard lyst Porthole-tema for typografi, knapper, input, Picker, tabell og navigasjon | CP Skeleton-suiten og faktiske NSHosting-bilder |
| Kontrollhandlinger | Klikkbar knapp-padding, virkelige AppKit feltredigeringer, korrekt initialt Picker-valg uten mutasjon, ekte menyvalg og ulike verdier med samme etikett | Native muse-/felteditor-regresjoner |
| ComponentSurface | Lokale kildehandlinger bruker aktiv requester og normal Resolver; separat mount-kontekst; payload urørt; nil GET skilles fra null SET; manglende SET-svar gir uavklart utfall uten retry | 6 tester med ekte Cells/Agreements, to montasjer, URL-klikk og tilgangsnekt |
| Offentlig katalog | Fire statiske GET-ruter bruker eksisterende offentlig lesemodell; fungerer når sentral vault nekter ny identitet | 4 Swift-tester, inkludert policy og strict-vault HTTP |
| Web-host | Aliaser dannes bare for identiske celleendepunkter; List kombinerer bundne og statiske rader; lange ubrutte tekster brytes | 6 Node-tester og målrettede nettlesertester |
| Bilde-fixture | Korrupt PNG erstattet med gyldig 32×32 firefeltsbilde; tester krever faktisk geometri og farger | Native rasterfarger og web decode/natural-size/fargesampler |
| Testkorpus | 26 faktiske enum-typer og 9 publiserte CellScaffold-fixtures, hver i 390 og 1280 px | 70 scenarioer per renderer |

Ingen normalisering fjerner styling eller materialiserer List til VStack for å få de nye snapshot-testene grønne. Host-aliasene er en eksplisitt kandidatkomposisjon; original staging-komposisjon og før-bilder er bevart.

## Teststatus

Sluttresultater fra de relevante lokale testportene:

| Test | Resultat | Artefakt |
| --- | --- | --- |
| CellProtocol Skeleton-kontrakter/native | 188/188, ingen skips | `renderer-skeleton-contract-tests-188.log` |
| Binding integrasjon | 30/30, ingen skips eller runtime warnings | `integrated-delivery-summary.json` |
| Native originalpayload-bilder | 70/70; 64 tekstkontroller, 2 Image-fargekontroller, 4 Spacer/Divider med kun rasteropptak | `native-acceptance-delivery/` |
| Web med samme payload/state | 70/70, ingen sidefeil eller manglende forventet tekst/valgt verdi/bildefarge | `web-acceptance-delivery/` |
| Web siste endrede CSS + liste + katalog | 22/22 | `web-final-regressions.log` |
| Offentlig katalog Swift | 4/4 på publisert CP-avhengighet | `logs/cellscaffold-catalog-tests-delivery.log` |
| Host-alias Node | 6/6 | Se `TRANSPORT.md` |
| Staging HTTP/handlinger | 11/11; dette er ikke brotesten | `remote-http-summary.json` |

Kjøringene overlapper; tallene summeres ikke til ett antall unike tester. De levende HTTP-kildene var CellScaffold staging; andre scaffold-implementasjoner er ikke gjennomkjørt. Dette er de relevante suiter for endringene, ikke en påstand om at hele appens øvrige testmengde eller alle mulige Skeleton-kombinasjoner er kjørt.

Testen for lang ubrutt tekst feilet i både VStack/HStack og begge bredder før CSS-rettingen; deretter bestod alle fire. Den virkelige kompakte remote-bridge-fixturen gikk fra `scrollWidth=604, clientWidth=358` til `358/358`. Navnet på fixturen innebærer ikke at den generelle fjernbroen virker.

## Dekningsmatrise

| Område | Schema/innhold | Native/web-visning | Handlinger og tilstand | Fortsatt grense |
| --- | --- | --- | --- | --- |
| 9 publiserte CellScaffold-fixtures | Opprinnelig JSON bevart; host-aliaser navngitt | Begge bredder kontrollert | 11 HTTP-tester; lokale rendererhandlinger separat | Ingen end-to-end generell native fjernlast |
| Alle 26 enum-typer | Korpus generert fra faktisk katalog + Tree/ComponentSurface | 52 opptak på hver renderer | Et utvalg direkte handlinger og relevante kontraktregresjoner | Ikke alle modifiers, kombinasjoner eller dynamiske tilstander |
| List/Grid/Reference | Riktige radverdier og kontekst | Faktiske bilder, kompakt/bred | Utvalg/oppdatering/statiske rader/autoritative nullverdier | Nye kombinasjoner må inn i regresjonskorpuset |
| ComponentSurface | To lokale montasjer, separat payload/kontekst | Riktig tekst og lokal root/item-arv | Ekte Resolver, aktiv requester, tillatt/nektet tilgang, to museklikk og normal URL | Kun lokale kilder; enkelte nested typer stoppes eksplisitt |
| Image/Spacer/Divider/ZStack | Gyldig Image; overlapping i original ZStack beholdt | Image-farger verifisert; Spacer/Divider visuelt opptak | Ikke interaktive | Tom tekstforventning er ikke innholdsbevis |
| Offentlig katalog | Alle 20 konfigurasjonsnavn dekodet | Ikke en gjennomklikk av alle 20 produktflater | Eksakte offentlige lesestier, private/skrivebaner avvist | Kode testet lokalt; staging ikke deployet |
| Mørkt tema/conference/arbitrær CSS/iOS | Uendret eller ikke dekket | Ikke sertifisert | Ikke sertifisert | Egen navngitt hostkontrakt og plattformkjøring kreves |

## Det som gjenstår før den opprinnelige påstanden kan bekreftes

1. **Sikker generell fjernbro:** CP53 er fortsatt åpen på kontrollert head `3824cf84b58903f900a49b0987ee660085f3d875`. AP5 serverintegrasjon og AP7 Binding-integrasjon er separate leveranser med eksisterende sikkerhetsporter. Den gamle anonyme `/bridgehead/...`-ruten gjenåpnes ikke. Sprout-onboarding og HMAC admin-transport er ikke universelle erstatninger. Se `TRANSPORT.md` og den eksisterende planen i `CellProtocolDocuments/Deliverables/PDD_bro-paa-i-prod_2026-09-26/`.
2. **Kildebevisste komponenter:** Adaptertestene beviser lokal dispatch og autorisasjon, ikke en komplett kildeabonnement→persistens→ny visning-arbeidsflyt. Reference, AttachmentField, FileUpload, NavigationBar og Visualization inne i en mounted scope beholder eksplisitt «source-aware host adapter»-diagnostikk. Lokal knappstøtte betyr ikke at disse virker gjennom en fjernkilde.
3. **Navigasjon og temakontrakt:** Relative URL-er krever en tillatt baseadresse; uten den er de utilgjengelige. Native dynamisk keypathKeypath-only NavigationBar er fortsatt en navngitt eksisterende grense.  Standard lyst Porthole-tema er testet. Plattformdetaljer i kontroller, fontmetrikk, skygger og andre CSS-klasser kan fortsatt avvike. Bilder kan gjennomgås i galleriet; pikselidentitet hevdes ikke.
4. **Levering til installert app/staging:** Kandidaten må inngå i koordinert CP-/klientrelease med riktige pinner og de ordinære portene. Ingen avhengighet er pinnet til en upublisert revisjon i produksjonsprosjektet, og den installerte appen er ikke erstattet.

## Kandidat og reproduksjon

Endelige lokale revisjoner:

| Repo | Commit |
| --- | --- |
| Binding | `b18e267d6e103c2bcb2ebda9f91215fc435861f2` |
| CellProtocol | `41139185b00e2abb7b6c28c212fc64140e60d083` |
| CellScaffold | `bdc9f8302691d8af7ee16e7f0fa659dddf500fac` |

Alle tre arbeidstrær er rene. Ingen push/PR eller deploy er utført.

Arbeidstrærne ligger i `workspaces/Binding`, `workspaces/CellProtocol` og `workspaces/CellScaffold`, på `codex/surface-parity-20260930`. De ble opprettet fra ferske origin/main-revisjoner; andres arbeid i de vanlige utsjekkene er bevart.

`Integration.xcworkspace` bygger Binding mot den eksplisitte lokale CellProtocol-kandidaten. Produksjonens CP-pin i Binding og CellScaffold er uendret. Appen er en usignert Debug-testkandidat i `/tmp/HAVEN-SurfaceParity-Integrated-20260930/Build/Products/Debug/HAVEN.app`.

`candidate-manifest.json` binder revisjoner, kilde-dirty-state, compiler inputs, lenket CellProtocol-artifakt og app-hash. Den første runden er bevart i `candidate-manifest-first.json`. Debug-bygget bruker en separat `HAVEN.debug.dylib`; manifestet hasher også den, siden launcher-hashen alene ikke identifiserer appkoden. Kommandoer og miljø er dokumentert i `PDD_surface-parity_2026-09-30/TESTRESULT.md` og repoets `Documentation/SkeletonParitySuite.md`.

## Læring og tidligere forsøk

Åtte læringer fra denne reparasjonsøkten er registrert, implementert i kanoniske ferdigheter og distribuert: originalpayload/NSHosting, offentlig katalogpolicy, bilde-/fulltype-orakler, native hit-target/felteditor, mounted actions, kontroller/geometri utover OCR Picker-meny/tilgjengelighet og faktisk Debug-dylib-proveniens. Falske testforventninger, før-bilder, mislykkede bygg og diskvaktens tidligere avslag beholdes som historikk; de er ikke sluttstatus. Diskvakten ble ikke omgått, og ingen opprydding ble utført.
