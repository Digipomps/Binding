# Personal Co-Pilot Design System

Dette dokumentet beskriver fase 1-implementasjonen av Binding sitt Personal Co-Pilot designsystem.

## Prinsipp

- `CellConfiguration` og Skeleton forblir portable sannhetskilder for innhold.
- Binding-shellen eier produktkontekst rundt portable flater:
  - navigasjon
  - loading / error / unavailable
  - trust / privacy / permission-kontekst
  - plattformspesifikk layout

Dette er med vilje ikke en ny Skeleton-spec og ikke en ny `presentationHint` i schemaet.

## Metadata-konvensjon

Personal Co-Pilot V1 legger disse hintene i discovery/policy-metadata:

- `surfaceFamily=<identity|relationship|content|intelligence|governance>`
- `presentationClass=<detail|list|grid|hero|form>`

Disse hintene ligger i samme metadata-strøm som eksisterende:

- `appStoreScope=personal-copilot-v1`
- `policyCategory=...`
- `requiresLogin=...`
- `requiresUserGeneratedContentModeration=...`
- `nativePermissionRequests=...`
- `universalLink=...`
- `reviewSummary=...`

I fase 1 brukes hintene av Binding-shellen for:

- valg av containerbredde
- inspector-innhold
- badges og trust/policy-kontekst

De brukes ikke som en generell theme engine.

## Style-role allowlist

Renderer-støttede / renderer-gjenkjente style roles for Personal Co-Pilot holdes bevisst små:

- `markdown`
- `tabstrip`
- `personal-hero`
- `personal-section-header`
- `personal-card`
- `personal-badge`
- `personal-action-row`
- `personal-key-value-block`
- `personal-inline-field`
- `personal-draft-composer`
- `personal-list-row`
- `personal-grid-tile`
- `personal-consent-prompt`
- `personal-publish-confirmation`
- `personal-match-card`
- `personal-chat-item`
- `personal-message-bubble`
- `personal-audit-row`
- `personal-scanner-result`
- `personal-workflow-step`

Viktig:

- `styleRole` og `styleClasses` er fortsatt metadata først.
- Vi lover ikke CSS-lignende eller generisk theme-oppførsel.
- Nye style roles bør bare legges til når Binding eller parity-suite faktisk trenger dem.

## Shell-retning i fase 1

- Telefon: native bunnnavigasjon for hovedgruppene `Home`, `Matches`, `Chat`, `Vault`, `Profile`.
- iPad/macOS: native sidebar/split-shell for `Personal`, `Network`, `Workspace`.
- Portable flater rendres fortsatt i samme Porthole-canvas.
- Inspector er shell-kontekst, ikke Skeleton.

## Tokens

Binding bruker en liten lokal tokenpakke for Personal Co-Pilot:

- krem/lyse flater
- lilla brand-aksent
- border-basert elevasjon
- medium som tyngste tekstvekt
- faste radius- og spacing-verdier

Tokenene brukes først på de kuraterte Personal Co-Pilot-seed-konfigene i `ConfigurationCatalogCell`.

## Ikke i fase 1

- ny `presentationHint` i `CellConfiguration`
- ukjent-komponent-container som skjuler kontraktfeil
- gesture-tunge shell-mønstre
- ekte node/canvas-Workflow Studio
