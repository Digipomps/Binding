# Butlerflaten: formålsanalyse før integrasjon

Dato: 2026-08-05

Status: analyse med simulerte formål og en beslutning. Menneskelig
beslutningseier: Kjetil.

Bakgrunn: den lokale committen `0623b816` «Harden Binding co-pilot runtime
parity» ble integrert mot main i
`codex/apple-purpose-claim-pipelines-20260805`. Butlerdelen ble ikke landet
der, med begrunnelsen at main hadde skrevet om `BindingPersonalChatHubCell`.
Dette dokumentet undersøker hva som faktisk manglet, og bruker formål til å
avgjøre hva som skal bygges.

## Kildegrunnlag

| Påstand | Status | Bevis |
| --- | --- | --- |
| Main mangler sju proactivity-nøkler og fem sync-nøkler i butler-tilstanden | retrieved | `git show origin/main:Binding/ChatWorkbenchParityCells.swift` mot `0623b816`, ac9778e2 |
| Main mangler `butler.trigger.run` og `butler.sync.*` som handlinger | retrieved | samme, handlings-switchen på linje 4870–5000 |
| `BindingPersonalButlerPolicy` er landet i branchen, ikke i main | retrieved | `grep -c "static func configuringSync"` → 5 i branchen, 0 i main |
| Mains hub delegerer allerede til den landede policyen | retrieved | `configureButlerProactivity` → `BindingPersonalButlerPolicy.configuringProactivity` |
| Den landede lifecycle-modifieren kaller en keypath main ikke har | retrieved | `PersonalButlerLifecycle.swift:122` mot mains switch |

Det siste funnet er alvorlig og var ikke kjent da butlerdelen ble utsatt:
oppvåkningsveien som ble landet pekte på `chatHub.butler.trigger.run`, som
ikke finnes i main. Butleren ville aldri våknet.

## Formål vurdert

Tre formål ble formulert og simulert før noe ble bygget. «Simulert» betyr
her: hva ville dette formålet produsert av arbeid, og hva ville gjort det
etterprøvbart?

### F-B1: Butleren våkner bare på en trigger eieren har slått på

**Goal:** ingen oppvåkningsvei når PersonalChatHub uten å passere
`BindingPersonalButlerPolicy`. Målbart: en oppvåkning med `app_launch` gir
`offer` når eieren har slått det på, og ikke-`offer` når hen har slått det av.

**Simulering.** To veier gir samme utfall:

1. legg `butler.trigger.run` inn i mains switch
2. pek lifecycle mot `butler.support.consider`, som main allerede har

Den lokale committen viste seg å implementere `butler.trigger.run` som
`return considerButlerSupport(value)` — samme funksjon. Vei 1 ville altså lagt
til en keypath som er et alias for en eksisterende. Vei 2 gir samme oppførsel
uten ny flate å autorisere og revidere. Den landede policyen tar allerede
imot `triggerKind` som synonym for `signalKind` og kjenner `app_launch`,
`user_schedule`, `periodic_check_in` og `task_completed`.

**Valgt: vei 2.** Én linje, pluss en test som viser at oppvåkningen når
policyen og at policyen — ikke oppvåkningen — bestemmer utfallet.

### F-B2: Eieren skal kunne sette når butleren får våkne, fra chatflaten

**Goal:** eieren kan endre proaktivitetsplan fra flaten og se den igjen.

**Simulering.** Formålet krevde tilsynelatende sju nye tilstandsnøkler og et
tekstfelt i katalogen. Undersøkelsen viste at mains
`butler.proactivity.configure` sender verdien rett til den landede policyen,
som allerede definerer `userScheduleEnabled`, `userScheduleLocalTime`,
`appLaunchEnabled` og `minimumIntervalHours`. Katalogen på main eksponerer
allerede knappene, og mains egen test
`personalCopilotSkeletonExposesButlerProfileProactivityAndCapabilityControls`
holder den flaten fast.

**Ikke valgt.** Garantien formålet ber om er allerede oppfylt. Det som gjensto
var et fritekstfelt for klokkeslett — en UX-forbedring, ikke et hull. Å bygge
det her ville vært å utføre et formål som allerede er nådd.

### F-B3: Preferanser krysser enheter bare med godkjenning på begge og signatur

**Goal:** en preferanseimport skjer bare når begge enheter har godkjent,
signaturen er verifisert, og den samme importen kan ikke tas inn to ganger.

**Simulering.** Policylaget for dette — `configuringSync`,
`updatingSyncTarget`, `preferenceSyncPayload`, `applyingSyncedPreferences`,
`recordingSyncExport` — er allerede landet, men ingen handling kaller det.
Det er død kode i binæren. Å gjøre det tilgjengelig krever fem
handlingsnøkler og tilhørende tilstandsnøkler i huben.

Dette er samme mønster som Apple-portene: et bibliotek uten kobling oppfyller
ikke sitt eget formål. Forskjellen er at dette er en **innkommende datavei**
mellom enheter, altså nøyaktig den typen flate som herdingen i main handlet
om.

**Valgt, men som egen leveranse.** Den skal ha sin egen gjennomgang, ikke
smugles inn i en PR om Apple-formålsporten.

## Beslutning

| Formål | Utfall | Begrunnelse |
| --- | --- | --- |
| F-B1 | bygget nå | reparerer en oppvåkningsvei som allerede var landet og gikk til ingenting |
| F-B2 | ikke bygget | garantien er allerede oppfylt av main pluss den landede policyen |
| F-B3 | egen PR | ekte hull, men innkommende datavei fortjener egen gjennomgang |

## Hva analysen lærte oss om metoden

Formålet var nyttig på en annen måte enn i konfliktrunden. Der avgjorde det
*hvilken side som vant*. Her avgjorde det *om arbeidet skulle utføres i det
hele tatt*: to av tre formål endte med at det riktige var å bygge noe helt
annet enn det som så ut til å mangle, eller ingenting.

Tre observasjoner verdt å ta med videre:

1. **Simuler formålet før du bygger det.** F-B2 så ut som sju manglende
   nøkler og endte som null linjer kode. Kostnaden ved å simulere var to
   grep-kommandoer.
2. **Et alias er ikke en manglende funksjon.** F-B1 så ut som en manglende
   handling i huben. Den var en peker til en handling som allerede fantes.
   Å legge den til ville økt flaten som må autoriseres, uten ny evne.
3. **Landet bibliotek uten kobling er et uoppfylt formål, ikke et halvferdig
   et.** Det gjelder både Apple-portene og sync-halvdelen av butlerpolicyen.
   Målet «finnes i binæren» er ikke det samme som «kan brukes og etterprøves».
