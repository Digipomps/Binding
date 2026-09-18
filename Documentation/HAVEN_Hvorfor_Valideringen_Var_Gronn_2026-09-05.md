# Hvorfor valideringen var grønn mens flaten var tom — 2026-09-05

Relasjoner-flaten viste en tittel og ingen vei inn. Ingen filopplasting, ingen
knapper, ingenting å gjøre. Alle tester var grønne. Dette er hvor
formålsdefinisjonen og valideringen sviktet, ledd for ledd, bevist fra kode.

## Selve feilen, i én setning

Sju seksjoner var portet på `visible(when:)` med rot-scope mot celletilstand.
Rendereren gir ingen verdi på rotnivå, en betingelse som ikke lar seg slå opp
returnerer `false`, og `false` betyr skjult. Flaten var derfor tom ved
konstruksjon — ikke ved en tilstand, men alltid.

Kjeden, verifisert:

1. `ContentView` tegner flaten: `BindingSkeletonView(element: skeleton)` —
   `userInfoValue` utelatt, altså `nil`.
2. `SkeletonElementView.isElementVisible` kaller
   `visibility.isVisible(root: userInfoValue, item: userInfoValue, context: userInfoValue)`.
3. `SkeletonConditionExpression.evaluate` → `resolve(scope: .root, root: nil)` → `nil`.
4. `if let equals { guard let resolvedValue … else { return false } }` → **false**.
5. Seksjonen tegnes ikke. Uten spor.

Inne i en listerad er det annerledes: `CellListView` sender radens verdi videre
som `userInfoValue`, så betingelser der lar seg svare på. Skillet er scope, og
det er mekanisk sjekkbart.

## Fem steder det gikk galt

**1. Valideringen målte røret, ikke bildet.** Hver eksisterende sjekk leser data
gjennom `porthole.get(...)`: rot-prober, referanseoppslag, lastetid. Rendereren
bruker en annen vei for synlighet. *En test som når dataene på en annen vei enn
produksjonen sertifiserer ingenting om produksjonen.* Det er den generelle
lærdommen, og den gjelder langt utenfor skeletons.

**2. Testkorpuset var ikke det som ble sendt ut.**
`offeredCatalogConfigurationsForVerification()` mapper scaffold-formålsmalene.
Flatene eieren faktisk åpner kommer fra `personalCopilotV1MenuConfigurations()`
og sidemeny-enumen — en annen liste. Relasjoner var bare i den andre. Derfor
pekte verken rot-probe-testen, lastetidstesten eller finnbarhetsauditen
noensinne på den.

**3. «Kan ikke slås opp» og «er usann» er samme svar.** `evaluate` returnerer
`false` for ukjent keypath, for feil verdi, for `isMalformed`, og for en
betingelse uten predikat i det hele tatt (`return evaluatedAnyPredicate`). Fire
svært ulike situasjoner, ett svar, null signal. Verken forfatter eller validator
kan skille dem uten en egen diagnosevei.

**4. `visibility` er udokumentert.** `references/schema-and-limits.md` lister
`hidden` under støttede modifiers, men nevner ikke `visibility`,
`SkeletonVisibilityRule` eller `SkeletonCondition` med ett ord. Hele flatens
struktur hviler på en modifier som ingen har skrevet ned semantikken til. Å lese
Swift-modellen gir formen, ikke rendererens scope-regler.

**5. Paritetssjekken var betinget vekk.** `cellconfiguration-skeleton-authoring`
har seksjonen «Porthole / Binding Design Parity Check» som eksplisitt nevner
«dead buttons» og «the requested initial configuration is actually rendered» —
men den åpner med *«When the task is a product redesign or design guide»*. Å
skrive en ny flate er strengt lest ingen av delene. Og hele
«Runtime Skeleton Iteration»-loopen, den som produserer skjermbilder, er scopet
til `/CellScaffold`. **Flater som bor i Swift-fabrikker i Binding har ingen
rendret-utdata-loop i det hele tatt.** Det er det strukturelle hullet.

## Og mine egne, i denne økten

**Jeg åpnet aldri skeleton-skillen.** Jeg la til to skeleton-elementer i dag —
et `TextField` for importkontekst og en `Visualization` på tre scanner-flater —
uten å invokere `cellconfiguration-skeleton-authoring`, hvis beskrivelse dekker
«adding or editing skeleton elements» ordrett. Hadde jeg gjort det, sto både
paritetsregelen om døde knapper og denne linjen der: *«FileUpload is supported
today as a real SkeletonElement case. Prefer it for new upload surfaces.»*
Kjetils første innvending — «det er ingen file upload eller drop-muligheter» —
er en regel jeg ikke leste. `SkeletonFileUpload` har `supportsDrop`.

**Jeg gjorde feil måling mer presis.** Jeg bygde `HavenSurfaceRelevance.audit`,
som sjekker at en flate er *beskrevet godt nok til å bli funnet*, og kalte
flatene validert. Finnbarhet er en egenskap ved beskrivelsen. Den sier ingenting
om at flaten virker. Presisjonen fikk det til å føles som dekning.

**Jeg svarte «klart» på et spørsmål om appen med bevis fra cellene.** Kjetil
spurte «klart for import via appen?». Min ende-til-ende-test gikk gjennom
cellene — ordene «through the cells» sto til og med i commit-meldingen. Jeg
kunne ikke se skjermen, og jeg sa det én gang, men lot det ikke stoppe et ja.

## Hva som er gjort

`SkeletonReachabilityAudit` (CellBase) svarer på spørsmålet et schema-sjekk ikke
kan: *vil noen noensinne se dette?* Den avgjør ved å kalle rendererens egen
betingelsesevaluering med rendererens egne rot-inndata, så den kan ikke drifte
fra skjermen. Funn navngir **hva eieren mister**, ikke at en node er skjult —
`lostActionKeypaths` er det som gjør et strukturfunn til et formålsfunn.
`reachableActionKeypaths` gir den andre halvdelen: mengden en
forventningskontrakt kan sjekkes mot, slik at «eieren kan importere en fil» blir
noe en test kan holde.

`testNoLocalSurfaceHidesItsOwnWaysIn` kjører den over alle tre korpusene.
Resultat: **1 av 23 flater** — Relasjoner, sju døde seksjoner, tolv utilgjengelige
handlinger, blant dem `addressBook.addressBook.pickFile` og
`contactImport.import.commit`. Resten av appen er ren. Testen står rød til
flaten er bygget om.

## Hva som gjenstår, og hvem som bestemmer

Relasjoner kan repareres på to måter uten rendererendring: flytte det portede
innholdet inn i rader, der betingelser lar seg svare på, eller la cellene avgjøre
og binde innhold i stedet for å porte seksjoner. Den tredje — å la rot-scope
betingelser slå opp mot absorbert celletilstand — er en rendererendring og
dermed Kjetils avgjørelse. Grenen `codex/condition-resolution-native-20260828`
er navngitt etter nettopp dette, men har ingen commits om det.

Uansett vei bør flaten bruke `FileUpload` med `supportsDrop`, ikke bare en knapp
som åpner en filvelger.
