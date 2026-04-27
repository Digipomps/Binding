# Binding Personal Co-Pilot GUI Design Prompt

Use this prompt with another language model when we want GUI proposals for Binding as a Personal Co-Pilot app built on `CellConfiguration` and Skeleton-based rendering.

## Prompt

```text
You are a senior product designer and design-systems thinker working on Binding, a component-based Personal Co-Pilot app built on top of CellProtocol and `CellConfiguration`.

Your job is to propose a flexible GUI system for Binding that works across:
- phone
- iPad / tablet
- laptop
- desktop

The output must be realistic for a component-based renderer where screens are assembled from portable `CellConfiguration` + Skeleton JSON, not hand-coded custom screens for every feature.

The design must feel intentional, premium, calm and modern, but also robust enough for rapid expansion as new components become available from CellScaffold or through later app releases.

Do not design a conference app. This is a Personal Co-Pilot product.

## Product context

Binding V1 is a curated Personal Co-Pilot with these user-facing areas:
- Personal Home
- My Profile
- Publish Public Profile
- Matches
- Invite Chat
- Vault / Ideas
- Meeting Intent
- Apple Intelligence
- Entity Scanner
- Workflow Studio
- Privacy / Audit surfaces

The product model is:
- local-first where sensible
- explicit consent before publishing private/profile data to cloud
- invite-only chat
- no random social feed
- no conference/demo focus
- no arbitrary plugin marketplace in the App Store experience

## Important technical context

Binding renders UI from `CellConfiguration.skeleton`, which behaves more like a portable UI document than app-local SwiftUI code.

Assume the current renderer supports composition from these building blocks:
- `VStack`
- `HStack`
- `ZStack`
- `ScrollView`
- `Section`
- `Grid`
- `List`
- `Reference`
- `Text`
- `Image`
- `Button`
- `TextField`
- `TextArea`
- `Toggle`
- `Picker`
- `Divider`
- `Spacer`

Assume each element can use a shared modifier model with fields like:
- padding
- width / height
- maxWidthInfinity / maxHeightInfinity
- alignment
- background
- cornerRadius
- shadow
- borderWidth / borderColor
- opacity
- text styling such as foregroundColor, fontStyle, fontSize, fontWeight, lineLimit, multilineTextAlignment, minimumScaleFactor

Assume data binding works through:
- top-level `cellReferences`
- label-relative keypaths inside the skeleton
- `cell:///Porthole/<label>...` when an explicit URL is needed
- requester-scoped local draft state for things like unsent compose text

Assume remote CellConfigurations can be added later from CellScaffold, so the design system must be extensible and must not depend on every future feature being hard-coded into the app shell.

## Design objective

Create a design template and component system for Binding that:
- feels native and polished on phone, iPad and desktop
- can host both current and future Personal Co-Pilot surfaces
- gracefully supports unknown future components from CellScaffold
- keeps a strong product identity even when content comes from remote configurations
- avoids UI dead ends
- remains legible, touch-friendly and keyboard-friendly
- is App Store-safe and suitable for a curated Personal Co-Pilot product

## Hard constraints

1. Do not assume completely custom native views for each feature.
2. Stay grounded in the current Skeleton component vocabulary unless you explicitly label something as a future enhancement.
3. Treat `CellConfiguration` as a portable UI contract.
4. New remote surfaces should be able to inherit the system and look coherent without redesigning the entire app.
5. The shell must scale from compact phone screens to large desktop canvases.
6. Unknown or newly added components must have a graceful host pattern, not a broken or ugly fallback.
7. The design should prioritize readability, composability, consent flows, chat clarity and modular expansion.

## What I want from you

Produce a practical design proposal with these sections:

### 1. Product shell
Design the overall Binding shell for:
- phone
- iPad
- laptop/desktop

Describe:
- navigation model
- where catalog/menu lives
- where the active Porthole surface lives
- how secondary actions and context are shown
- how editing / apply / discard / draft states should appear

### 2. Visual language
Define:
- overall design direction
- typography strategy
- color strategy
- elevation / borders / surfaces
- spacing rhythm
- iconography direction
- motion principles

Give a design direction that does not feel generic or “AI default”.

### 3. Design tokens
Propose a compact token system for:
- color
- spacing
- radius
- border
- shadow
- typography scale
- sizing

The tokens should work across phone, tablet and desktop.

### 4. Core component library for Binding
Define a reusable component template set for the kinds of things Binding needs to show.

At minimum include:
- app shell / canvas shell
- navigation tile / menu tile
- hero panel
- section header
- card
- status badge / chip
- key-value summary block
- action row
- primary / secondary / destructive buttons
- inline form field
- multiline draft editor
- list row
- grid tile
- empty state
- loading / syncing state
- unavailable / read-only state
- consent prompt
- publish confirmation pattern
- match card
- chat thread list item
- chat message bubble
- chat composer block
- meeting intent card
- vault note/project card
- audit/event row
- scanner result card
- workflow step/node card

For each component, describe:
- purpose
- visual anatomy
- which current Skeleton elements it can be built from
- key states
- compact / medium / expanded behavior
- what happens if content is missing, unavailable or read-only
- how it should inherit styling when rendered from a remote CellConfiguration

### 5. Screen assemblies
Show how the components combine into complete screens for:
- Personal Home
- My Profile
- Publish Public Profile
- Matches
- Invite Chat
- Vault / Ideas
- Meeting Intent
- Workflow Studio

For each screen, explain the structure on:
- phone
- iPad
- desktop

### 6. Extensibility model
This is especially important.

Propose a strategy for how Binding should visually absorb future components from CellScaffold without collapsing into inconsistency.

Address:
- component families
- surface wrappers
- fallback containers for unknown remote components
- metadata-driven presentation hints
- how a new remote config can feel “native to Binding” on day one
- how to distinguish “local core component”, “remote trusted component” and “read-only unavailable component”

### 7. Responsive layout rules
Give concrete layout rules for:
- single-column compact phone
- two-pane tablet
- multi-pane laptop/desktop
- minimum touch targets
- maximum readable text widths
- list vs grid switching
- persistent vs collapsible side panels

### 8. Accessibility and internationalization
Cover:
- dynamic type tolerance
- contrast
- keyboard navigation on laptop/desktop
- screen reader semantics
- long localized strings
- safe empty states and denied-permission states

### 9. Current-support vs future-support
For each major idea, clearly separate:
- what can be built now with today’s Skeleton/CellConfiguration model
- what is a near-term extension
- what would require a deeper renderer/platform enhancement

### 10. Output format
Structure your answer like this:

1. One recommended design direction
2. Two alternative visual directions
3. A responsive shell proposal
4. A component catalogue
5. Screen assembly recipes
6. Extensibility rules for future CellScaffold components
7. A short prioritized implementation roadmap

## Practicality requirement

Do not give me only moodboard language.
I need a proposal that can actually guide implementation in a Skeleton-driven system.

For the most important components, include a “Skeleton-friendly recipe” like:
- parent container type
- typical nested elements
- expected modifiers
- data-binding pattern

Example level of detail:
- “Profile card can be built as Section -> VStack -> HStack(Image + VStack(Text...)) + HStack(chips) + Button row”

## Tone of the design

Aim for:
- calm confidence
- thoughtful productivity
- human warmth
- high trust
- modularity
- personal intelligence rather than enterprise dashboard

Avoid:
- conference/demo aesthetics
- generic social media look
- noisy startup gradients everywhere
- dark-pattern engagement tricks
- overdesigned futuristic chrome that will break when remote components vary

## Final reminder

This app is unusual because the UI is assembled from portable component contracts. Your proposal must embrace that instead of fighting it.

Design a system, not just a few pretty screens.
```

## Notes For Us

- This prompt is intentionally strict about current Skeleton support so the receiving model does not invent impossible UI primitives.
- It also asks for an extensibility model, which is the main challenge in Binding: new `CellConfiguration` surfaces should arrive into a coherent design system instead of feeling like foreign bodies.
- If we want, the next step can be a second prompt that asks the other model to turn its chosen direction into concrete `CellConfiguration`/Skeleton recipes for a subset of Personal Co-Pilot screens.
