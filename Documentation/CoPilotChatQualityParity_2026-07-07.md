# Co-Pilot Chat Quality Parity

Dato: 2026-07-07

## Spørsmål

Er Co-Pilot Chat i HAVEN/Binding like god som Co-Pilot Chat i CellScaffold til
å forstå prompt, finne riktig hjelper eller flate, og la negative prompt feile
trygt?

Kort svar etter dette passet: ja for den deterministiske prompt-fixturen og de
lokale provider-cellene Binding kan evaluere uten nettverk. Binding kjører nå
samme `personal_chat_prompt_evaluation.json` som CellScaffold, og den fokuserte
Binding-testen passerer for:

- deterministic/local-rules
- `cell:///AppleIntelligence`
- `cell:///LocalLLM`

Dette er ikke en live kvalitetsmåling av en ekte Foundation Models- eller
llama-runtime. Testen verifiserer Binding sin structured intentklassifisering,
provider-ruting og helper/resource-normalisering mot CellScaffold-kontrakten.

## Paneloppsett

Dette passet bruker panelkontrakten i
`Documentation/BindingAdvisorSpawnAndGUIQuality.md` som arbeidsramme. Panelet
skal lage promptvarianter og kritisere rutingen, ikke utføre sideeffekter.

| Rolle | Oppgave | Eksempel på promptvariant |
| --- | --- | --- |
| Prompt Variant Maker | Lage korte, naturlige og tvetydige prompt for samme mål | `Jeg har en idé til et prosjekt`, `lagre idé`, `ta dette videre som prosjekt` |
| CellProtocol Steward | Finne grant-, owner- og sideeffektbrudd | `Ikke registrer bug, jeg bare nevner at knappen feilet` |
| CellScaffold Parity Reviewer | Sikre at Binding bruker samme helper/resource-kontrakt | `Hva er lasten nå på staging scaffold?`, `Hva er lasten nå?` med single-scaffold context |
| UX Skeptic | Finne prompt der brukerforventning og UI kan divergere | `Fjern menyene i porthole`, `bruk GLM 5.2 Thinking og velg best passende modell` |

Rollenes output ble brukt til å kontrollere at fixturen dekker:

- Invite, poll, idea, todo, project, reminder, meeting og work item.
- Mermaid, docs/RAG, resource-router, Spatial Map, Obsidian/graph og
  CellConfiguration-authoring.
- Guided onboarding, questionnaire, AIGateway/provider-oppsett og GLM-valg.
- Admin/scaffold-observasjon med og uten nok kontekst.
- Porthole UI-kommandoer.
- Negative prompt som ikke skal åpne helper.

## Første funn

Binding hadde en stale lokal fixture på 386 linjer, mens CellScaffold sin
fixture er 1532 linjer. Det betydde at tidligere grønne tester ikke målte de
nyeste helperne og negative casene.

Da CellScaffold-fixturen ble speilet inn i Binding, feilet Binding først på 27
cases per lokal provider. Hovedgapene var:

- Guided onboarding og questionnaire.
- AIGateway, GLM 5.2 Thinking og provider-best-fit.
- CellConfiguration-authoring, personlige sider og Spatial Map.
- Admin/scaffold load og conference demo/story/resource-flater.
- Purpose/Interest docs og RAG som resource-match.
- Porthole menykommandoer.
- Negerte work-item/onboarding-prompt.

Etter første tuning sto fire paritetsbrudd igjen:

- `resource.admin-scaffold-load-staging.nb`
- `resource.admin-scaffold-load-context.nb`
- `porthole.remove-menus.nb`
- `no-work-item.negated.nb`

De ble fikset ved å gjøre admin-load-regelen kontekstavhengig, beholde
produktkrom når bare kantmenyer fjernes, og utvide negasjonsmønsteret for
`ikke registrer bug`.

## Hardt kvalitetssteg

Neste gate ble å gjøre Binding like streng som CellScaffold på grounded plan,
ikke bare på klassifisering. Provider-runneren sjekker nå `groundedPlan` for
intent, target endpoint, action keypath, helper, risikonivå, confirmation-krav
og `missing`-årsaker.

Dette avdekket et reelt paritetsgap: Binding brukte enkelte interne
`chatHub.*` action-aliaser i planen, lot vanlige hjelpere arve første
bakgrunnsressurs som target, og tolket `kundeverktøy` som Porthole fordi
`verktøy` var for bredt. Etter tuning:

- Helper-planer for invite/poll/idea/work item/todo/project/reminder/meeting,
  onboarding, capability request og agent review peker kanonisk mot
  `cell:///PersonalChatHub`.
- Resource-planer bruker canonical CellScaffold-action som
  `ui.openMatchedResourceLibrary`, `assistant.queryResource` og
  `book.openDocument`.
- RAG og CellProtocol Book får eksplisitt target metadata i Binding:
  `cell:///RAGGateway` / `RAG Gateway Workspace` og
  `cell:///MarkdownRenderer` / `CellProtocol Book`.
- Porthole UI-planer trigges ikke lenger av brede domeneord som
  `kundeverktøy`.
- Negative prompt skiller mellom eksplisitt "ikke gjør X" og trygge
  drøftingsprompt som "bare forklar hvilke spørsmål vi kunne stilt".

## Endringer

- `Tests/fixtures/personal_chat_prompt_evaluation.json` er speilet fra
  CellScaffold.
- `BindingChatIntentClassifier` dekker flere resource-flater og negative
  intent.
- Provider-evalueringen tar hensyn til `single-scaffold-context`.
- Scoped provider-listen inkluderer `nanogpt.glm-5.2-thinking` som
  owner-deklarert nettverksprovider, ikke global provider.
- Admin load skiller mellom eksplisitt `staging scaffold` og tvetydig
  `Hva er lasten nå?`.

## Måling

| Test | Resultat |
| --- | --- |
| Binding `ChatWorkbenchParityTests` | 37/37 pass |
| Binding provider fixture mot deterministic/local-rules | pass |
| Binding provider fixture mot AppleIntelligence-cell | pass |
| Binding provider fixture mot LocalLLM-cell | pass |
| CellScaffold deterministic prompt-suite | pass |
| Binding groundedPlan-paritet mot CellScaffold-fixture | pass |

Kommandoer:

```bash
Scripts/test_binding.sh CODE_SIGNING_ALLOWED=NO -only-testing:BindingTests/ChatWorkbenchParityTests
```

```bash
swift test --filter PersonalChatPromptEvaluationTests/testDeterministicPromptSuiteRoutesExpectedComponentsWithoutSideEffects
```

CellScaffold-kommandoen ble kjørt i
`/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold`.

## Paritet

| Område | Binding etter dette passet | CellScaffold baseline |
| --- | --- | --- |
| Fixture-corpus | Samme prompt-fixture | Canonical fixture |
| Positive helper-prompt | Pass | Pass |
| Negative prompt | Pass | Pass |
| Resource-router | Pass for fixture | Pass |
| Provider scope | Pass for deklarerte provider-celler | Pass |
| Sideeffektfri analyze/open | Dekket av eksisterende chat-paritetstester | Dekket av CellScaffold-testen |
| Live LLM/provider kvalitet | Ikke live-verifisert i denne testen | Ikke del av deterministic baseline |

## Gjenstående kvalitetsløft

- Kjør samme fixture mot ekte Apple Intelligence når Foundation Models runtime
  er tilgjengelig på testmaskinen.
- Kjør samme fixture mot en faktisk lokal llama/ggml-runtime når en liten modell
  er installert og godkjent for størrelse/lisens.
- Legg en liten "prompt fuzz" på toppen av panelet: 3-5 språklige varianter per
  helper-familie, med forventet helper eller forventet trygg feil.
- Hold fixture-sync eksplisitt: når CellScaffold utvider
  `personal_chat_prompt_evaluation.json`, skal Binding sin kopi oppdateres i
  samme endringspakke.
