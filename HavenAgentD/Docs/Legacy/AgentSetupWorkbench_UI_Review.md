# Agent Setup Workbench: Felt, Knapper og UX-vurdering

Legacy note:

- denne noten beskriver den gamle Binding-embedded workbenchen
- workbenchen er ikke lenger del av hovedproduktet `Binding`
- behold dokumentet kun som historisk UX-/implementasjonskontekst for agentarbeid under `HavenAgentD`

Denne noten beskriver hva `Agent Setup Workbench` i `Binding` faktisk inneholder per i dag, hva hvert tekstfelt og hver knapp gjør, og hva som bør strammes inn UX-messig.

Kildene for vurderingen er:
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/ConfigurationCatalogCell.swift`
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/AgentProvisioningCell.swift`
- `/Users/kjetil/Build/Digipomps/HAVEN/Binding/Cells/AgentEnrollmentCell.swift`

## Overordnet vurdering

Workbenchen er allerede godt strukturert som en lineær operatørflyt:

1. bind purpose
2. pek til lokal runtime
3. installer/start/connect
4. pair Binding og agent
5. se runtime-status
6. review remote intents
7. forklar topology/trust

Det er riktig retning. Den viktigste UX-svakheten nå er ikke mangel på informasjon, men at noen felt er for rå og tekniske for tidlig i flyten, mens andre felter mangler hjelpefunksjoner som gjør dem raske å bruke.

Den viktigste anbefalingen er:

- `Purpose name` bør få autocomplete med forslag fra tilgjengelige oppslag, men fortsatt tillate fri tekst.

## Hero / toppseksjon

### Visningsfelt

`Agent Setup Workbench`
- Tittel for workbenchen.

`Purpose first. CellProtocol always. ...`
- Forklarer styringsmodellen.

`agent.setup.status.purposeBinding`
- Viser nåværende binding som `purposeName -> purposeRef [source]`.
- Hensikt: bekrefte hva agenten faktisk er bundet til.

`agent.setup.status.portholeStrategy`
- Viser at agenten bruker ett lokalt kontroll-porthole, ikke ett per klient.
- Hensikt: gjøre arkitekturen eksplisitt.

`Install`, `Runtime`, `Bridge`
- Tre stage-kort som viser:
  - `agent.setup.status.installStage`
  - `agent.setup.status.runtimeStage`
  - `agent.setup.status.connectStage`

### Knapper

`Use active Perspective`
- Keypath: `agent.setup.syncFromPerspective`
- Leser `cell:///Perspective/activePurpose` og fyller:
  - `purposeName`
  - `purposeRef`
  - `goal`
  - `interests`
- Hensiktsmessig: ja, dette er riktig primærinngang.

`Refresh`
- Keypath: `agent.setup.refresh`
- Leser lokal state på nytt og oppdaterer workbenchen.
- Hensiktsmessig: ja.

`Mac ops`
- Keypath: `agent.setup.selectPreset`
- Setter et preset for lokal agentdrift.

`File intake`
- Keypath: `agent.setup.selectPreset`
- Setter et preset for mappe-/filflyt.

`Research companion`
- Keypath: `agent.setup.selectPreset`
- Setter et preset for forsknings-/kontekstbruk.

### Vurdering

- Heroen gjør riktig jobb.
- Stage-kortene får passe plass.
- Preset-knappene er nyttige, men de er litt løsrevet fra purpose-feltene under.

Anbefaling:
- behold preset-knappene
- la valg av preset tydelig markere at purpose-feltene ble oppdatert
- vurder å vise valgt preset eller `source` som egen chip

## 1. Bind to purpose

### Tekstfelter

`Purpose name`
- Keypath: `agent.setup.purpose.name`
- Innhold: menneskelig navn for purpose.
- Nåværende oppførsel:
  - skriver bruker her, settes `purposeSource = "Manual draft"`
  - hvis `purposeRef` er tom eller fortsatt default, genereres en slugget `purpose://...` automatisk
- Vurdering:
  - veldig viktig felt
  - bør få mer hjelp enn et nakent tekstfelt

`purpose://portable-ref`
- Keypath: `agent.setup.purpose.ref`
- Innhold: portabel purpose-ref som agent, sprout og scaffold bruker videre.
- Nåværende oppførsel:
  - kan redigeres manuelt
  - overstyres ikke hvis bruker allerede har satt en egen verdi
- Vurdering:
  - riktig å ha dette tilgjengelig
  - men for prominent for nye brukere

`Goal / operating intent`
- Keypath: `agent.setup.purpose.goal`
- Innhold: setning eller kort beskrivelse av hva agenten skal gjøre.
- Nåværende oppførsel:
  - ren tekststreng
  - fylles automatisk av `Use active Perspective` eller preset
- Vurdering:
  - feltet er riktig
  - dagens single-line tekstfelt er for trangt

`interest-1, interest-2, interest-3`
- Keypath: `agent.setup.purpose.interests`
- Innhold: interesseord som brukes videre i starter-auth og bootstrap.
- Nåværende oppførsel:
  - håndteres som kommaseparert tekst
  - fylles av Perspective eller preset
- Vurdering:
  - riktig data
  - feil input-modell for vanlig bruk

### Liste

`cell:///Perspective/activePurpose.purposes`
- Viser aktive purposes fra `Perspective`.
- Viser:
  - `purposeName`
  - `portablePurposeRef`
  - `purposeWeight`
- Vurdering:
  - riktig å vise dette
  - men den er i praksis bare informativ nå
  - den burde være selekterbar eller kunne brukes som forslag direkte

### Vurdering av plass

- Seksjonen har riktig mengde vertikal plass.
- `Purpose name` og `Goal` burde få mest plass.
- `Purpose ref` og `Interests` trenger mindre visuell tyngde enn i dag.

### Anbefalt forbedring

#### `Purpose name` bør få autocomplete

Ja. Dette er den viktigste konkrete UX-forbedringen.

Autocomplete bør:
- hente forslag fra `cell:///Perspective/activePurpose.purposes`
- gjerne også fra nylig brukte lokale purpose-utkast senere
- la brukeren skrive fri tekst uten å tvinge valg fra listen
- ha en eksplisitt fallback som betyr `bruk akkurat det jeg skrev`

Når bruker velger forslag bør workbenchen fylle:
- `purposeName`
- `purposeRef`
- `goal` hvis tilgjengelig eller generert
- `interests` hvis tilgjengelig

Anbefalt UX-mønster:
- kombinasjon av tekstfelt og forslag under feltet
- ikke ren dropdown
- ikke hard binding til eksisterende oppslag

#### Andre anbefalinger

`Purpose ref`
- behold som redigerbart felt
- men plasser det som sekundær detalj under `Purpose name`
- gjerne med forklaring som `auto-generated, can be overridden`

`Goal`
- bør bli `TextArea`, ikke `TextField`
- minst 3-4 linjer synlig høyde

`Interests`
- bør bli tag-/chip-editor
- forslag bør kunne komme fra Perspective-oppslag
- fri tekst må fortsatt være mulig

## 2. Point to local runtime

### Tekstfelter

`staging.haven.digipomps.org`
- Keypath: `agent.setup.status.domain`
- Innhold: scaffold-domene.
- Vurdering:
  - viktig felt
  - burde få miljøforslag som `staging`, `dev`, eventuelt `local`

`/path/to/Binding`
- Keypath: `agent.setup.environment.sourceRoot`
- Innhold: workspace-root som brukes for å finne agentpakken og install-assets.
- Vurdering:
  - teknisk nødvendig i dev
  - for teknisk for førstegangsbruk

`/absolute/path/to/sprout`
- Keypath: `agent.setup.environment.sproutBinaryPath`
- Innhold: sti til `sprout`-binær.
- Vurdering:
  - teknisk og viktig i utvikling
  - bør ikke ligge like høyt i hovedflyten for vanlige brukere

### Statusfelt

`binaryState`
- om agent-binæren finnes/bare er klargjort

`configState`
- om config er skrevet

`launchAgentState`
- om LaunchAgent finnes/er lastet

`sproutState`
- om `sprout`-banen/configen ser gyldig ut

`controlBridgeState`
- live-status for lokal CellProtocol-bro

`controlBridgeEndpoint`
- websocket-endpoint for loopback-broen

### Vurdering av plass

- Domene-feltet får passe plass.
- `sourceRoot` og `sproutBinaryPath` tar for mye plass i hovedløpet.
- Statuslinjene er nyttige, men kunne grupperes tydeligere.

### Anbefalt forbedring

- gjør `sourceRoot` og `sproutBinaryPath` til en `Advanced`-seksjon som er åpen i dev-modus og kollapset ellers
- gjør `domain` til combo/segmented input med:
  - `staging`
  - `dev`
  - `custom`

## 3. Install, start, connect

### Knapper

`Install agent`
- Keypath: `agent.setup.install`
- Gjør:
  - bygger `haven-agentd` via `xcrun swift build --product haven-agentd`
  - kopierer binæren til install-lokasjon
- Vurdering:
  - label er riktig

`Start LaunchAgent`
- Keypath: `agent.setup.start`
- Gjør:
  - `launchctl bootstrap` eller `kickstart`
- Vurdering:
  - label er riktig

`Connect purpose`
- Keypath: `agent.setup.connect`
- Gjør:
  - kjører installert binær med `run --config ... --once`
- Vurdering:
  - funksjonen er riktig
  - label er litt misvisende
  - dette er mer en `one-shot connect/bootstrap` enn en varig tilkoblingsmodus

`Stop`
- Keypath: `agent.setup.stop`
- Gjør:
  - `launchctl bootout`
- Vurdering:
  - riktig sekundær handling

`Open Perspective`
- åpner Perspective-workbench i porthole

`Open Porthole control`
- åpner Porthole-workbench i porthole

### Lister og status

`Install pipeline`
- Liste: `agent.setup.pipeline`
- Viser steg, status og detaljer for provisioning-/installasjonsløpet

### Vurdering av plass

- Primærknappene får riktig plass.
- `Open Perspective` og `Open Porthole control` tar litt for mye plass i samme seksjon som install/start/connect.
- Pipeline-listen på høyde `212` er grei når den har innhold, men tung når den er tom.

### Anbefalt forbedring

- behold `Install agent`, `Start LaunchAgent`, `Stop`
- vurder å rename `Connect purpose` til:
  - `Run connect now`
  - eller `Bootstrap now`
- flytt `Open Perspective` og `Open Porthole control` til en mindre hjelpelinje eller sekundær meny

## 4. Pair Binding and agent identity

### Knapper

`Create pairing artifact`
- Keypath: `enrollment.createPairingArtifact`
- Gjør mer enn labelen antyder:
  - henter live agentidentitet over lokal CellProtocol-bro
  - ber agenten attestere identiteten
  - lar Binding signere approval
  - skriver pairing artifact
  - ber agenten utstede `starter-auth`
  - ber agenten countersigne `entity-link`
- Vurdering:
  - funksjonelt riktig
  - label er for svak i forhold til alt som faktisk skjer

`Refresh pairing`
- Keypath: `enrollment.refresh`
- Leser pairing-/starter-auth-/entity-link-state på nytt

### Visningsfelt

Seksjonen viser:
- pairing summary
- verification status
- agent identity status
- agent display name / DID
- operator display name / DID
- purpose ref
- scaffold domain
- artifact path
- starter-auth status, path og expiry
- entity-link status, contract id og path
- last recorded at
- last error

### Vurdering av plass

- Seksjonen gir for mye lavnivådetalj i hovedløpet.
- Filstier og contract IDs tar mye vertikal plass og er ikke førsteprioritet for de fleste.
- Seksjonen er riktig innholdsmessig, men for ekspandert som default.

### Anbefalt forbedring

- behold summary, verification status og identitetsoversikt synlig
- flytt disse til en kollapsbar `Technical details`:
  - artifact path
  - starter-auth path
  - entity-link path
  - contract ID
  - timestamps
  - rå siste feil

Mulig label-forbedring:
- `Pair and issue bootstrap evidence`

## 5. Runtime and bridge state

### Visningsfelt

Seksjonen viser:
- kontrollbro-status
- kontrollbro-endpoint
- aktiv kontrakt-ID
- siste heartbeat
- siste event-oppsummering
- siste feil
- aktivitetsliste

### Vurdering

- Dette er riktig operatørinformasjon.
- Seksjonen er hensiktsmessig.
- Aktivitetslisten får litt mye plass når den er tom, men fungerer ellers bra.

### Anbefalt forbedring

- behold seksjonen stort sett som den er
- vis tom-tilstand mer kompakt
- vurder fargekoder eller signalchips for `healthy`, `degraded`, `stopped`

## 6. Review remote intents

### Tekstfelt

`Optional operator note for approve/reject`
- Keypath: `agent.setup.review.noteDraft`
- Innhold: frivillig kommentar som tas med i audit.
- Vurdering:
  - riktig felt
  - passe størrelse

### Knapper

`Approve selected`
- Keypath: `agent.setup.review.approveSelected`
- Godkjenner valgt intent via review-cellen og kjører lokal dispatch hvis policy tillater det.

`Reject selected`
- Keypath: `agent.setup.review.rejectSelected`
- Avviser valgt intent og skriver audit.

### Lister og status

`pendingIntentList`
- Liste over ventende verified intents
- single-selection
- selection sender `id` til `agent.setup.review.selection`

`auditList`
- viser review-audit i revers rekkefølge

### Vurdering av plass

- Pending-listen trenger plassen.
- Audit-listen får litt for mye plass når den ligger rett under pending-listen i samme seksjon.
- Kombinasjonen av note, knapper, pending-liste og audit-liste gir seksjonen mye vertikal tyngde.

### Anbefalt forbedring

- behold pending-listen som primærflate
- gjør audit-listen kollapsbar eller tabbet
- eventuelt:
  - `Pending`
  - `Audit`

## 7. Topology and trust model

### Innhold

Tre tekstlinjer forklarer:
- CellProtocol first
- one operator porthole
- reviewed effects only

### Vurdering

- Innholdet er riktig og viktig.
- Men som permanent stor seksjon nederst er det litt for statisk.

### Anbefalt forbedring

- gjør dette til en kompakt info-boks eller `Why this setup?`
- behold teksten, men gi den mindre høyde i standardvisningen

## Samlet vurdering av plassbruk

### Får for lite plass

`Purpose name`
- trenger forslag/autocomplete og mer tydelig primærrolle

`Goal`
- trenger multiline input

`Interests`
- trenger chip/tag-editor i stedet for rå tekst

### Får passe plass

Hero-seksjon
- stage-kort og preset-knapper fungerer

Runtime-seksjon
- informasjonsnivået er riktig

Review note + approve/reject
- god størrelse

### Får for mye plass

`sourceRoot` og `sproutBinaryPath`
- for tekniske i hovedflyten

Enrollment-detaljer
- spesielt filstier og tekniske metadata

Audit-listen
- tar mye vertikal plass under pending-listen

Policy-/topology-seksjonen
- viktig, men bør komprimeres

## Konkrete anbefalinger i prioritert rekkefølge

### P1

Legg til autocomplete på `Purpose name`
- forslag fra `Perspective/activePurpose.purposes`
- fri tekst må fortsatt være mulig
- valg av forslag bør fylle `purposeRef`, `goal` og `interests`

Gjør `Goal` til multiline input

Bytt `Interests` fra kommaseparert tekst til chip/tag-input

### P2

Gjør `sourceRoot` og `sproutBinaryPath` til avanserte felt

Gjør `activePurposeList` interaktiv
- klikk på rad bør kunne fylle purpose-feltene

Komprimer enrollment-seksjonen
- summary synlig
- tekniske detaljer bak ekspanderbar blokk

### P3

Gi `domain` forslag/presets
- `staging`
- `dev`
- `custom`

Komprimer audit til sekundær visning eller egen fane

Rename `Connect purpose`
- dagens label beskriver ikke helt at dette er en eksplisitt one-shot connect/bootstrap-handling

## Anbefalt fremtidig inputmodell for purpose

Den beste modellen er:

1. `Purpose name` som primært felt
2. inline autocomplete under feltet
3. valg fra forslag oppdaterer resten av purpose-blokken
4. bruker kan ignorere forslag og skrive fritt
5. `Purpose ref` auto-genereres, men kan overstyres manuelt

Dette gir lav friksjon uten å bryte med HAVEN/CellProtocol-modellen:
- oppslag kommer fra tilgjengelige celler
- operatøren kan fortsatt definere noe nytt
- systemet tvinger ikke brukeren inn i et lukket katalogvalg

## Kort konklusjon

Workbenchen er strukturelt riktig, men den neste klare forbedringen er å gjøre purpose-delen mer hjelpsom og mindre rå. Hvis bare én ting skal bygges først, bør det være autocomplete og forslag for `Purpose name`, med fri tekst som fullverdig fallback.
