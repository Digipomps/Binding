# Co-Pilot Purpose/Interest Quality Report

Dato: 2026-06-29

## Sporsmaal

Hjelper det aa bruke aktivt formaal og interesser fra `PerspectiveCell` til aa gi
bedre Co-Pilot Chat-forslag i Binding?

Kort svar: ja, tydelig for tvetydige oppfoelgingsprompt der brukeren skriver
ting som "legg dette inn", "neste steg", "lagre dette" eller "koble dette".
Dette er nettopp prompt-typen der chatten ellers mangler nok tekstsignal til aa
velge trygg hjelper.

## Testet endring

Binding har allerede Co-Pilot-analyse som henter Perspective-summary og bygger
et lite `BindingChatPurposeContext` med:

- `purposeRefs`
- `interests`
- `weights`
- `source`

Den nye regresjonstesten
`purposeInterestContextQualityMatrixImprovesAmbiguousChatPrompts` maaler samme
prompt uten og med aktiv Purpose/Interest-context.

Testen dekker disse tvetydige promptene:

| Prompt | Aktiv context | Forventet hjelper | Forventet formaal |
| --- | --- | --- | --- |
| `legg dette inn` | project/planning | `project` | `personal.chat.assist.project` |
| `neste steg` | todo/task | `todo` | `personal.chat.assist.todo` |
| `lagre dette` | idea/capture/vault | `idea-capture` | `personal.chat.assist.idea.capture` |
| `koble dette` | graph/obsidian/vault | `resource-router` | `personal.knowledge.graph.index` |

## Maling

Deterministisk klassifisering gir denne kvalitetsporten:

| Metrikk | Uten Perspective | Med Perspective |
| --- | ---: | ---: |
| Eksakt helper+formaal-treff | 0/4 | 4/4 |
| Trygge forslag (`shouldSuggest`) | 0/4 | 4/4 |
| Snitt-confidence | 0.20 | 0.885 |
| Confidence-loeft | - | +0.685 |

Testen sjekker ogsaa at Perspective ikke overstyrer en eksplisitt negativ
brukerintensjon: `ikke lagre ide` med aktiv idea-context gir fortsatt ingen
forslag og `negativeIntent=idea_capture`.

## Testdrevne Funn

Foerste kjoering av matrisen fant to svakheter som ble rettet:

- graf/Obsidian-context med `vault` kunne bli tolket som generell idefangst
  fordi `vault` var et bredt ide-signal og ide ble vurdert foer graf.
- `ikke lagre ide` ble ikke fanget som negativ intensjon fordi negasjonsregelen
  kjente `ikke ide` og `ikke lag ide`, men ikke `ikke lagre ide`.

Klassifiseringen prioriterer naa graf/knowledge-graph/Obsidian som mer
spesifikk context enn generell vault/idefangst, og negasjonsregelen dekker
`ikke lagre`, `ikke opprett` og `ikke start`.

## Tolkning

Purpose/Interest-context gir en klar forbedring naar prompten er deiktisk eller
kontekstuell: "dette", "neste steg", "koble dette". Uten context er det riktig
at Binding ikke gjetter. Med aktiv context kan Co-Pilot velge en trygg hjelper
uten aa utfoere sideeffekter.

Dette forbedrer ikke alle chat-prompter. Klare prompter som "lag prosjektplan"
eller "legg til oppgave" skal fortsatt matches av deterministiske lokale regler.
RAG, agent og remote-provider skal fremdeles bare foreslaas naar prompt og grant
matcher riktig case.

## Sikkerhet Og CellProtocol

Perspective-context brukes bare som ranking-context. Det gir ikke nye grants,
leser ikke skjulte celler og skal ikke mutere Perspective under
`assistant.analyzeDraft`, `chatHub.prompt.submit` eller `ui.openSuggestedHelper`.

Sideeffektregelen staar fast:

- analyze kan foreslaa hjelper
- open-helper kan aapne sideeffektfri UI
- accept/confirm er eneste sted som kan opprette, lagre, sende eller spoerre
  ekstern ressurs

## Gjenstaaende Tuning

Neste kvalitetsloeft er aa utvide context-matrisen til flere aktive formaal:

- invite/personvalg
- poll/gruppedecision
- reminder/tid
- meeting/intensjon uten native kalenderlesing
- docs/RAG bare naar granted RAG-case finnes
- HAVENAgentD review/signering, aldri direkte kjoring

Det boer ogsaa legges en UI-metrikk paa toppen av chat-smoken: ingen synlig
`failure`, `denied`, `CellAuthorizationDecision` eller raw keypath i vanlig
Samtale/Aktivt-visning.
