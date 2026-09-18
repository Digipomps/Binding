# Relasjoner i min egen entitet — implementasjon 2026-08-30

Forrige runde (20.–21.08) ga oss et relasjonslager på enheten, import fra fil
og adressebok, signerte invitasjoner og en projeksjon av interesser inn i
Perspective. Denne runden svarer på bestillingen «slå opp Vegar, la HAVEN finne
ut hvordan en chat best startes, og la det gjelde alle — fra den flaten og
enheten jeg bruker, med relasjonen, når den oppsto, hvordan vi har interagert,
bevis på kontakt, og interaksjonene i chronicle».

Tre repoer, i denne rekkefølgen: CellProtocol (modellen), Binding (bruken),
CellScaffold (oppgavekø — ikke rørt).

## Beslutninger

**Relasjonen og adressen er to poster.** `relations.validatedContacts.<id>`
(fra før, fail-closed, eiersignert) holder *hvordan nå* — e-post, telefon.
`relations.records.<id>` (ny, `EntityRelationRecordV1`) holder *selve båndet*:
opprinnelse, roller per kontekst, interesser, kanaler, standing, bevis,
interaksjonssammendrag. Den nye posten avviser råadresser ved skriving
(`rawContactValueNotAllowed`), så den kan følge entiteten til enhver flate uten
å bli en kontaktliste på veien. Samme `relationID` binder dem.

**Roller er per kontekst, ikke per person.** Sjur er prosjektleder og redaktør
i bokprosjektet og professor emeritus for øvrig. `EntityRelationRole(context,
role, group)` — én person, mange kontekster. Importøren fikk et eget
`.group`-felt («Gruppe», «arbeidsgruppe», «spor», «bord») og `import.commit`
tar `context`; uten det er filnavnet konteksten. Ærlig, om enn dårlig.

**Erklært og antatt holdes fra hverandre hele veien.** `interests.declared`
og `interests.inferred` i entiteten, ikke bare et prefiks i en tag-liste.
Grafen veier dem ulikt (0,75 / 0,35), og en flate må kunne vise eieren hva
som er sagt og hva som er gjettet.

**Interaksjoner er chronicle-hendelser; posten har bare summen.**
`chronicle[id=relation-event-<relationID>-<eventID>]` er hendelsen
(`EntityRelationInteractionEvent`), `interactions` på posten er det løpende
sammendraget en flate kan binde uten å lese chronicle. Ett commit skriver
begge, så de ikke kan skli fra hverandre. `applying(_:chronicleRef:)` er ren
og testet: samme hendelse to ganger er en feil testen ser.

**Egen policy, standard `metadata`.** `person.relations.interactionPolicy`
er `off | metadata | full`. Metadata: at kontakt skjedde, når, kanal og
retning — aldri hva. `full` krever `fullContentWarningAccepted`. Policyen
overstyrer den som kaller: en hendelse med sammendrag under metadata-policy
bygges om uten sammendraget før den skrives. Chattens policy står fortsatt
`off`; de er to brytere fordi de svarer på to spørsmål.

**Bevis er referanser.** `EntityRelationEvidence` peker på en VC-id eller en
presentasjons-hash; selve legitimasjonen bor i `proofs`. `verified` sier om
*vi* sjekket signaturen. `vc.presented` løfter standing til `verified`; en
blokkering lar seg ikke oppheve av bevis.

**«Hvordan når jeg Vegar» er en ren funksjon.** `EntityRelationReachPlanner`
i CellBase rangerer kanalene på posten — entitet (åpne chat) foran
korrespondanse foran nylig nearby foran invitasjonslenke — og skriver
grunnen på norsk for eieren. En invitasjon sendt for under sju dager siden
gjør `send-invite` til `resend-invite` med dato i begrunnelsen. Ingen kanal og
ingen blokkering gir et ærlig «jeg har ingen kanal», ikke en gjetning. Samme
planner skal brukes av butleren, flaten og scaffoldet.

**Entiteten er autoritet, cellen er arbeidskopi.** `BindingRelationsCell`
speiler hver endring inn i entiteten via `EntityBatchPersistEnvelope` og
autoritetsjournalen — samme vei som chat-chronicle. Mutasjons-id er en hash av
innholdet, så en identisk resync er gratis. Sletting er en `null`-skriving til
postens egen keypath. `relations.syncToEntity` tvinger full runde.

**Butleren slår opp ekte mennesker.** «Anna Kollega» er borte.
`analyzeDraft` kaller `relations.reach` med navnet skrelt ut av setningen;
to treff blir et spørsmål, null treff blir «fant ingen». Å godta forslaget
gjør det planneren anbefalte: åpne chat mot entiteten, eller be
invitasjonscellen forberede en lenke. Begge logger en interaksjon.

**Oppstartsidentiteten overlever nå omstart.** `BindingStartupIdentityVault`
sover i Keychain per kontekst og gjenoppstår før noe mintes. Under XCTest,
eller med `--haven-ephemeral-identity`, som før. Det som *ikke* er gjort: de
to «private»-identitetene (oppstart og Face-ID-autentisert) er fortsatt to
personer. IdentityLink-VC-en er veien til én — lagt i oppgavekøen.

## Nye nøkler på `cell:///Relations`

| Nøkkel | Type | Hva |
|---|---|---|
| `relations.reach` | set | `{query}` eller `{id}` → plan med anbefalt handling, alternativer, blokkeringer, siste kontakt |
| `relations.recordInteraction` | set | `{id, kind, channel?, direction?, at?, summary?, evidenceID?}` → chronicle + sammendrag |
| `relations.interactions` | set | `{id, limit?}` → hendelsene bak sammendraget, nyeste først |
| `relations.syncToEntity` | set | tvungen full synk |
| `relations.interactionPolicy` | set | leser policyen |
| `relations.setInteractionPolicy` | set | `{mode, fullContentWarningAccepted?}` |
| `relations.entitySync` | get | siste synk-resultat (også i `state.entitySync`) |

`relations.setInviteState` til `prepared/sent/opened/joined` logger nå
tilsvarende `invite.*`-hendelse automatisk.

## Verifisert

- CellBase: 14 tester i `EntityRelationRecordV1Tests` (rundtur gjennom
  autoritetsjournalen, avvisning av råadresse i fire former, binding
  keypath↔relationID, policy-overstyring, planner i seks situasjoner).
- Binding: 32 tester i 8 suiter, inkludert **den ekte deltakerlista**:
  189 poster, 0 hoppet over, 181 med arbeidsgruppe, 20 i «KI og tillit»,
  13 i «Bærekraft», Sjur som «Prosjektleder og redaktør», ingen adresse i
  noen entitetspost. Testen leser `.sprout/import/` og trer til side der fila
  ikke finnes — 189 virkelige mennesker skal ikke inn i et repo.
- Identitet: to vaults over ett lager = to oppstarter av samme app; samme
  UUID, samme signaturnøkkel, adopsjon i stedet for overskriving.

## Ærlig om det som gjenstår

1. **Korrespondansen logger ikke seg selv.** MCP-verktøyene kjører i
   daemonen og kaller ikke `relations.recordInteraction`. Uten det er «når
   snakket vi sist» blind for den kanalen som faktisk virker. Oppgavekø.
2. **Scaffoldet leser ikke `relations.records` ennå.** Porthole ser ikke
   relasjonene før den gjør det. Oppgavekø.
3. **To identiteter.** Se over.
4. **Nearby skriver ikke `nearby.met`.** Kanalen finnes i modellen;
   EntityRadar kaller ikke inn. Én linje når noen tar den.
5. **Ingen VC utstedes ennå ved kontakt.** Modellen tar imot bevis;
   ingen produserer dem. `IdentityLinkVCProfile.md` har oppskriften.
