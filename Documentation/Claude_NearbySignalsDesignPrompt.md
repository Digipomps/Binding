# Claude Prompt: Nearby Signals UI Design

Use this prompt when asking Claude for a grounded GUI proposal for Binding's
Nearby Signals surface.

```text
You are designing a GUI proposal for a new Binding / HAVEN Personal Co-Pilot feature called "Nearby Signals".

This is not a blank-slate social feed. Stay grounded in HAVEN / CellProtocol boundaries.

Product goal:
A user can capture their current or manually selected position, add text, optional image, purpose and interests, then publish it as a short-lived nearby signal. Other users can search the area they are currently in and discover openly published interesting things nearby.

Important defaults:
- The published object is a "Nearby Signal", not a permanent profile and not a generic map pin.
- Default visibility is ephemeral nearby: coarse location, minimum radius 250 m, expires after 2 hours.
- Publishing requires explicit consent.
- Search returns only active, openly published signals.
- No private drafts, exact GPS, EXIF metadata, private profile data, chat state, or inferred preferences should be exposed.
- Purpose/interests use HAVEN concepts such as `purpose://...` and `interest://...`.
- Ranking should feel explainable: nearby, relevant to declared purpose/interests, recently active.

Architecture boundaries:
- Binding owns local/native capture: location permission, manual location fallback, image picker, EXIF stripping, local draft, publish preview, privacy audit.
- CellScaffold owns published read models and directory search through cells like `NearbySignalPublisherCell` and `NearbySignalDirectoryCell`.
- Public profile, chat, contact exchange, report/hide/block should be separate references or handoffs, not hidden inside the scanner/signal draft.
- Skeleton/CellConfiguration can render lists, forms, details, buttons, status and moderation actions.
- Native SwiftUI is appropriate for map/radius/location capture and image picking.

Design the GUI for phone, tablet and desktop.

Please produce:
1. Recommended UX direction and emotional tone.
2. Main user flow: create draft -> choose position -> add text/image -> choose purpose/interests -> preview -> publish -> renew/unpublish/delete.
3. Discovery flow: search nearby -> filter by purpose/interests -> inspect signal -> report/hide/block -> optional contact/chat handoff.
4. Component set: composer, location/radius selector, image preview, purpose/interest chips, publish preview, nearby result card, signal detail, empty/denied/error/moderation states.
5. Phone, tablet and desktop layouts.
6. Clear distinction between native Binding components and portable CellConfiguration/Skeleton components.
7. Privacy and trust copy: concise UI text for consent, expiry, coarse location, image metadata, and "openly published".
8. Accessibility and small-screen behavior.
9. Implementation roadmap with v1, v1.1 and future enhancements.

Do not produce only visual moodboard language. Make the proposal practical enough that an engineer can implement it in Binding with native SwiftUI plus CellConfiguration surfaces.
```

## Implementation Notes From Claude Proposal

- Keep the invariant explicit in code and contracts: `NearbySignalDraft` stays local, `NearbySignalPublishRequest` is the only object sent on publish consent, and `NearbySignalSummary` is the only directory/detail read model.
- Current Binding fallback renders the portable parts in CellConfiguration/Skeleton: forms, preview/consent copy, result lists, status, report, hide and block.
- Native SwiftUI/OS-owned pieces remain a separate Binding slice: CoreLocation prompt, manual MapKit picker/radius overlay, PhotosUI image picker and real EXIF stripping.
- Do not add fake Skeleton elements for map, photo picking or sliders. Until native UI is wired, the portable fallback uses text fields and explicit buttons to model the contract safely.
