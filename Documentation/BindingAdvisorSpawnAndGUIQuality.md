# Binding advisor spawn and GUI quality contract

Date: 2026-07-04

## Purpose

Binding needs a repeatable way to ask several advisers for GUI judgement without turning that
judgement into hidden provider calls or implicit Cell side effects. The new `haven-agentd
plan-advisors` command creates a strict no-write plan, while `haven-agentd spawn-advisors` creates a
local, reviewable advisory artifact. Neither command runs an AI model, sends notifications, mutates
cells, opens helpers, accepts suggestions, or executes scripts.

The command is intended to support GUI decisions such as Co-Pilot Chat, Arendalsuka/Event Atlas,
and other portable CellConfiguration surfaces where Binding must stay semantically paired with
CellScaffold/Porthole.

## Command

```bash
swift run haven-agentd plan-advisors \
  --profile binding-gui
```

Persist the same panel as a local artifact only after that is explicitly useful:

```bash
swift run haven-agentd spawn-advisors \
  --profile binding-gui \
  --out-dir /tmp/haven-advisors
```

Useful variants:

```bash
swift run haven-agentd spawn-advisors \
  --profile arendalsuka-gui \
  --brief-file /path/to/gui-brief.md \
  --source-ref Binding \
  --source-ref CellScaffold/Porthole \
  --json
```

Custom panels can be created with:

```bash
swift run haven-agentd spawn-advisors \
  --profile custom \
  --topic "Binding surface review" \
  --purpose purpose://binding.gui.user-value \
  --goal "Define measurable acceptance criteria for a user task" \
  --brief-file /path/to/brief.md \
  --advisor "cellprotocol-steward|CellProtocol Steward|local_or_reviewed|Check grants, ownership, side effects, and portable semantics|grants,side-effects,skeleton"
```

The no-write plan schema is `haven.agentd.advisor-panel-plan.v1`. Persisted artifacts use
`haven.agentd.advisor-panel-spawn.v1`. Generated task prompts use `haven.advisor-review.v1` as their
expected output contract.

## Objective GUI Quality Gates

A Binding GUI is good enough for production only when the user can complete the purpose it was made
for and the runtime can prove that it did so without policy shortcuts. These gates are intentionally
measurable:

1. Task success: a first-time user can complete the primary task path without reading developer
   terminology, raw keypaths, stack traces, or provider dumps.
2. Interaction cost: the first screen exposes one clear primary action and no competing action set
   that asks the user to understand internal modes.
3. Side-effect safety: analyze, preview, browse, open helper, and advisory review are side-effect-free.
   Send, save, share, invite, approve, sign, or execute require an explicit user action.
4. CellProtocol ownership: data and actions come only from cells available in the requester's scope
   through valid owner/grant/capability paths.
5. Purpose/Interest context: prompt and GUI routing use active Purpose/Interest context as ranking
   input, but not as authorization.
6. CellScaffold parity: Binding renders the same meaningful sections, tabs, lists, fields, helper
   openings, references, errors, and action contracts as CellScaffold. Pixel-perfect parity is not
   required.
7. Accessibility: the surface satisfies the relevant WCAG 2.2 AA-style checks for perceivable,
   operable, understandable, and robust UI, and supports keyboard/focus/status semantics where the
   platform exposes them.
8. Mobile usability: iPhone/iPad layouts keep touch targets reachable, avoid nested cards and
   duplicate bottom actions, preserve context when drawers/sheets open, and keep the composer or
   main task visible.
9. Performance: local/staging test runs should keep first useful render, interaction latency, and
   layout stability inside the same budget family as Core Web Vitals: LCP-like render <= 2.5s,
   INP-like response <= 200ms, and CLS-like layout shift <= 0.1 at p75 for mobile and desktop.
10. Failure hygiene: ordinary user surfaces must not show `failure:`, `denied(...)`, raw command names,
    or fallback placeholders as product copy. Diagnostics belong in an advanced/debug surface.

Sources used for the general quality gates: W3C WCAG 2.2, W3C Mobile Accessibility, and web.dev Core
Web Vitals. HAVEN-specific gates come from the CellProtocol/Binding/CellScaffold parity model.

## Binding GUI Shape

For chat-first and event-atlas style surfaces, the target shape is:

- One primary user interaction zone per surface. Chat-like surfaces use one composer and one primary
  submit/action affordance, not separate "send" and "find suggestion" controls.
- Progressive disclosure: default view shows the task, current context, and next safe step. Advanced
  details such as provider, purpose weights, signatures, execution scope, and raw diagnostics live
  behind "Mer" or an advanced inspector.
- Detail helpers use overlays, sheets, or drawers that preserve the current list/search/chat context.
  They must not replace the whole work context unless the skeleton explicitly asks for navigation.
- Search/filter/list/map/event-program flows must keep selection state stable and never auto-select or
  perform side effects from filtering alone.
- Standard UI says what will happen in human language: "Åpne forslag", "Forbered invitasjon",
  "Lagre privat utkast". Raw paths such as `assistant.acceptSuggestion` stay hidden.

## CellProtocol Boundaries

The GUI may help the user understand available actions, but it must not become the authority for
access:

- Visibility is not authorization. Older renderers may ignore visibility metadata, so cells and the
  resolver must still enforce grants.
- Binding must not create global provider registries or global helper menus. Providers, tools, and
  helper cells are discovered through the current requester scope and CellConfiguration references.
- Purpose/Interest can rank and explain possible routes, but cannot grant access.
- An overlay/drawer can open a helper without side effects. Accepting a suggestion, saving data,
  sending an invitation, or running an agent is a separate explicit action.
- The standard UI must not leak inaccessible cell names, participant data, drafts, contacts,
  calendar/mic/camera/vault contents, or other threads into prompts or visible UI.

## CellScaffold Parity Checklist

Every candidate Binding GUI should be checked against the CellScaffold baseline with this matrix:

| Check | Pass condition |
| --- | --- |
| Contract parity | Same source endpoint, cellReferences, readable keypaths, and writable actions exist. |
| Semantic parity | Same meaningful sections, tabs, lists, fields, helpers, references, and empty states are reachable. |
| Behavior parity | Buttons and selections update the same state/action contract and preserve parent context. |
| Failure parity | Missing grants show human recovery text or diagnostics, not raw runtime failure copy. |
| Responsive sanity | iPhone, iPad, and macOS layouts have no overlap, hidden primary action, or duplicate bottom controls. |
| Accessibility | Focus order, labels, status messages, reduced motion, contrast, and target sizes are acceptable. |
| Side-effect audit | Preview/open/analyze paths do not mutate; accept/confirm/send paths are the only mutations. |

## Adviser Roles

The default panel intentionally uses disagreement:

- CellProtocol Steward: catches ownership, grants, provider-scope, and side-effect mistakes.
- Binding GUI Evaluator: checks user comprehension, mobile ergonomics, accessibility, and interaction
  cost.
- CellScaffold Parity Reviewer: checks semantic parity with Porthole and portable skeleton behavior.
- User-Value Skeptic: challenges whether the GUI actually solves the user's purpose.

Their outputs should be synthesized into concrete implementation tasks, not treated as a vote.
