# CellScaffold Handoff: Conference Admin Preview on Staging

Date checked: 2026-03-31

Context:
- Binding `main` now routes conference demo start through `Conference Demo Launcher`.
- `Conference Public Surface` is intentionally staging-backed because staging is the deployed CellScaffold instance.
- Binding-side routing/build now looks healthy.
- The remaining gap is the quality of the organizer/admin preview state served by staging.

## Summary

`Conference Public Surface` on staging looks healthy.

`Conference Control Tower` on staging now serves much more real organizer data than it did earlier the same day. The remaining organizer gap is narrower now: the `system` lane is still denied, and the `content` lane still reports `Unavailable.`, but access, audience discovery, insights, sponsor, session polling, session thread, and simulation now return meaningful state.

This means the current organizer problem no longer looks like broad Binding routing failure. It looks like a narrower staging-side preview parity gap around:

- published content editor state
- `AdminOverview` / system observer metrics

## Endpoints checked

Public surface:
- `https://staging.haven.digipomps.org/conference-public`
- `https://staging.haven.digipomps.org/conference-public/api/configuration`
- `https://staging.haven.digipomps.org/conference-public/api/state`

Admin preview:
- `https://staging.haven.digipomps.org/conference-admin-preview?previewAdminId=preview-fresh-check`
- `https://staging.haven.digipomps.org/conference-admin-preview/api/configuration?previewAdminId=preview-fresh-check`
- `https://staging.haven.digipomps.org/conference-admin-preview/api/state?previewAdminId=preview-fresh-check`

## What is healthy

### Public surface

The public route is healthy and serves:
- correct HTML shell title: `Conference Public Surface`
- correct configuration name: `Conference Public Surface`
- correct cell reference label: `conferencePublicShell`
- non-empty state for:
  - `workspace`
  - `tracks`
  - `sessions`
  - `people`
  - `articles`
  - `facilities`
  - `access`

This means the staging-backed public opener is currently good enough for Binding parity.

### Admin preview configuration

The admin preview configuration itself is healthy:
- configuration name: `Conference Control Tower`
- source cell: `ConferenceAdminPreviewShellCell`
- reference label: `conferenceAdminShell`

So the route and top-level config are not the main problem.

## What is failing or unresolved on admin preview state

From `GET /conference-admin-preview/api/state?previewAdminId=preview-fresh-check`:

### Published content / organizer CMS
- `content.intro = "Published content editor unavailable."`
- `content.status = "Unavailable."`
- `content.lifecycleSummary = "Published content state unavailable."`
- content previews and draft collections still look unresolved

### System / admin observer
- `system.status = "Live admin metrics unavailable."`
- `system.topProcessSummary = "AdminOverview lookup failed: denied"`
- resolver / storage / host summaries remain unavailable

## What is healthy now on admin preview state

### Access / agreements
- `access.agreementSummary = "No access requests created yet."`
- `access.coverageSummary` is populated
- `access.selectionSummary` is populated
- organizer access matrix rows are populated

### Access requests
- `accessRequests.headline = "Audience access requests"`
- `accessRequests.status = "0 request(s) total · 0 pending · 0 active grants."`
- segment options and policy summaries are populated

### Audience discovery
- `audienceDiscovery.headline = "Audience discovery"`
- `audienceDiscovery.status = "4 cohort(s) modeled. 123 query-ready and 97 still gated across roughly 213 relevant entities."`
- query-ready and gated entities are populated

### Organizer insights
- `insights.dashboardSummary = "2 relations · 1 meetings · 0 bilaterally persisted agreement set(s) · 0 consented signal(s)"`
- `insights.status = "Organizer projection ready..."`
- the section now reads like a real organizer aggregate instead of a dead shell

### Sponsor / exhibitor
- `sponsor.dashboardSummary = "No sponsor-safe participant feed loaded."`
- `sponsor.status = "Sponsor dashboard ready from organizer-safe consent and lead aggregates."`
- zero-data is now intentional rather than unavailable

## What still works inside admin preview

These parts are healthy:
- `workspace`
- `access`
- `accessRequests`
- `audienceDiscovery`
- `insights`
- `sponsor`
- `sessionPolling`
- `sessionThread`
- `simulation`

That suggests:
- the preview route is alive
- the wrapper shell is alive
- most organizer-side subcells are now resolvable
- the remaining broken lanes are much more specific than before

## Likely problem shape

Most likely one or more of these:
- published content still expects a stronger organizer requester or stronger seeded authoring state
- `AdminOverview` observer path is still denied for the preview identity
- preview fallback behavior is still too harsh for content/system lanes even when the rest of the organizer shell is healthy

## Suggested debug order

1. Re-check published content preview path
- Confirm why `content` still resolves to `Unavailable.` while the rest of the organizer shell is now healthy.
- Compare requester choice there with the now-healthy access / insights / sponsor lanes.

2. Re-check `AdminOverview`
- `system.topProcessSummary = "AdminOverview lookup failed: denied"` is still the clearest remaining signal.
- If that requester path is fixed, the whole `system` lane may unblock quickly.

3. Verify preview-specific fallback behavior
- If preview intentionally cannot read some live authoring or observer state, serve an honest reduced preview instead of full `Unavailable.` placeholders.

## Expected outcome for Binding parity

Binding should be able to load staging admin preview without filling major sections with unavailable placeholders.

Minimum parity target:
- access section populated
- content section populated or intentionally reduced-but-readable
- insights section populated
- sponsor section populated
- system section either populated or intentionally omitted in preview

## Binding-side status

Binding commit used during this check:
- `9a6384bc` `Align Binding conference demo launcher with staging`

Binding-side conclusions:
- public surface routing is healthy
- admin preview routing is healthy
- the organizer gap is now mostly about content/system parity and visual hierarchy, not a dead preview route
