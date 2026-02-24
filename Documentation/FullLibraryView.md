# Full Library View (Binding)

This document describes the implemented Full Library UI for the Binding app.

## Entry points
- `upperMid` edge-menu main button opens Full Library (search-first role).
- Mode panel includes a `Library` button for explicit access.
- The view is presented as a sheet from `ContentView`.

## File map
- UI: `Binding/FullLibraryView.swift`
- Catalog backend/query contract: `Cells/ConfigurationCatalogCell.swift`
- Host wiring: `Binding/ContentView.swift`

## Implemented IA
- Tabs/segments:
  - `All configs`
  - `For my purposes`
  - `Sources`
  - `Templates`
- Search:
  - Search-as-you-type (`q`)
  - Token input (format: `kind:value`)
- Tokens:
  - `purpose`
  - `interest`
  - `category`
  - `source`
  - `compatibility`
  - `authRequired`
- Facets:
  - category path
  - source
  - compatibility (`supportedInsertionModes`)
  - auth required
  - flow-driven
  - editable
- Result details:
  - score + score breakdown
  - route (`directPurpose` / `viaInterest` / `text`)
  - badges
  - source ref
  - skeleton preview (when available)

## Runtime calls
- Query endpoint:
  - `set("query", payload)`
- Facet endpoint:
  - `set("facetCounts", payload)`

Query payload includes:
- `q`
- `tokens`
- `filters`
- `context` (`editMode`, `selectedNodeKind`, `insertionIntent`)
- `constraints` (`maxSources`, `resourceBudget`, `networkPolicy`, `allowDegradedSources`, `maxResults`)

Facet payload includes:
- `baseQuery`
- `facetKeys`
- `activeFilters`

## Offline behavior
- Full Library depends on online `ConfigurationCatalog`.
- If no catalog source resolves:
  - Full query/facet UI is shown as unavailable.
  - Fallback sections remain available:
    - cached favorites (from upper-right menu set)
    - cached templates/bootstraps (from lower-left menu set)

## Current limitations
- View currently applies selected configurations as full Porthole loads (same behavior as existing click-to-add).
- Root-vs-component insertion probing is not yet implemented in this UI layer; compatibility is represented via badges/facets and query context only.

