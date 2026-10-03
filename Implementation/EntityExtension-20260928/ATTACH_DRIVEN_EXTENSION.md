# Entitetsutvidelse ved attach/Absorb

Designpresisering fra Kjetil, 2026-09-28. Dette er en konkret integrasjonskontrakt,
ikke en påstand om at automatisk utvidelse allerede er implementert.

## Produktregelen

Når brukeren tar i bruk en celle i et annet scaffold, kan den samme handlingen
starte entitetsutvidelsen. Dersom verten støtter funksjonen, eierskapet er
verifisert og brukerens policy dekker utvidelsen, fullføres den uten en ekstra
QR-runde. Ellers spør appen i konteksten der brukeren allerede arbeider.

Forslag til spørsmål, med faktiske navn på begge sider:

> Bruke entiteten du har på «Hjemme» også i «HAVEN på telefonen»?

Valg: «Denne gangen», «Automatisk på dette stedet» og «Ikke nå». En lagret policy
må være avgrenset til riktig entitet, identiteter, domener og betrodd mottaker.
Ved automatisk fullføring vises en kort kvittering og hvor tilgangen kan
administreres. Ved avslag beholdes den cellerettigheten brukeren allerede hadde.

Det er menneskets representasjon og muligheter som utvides. Scaffoldene lenkes
ikke til hverandre som én sikkerhetsidentitet.

## Hva eierskapet beviser

En celle med en verifisert, gjeldende eierrelasjon er en god inngang til beviset.
Den som opererer cellen må samtidig bevise kontroll over den identiteten som
står som eier, eller over en allerede verifisert samme-entitet-identitet i det
aktuelle domenet. Et tidligere skapelsestidspunkt erstatter ikke dagens
rettighet etter overføring eller tilbakekalling.

Følgende er ikke tilstrekkelig: URL-en, en kopi av cellen, et offentlig owner-felt,
en UUID, tilgang til vertens database eller en vellykket vanlig lesing. En celle
kan deles via en avtale uten at mottakeren eier den. En person kan dessuten ha
rett til å bruke organisasjonens eller agentens identitet uten at disse skal
slås sammen med personens egen entitet.

Identitetens eksisterende tilhørighet til riktig entitet må komme fra brukerens
betrodde, aktive identitetskontekst eller en gyldig verifisert kobling. Den skal
ikke utledes fra et vilkårlig fjernscaffolds påstand om et globalt person-ID.

## To gjennomføringsveier

1. **Samme identitet eller allerede gyldig samme-entitet-kobling:** Etter brukerens
   policy kan verten registrere eller oppdatere entitetens tilstedeværelse og
   tilgjengelige funksjoner. Ingen ny identitetskobling er nødvendig. Eksisterende
   nøkkel kan signere over broen; privat nøkkel skal ikke kopieres til verten.
2. **Ny lokal identitet skal inn i entiteten:** Attach-handlingen starter den
   eksisterende signerte enrollment/completion-flyten. Den eksisterende
   eieridentiteten godkjenner den nøyaktige nye identiteten, og den nye identiteten
   beviser egen nøkkelkontroll. Policyen kan autorisere disse nye signeringene
   automatisk. Den kan ikke gjøre et gammelt Absorb-signaturbevis om til en
   enrollment-signatur eller omgå påkrevd fersk autentisering.

I dagens CellProtocol kan `same_entity` med godkjent domene gi den nye nøkkelen
**eieradgang** gjennom GeneralCell. Dette er derfor en policy for identitetsutvidelse,
ikke bare en innstilling for å åpne en celle. Dersom brukeren bare ønsker tilgang
til akkurat én celle, skal vanlig avtalebasert tilgang brukes. Vi skal ikke love
celleavgrenset same-entity-adgang som dagens resolver ikke håndhever.

## Integrasjonsrekkefølge

1. Ta imot en brukerinitiert attach eller en gjenopptakelse som er dekket av
   eksisterende policy. Bakgrunnsdiscovery, en forhåndsvisning eller offentlig
   Absorb skal ikke alene skape en ny koblingshandling eller gjentatte spørsmål.
2. Gjennomfør ordinær resolver-autorisering. Klassifiser den konkrete
   per-operasjon-beslutningen: direkte eierbevis, verifisert linked-owner-bevis,
   signert avtale, cellespesifikk adgang eller avslag. Bare de to eierveiene er
   kandidater til denne automatiseringen. Debug bypass er aldri eierbevis.
3. Bind kandidaten til aktuell celle, eiernøkkel, lokal identitet, domene,
   autentisert mottaker, operasjon og formål. En generisk «sist godkjent»-logg eller
   klientinnsendt JSON med `allowed: true` er ikke autorisasjonsbevis.
4. Kontroller aktuell eierrelasjon, eventuelle koblingers status og vertens
   faktiske enrollment/lagringsfunksjoner. Discovery annonserer bare muligheter.
5. Evaluer eierens aktive policy: spør, automatisk innenfor uttrykkelig policy,
   eller aldri. Bind en automatisk tillatelse til policyversjon og avgrensning;
   «alltid her» må ikke følge et vertsnavn til en annen nøkkel eller konto.
6. Bruk veien over for eksisterende eller ny identitet. Ved ny identitet signeres
   nye, kortlivede, formålsbundne forespørsler med nonce, audience, origin,
   nøkkelfingeravtrykk og godkjente domener/scopes. Dagens generelle eierchallenge
   skal fortsatt bare bevise den handlingen den er skrevet for.
7. Aktiver først etter verifisert, varig fullføring gjennom eksisterende
   IdentityLink/EntityAnchor-mekanisme. Gjenopptakelse må bruke samme operasjons-ID
   og bevis slik at restart, timeout og gjentatt Absorb ikke gir ekstra koblinger.
8. Rapporter nøyaktig hva som er fullført og hva som eventuelt venter på lokal
   eller fjern bekreftelse. Eksisterende avslag og tilbakekalling gjelder fortsatt.

Policyen kan etterpå utløse en separat, autorisert plan for data, indekser og
varsling. Eierskapskobling alene bestiller ikke kopiering, lagring, offentliggjøring,
indeksering eller APNs/Web Push-abonnement på alle tilgjengelige verter.

## Plassering av ansvar

**CellProtocol-forslag:** en per-operasjon-kvittering for verifisert eieradgang,
policykontrakt for automatisert entitetsutvidelse, idempotent kobling til dagens
completion-mekanisme og gjenbrukbare tillatelses-/avslagstester. Kvitteringen må
utstedes gjennom den betrodde autorisasjonsveien og ha avgrenset formål; den skal
ikke være en ny generell bearer-capability eller eksponeres offentlig.

**Scaffold/app:** attach-trigger, tilgjengelighetsdeteksjon, brukerens policy-UI,
OS/vault-signering og statusvisning. Automatikk plasseres i en eksplisitt
koordinator etter vellykket autorisasjon, ikke som skjult autoritetsendring i
hver Absorb, i transporten eller i rendererens UI-kode.

**QR/Nearby:** alternativer for oppstart når den eksisterende celleforbindelsen
ikke gir en brukbar, autentisert vei til de involverte identitetene. De er ikke
obligatoriske når attach-flyten allerede har de nødvendige bevisene.

## Akseptansekriterier før implementasjonen kan kalles ferdig

| Tilfelle | Forventet resultat |
| --- | --- |
| Eierbevis, støttet vert, gyldig autopolicy | Automatisk verifisert fullføring, én kvittering |
| Eierbevis uten autopolicy | Ett forståelig spørsmål før ny autoritet aktiveres |
| Samme nøkkel eller eksisterende gyldig kobling | Idempotent tilstedeværelse; ingen ny enrollment |
| Kun avtalt lese-/skrivetilgang | Vanlig celletilgang; ingen automatisk identitetskobling |
| Kopiert owner-UUID, annen nøkkel, debug bypass | Ingen utvidelse |
| Tilbakekalt/utløpt kobling eller flyttet eierskap | Ny vurdering; ingen automatisk gjenaktivering |
| Agent-/organisasjonsrolle uten personkoblingsmyndighet | Ingen implisitt sammenslåing med mennesket |
| Annet domene, mottakernøkkel, scope eller policyversjon | Avslag eller ny eksplisitt vurdering |
| Replay, restart, dobbelt attach, to samtidige scaffolds | Én logisk fullføring; ingen ekstra autoritet |
| Påkrevd fersk autentisering eller låst vault | Be om nødvendig autentisering; ingen policy-bypass |
| Ustøttet/offline vert, avbryt, timeout | Behold eksisterende celletilgang; ærlig ventende/avvist status |
| Ingen storage-/delings-/varslingsautorisasjon | Ingen automatisk dataflytting eller pushregistrering |

## Kildegrunnlag

Lest fra CellProtocol lokal `origin/main` på
`81601a6f835252aba7e99d43786fb5d67227c245`:

- `Sources/CellBase/Cells/GeneralCell/CellAuthorization.swift`: ulike beslutningsveier,
  eiernøkkelkontroll og avslag på UUID/nøkkel-mismatch.
- `Sources/CellBase/Cells/GeneralCell/GeneralCell.swift:2030`: direkte eller allerede
  lenket eierbevis; ny signaturkontroll mot den aktuelle betrodde nøkkelen.
- Samme fil, `checkIdentityOrigin` rundt 2253: challenge bundet til celle, domene,
  handlingen `checkIdentityOrigin`, audience `GeneralCell` og nonce.
- `Sources/CellBase/Cells/Bridging/BridgeIdentityProofAuthorization.swift:73`:
  broens signeringsautorisasjon godtar denne handlingen/audience innenfor en
  aktiv operasjonslease. Dette er ikke en generell signeringsfullmakt.
- `Sources/CellBase/Identity/IdentityLinkRegistry.swift:98`: eksakt nøkkel,
  `same_entity`, godkjent domene og lokal anchor-binding.
- `Sources/CellBase/Identity/IdentityLinkCompletion.swift`: separat signert
  request/approval/presentation/fullføring.
- `Tests/CellBaseTests/BridgeIdentityBoundaryTests.swift`: gjest oppretter og leser
  egen celle; verten og kopiert offentlig eieridentitet avvises.

Ingen runtime-endring eller nye testkjøringer er utført for denne presiseringen.
Den eldre uverifiserte flyten forblir sperret i sikkerhetskandidaten.
