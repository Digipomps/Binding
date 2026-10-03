# Nearby Purpose Bridge — to-enhets akseptansesjekkliste

Dato: 2026-08-21  
Status: Ikke utført; krever to fysiske Apple-enheter i samme rom.

## Forutsetninger

- Begge enheter kjører samme lokale CellProtocol/Binding-revisjon.
- Bluetooth og lokalt nettverk er tillatt på begge enheter.
- Begge testidentiteter har minst ett aktivt Perspective-formål med samme portable referanse.
- Ingen beacon-referanser er forhåndsvalgt.

## Sjekkliste

- [ ] Start med strict policy på begge enheter. Bekreft at discoveryInfo ikke har `pt`, `it` eller `c`.
- [ ] På enhet A: velg eksplisitt minst ett formål/interesse, bekreft advarselen og godkjenn beacon.
- [ ] På enhet B: gjør tilsvarende med minst én overlappende portable referanse.
- [ ] Før noen tilkobling: bekreft at B vises i A sin radar med riktig entitetstype og `beaconOverlapCount > 0`.
- [ ] Bekreft at radarvisningen merker treffet som et uverifisert beacon-hint, ikke identitet, tillit, kontakt eller avtale.
- [ ] Send en transportinvitasjon fra A. Bekreft at B ikke auto-aksepterer og viser eksplisitte valg for godkjenning og avvisning.
- [ ] Avvis på B. Bekreft at A og B ikke står igjen med en tilkoblet eller halvåpen sesjon.
- [ ] Send invitasjonen på nytt og godkjenn på B. Bekreft at bare den valgte peer-en blir tilkoblet.
- [ ] Bekreft at aggregert probe skjer etter godkjent transport og bare viser score/bøtter, aldri klare referanser.
- [ ] Be om detaljert probe. Bekreft at B må godkjenne separat før klare referanser sendes.
- [ ] Koble til en tredje enhet samtidig. Bekreft at meldinger, brotilstand og resultater ikke blandes mellom peers.
- [ ] Stopp scanning. Bekreft at broer, nonces og probe-resultater tømmes.
- [ ] Sett eller simuler utløpt beacon-policy. Bekreft at beacon og scanning stoppes og at ny eksplisitt godkjenning kreves.

## Målinger som allerede er gjort automatisk

- En realistisk policy med 8 formål, 8 interesser, konteksttoken og 36-tegns sesjons-UUID blir deterministisk begrenset til 6+6 tokens og måler **175 Bonjour TXT-byte** når både `=` og lengdeoktetten for hvert nøkkel/verdi-par regnes med. Dette er under prosjektets konservative 200-byte-grense.
- Enhetstester dekker token/slug-determinisme, ukjent versjon, overlapp, policy/utløp, eksplisitt invitasjon/timeout, probe-orakelmotstand, replay/duplikat, payload-grense og lovlige/ulovlige peer-overganger.

## Faktiske to-enhetsmålinger

Ikke tilgjengelig i denne arbeidsøkten. Fyll inn enhetsmodeller, OS-versjoner, faktisk observert pre-connect-overlapp, invitasjonsutfall og eventuelle avvik når sjekklisten kjøres.
