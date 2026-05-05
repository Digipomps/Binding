# Gemini Conference Chat UI Prompt

Use this prompt together with:

- [/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/GeminiSkeletonDesignPack.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/GeminiSkeletonDesignPack.md)
- [/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/Porthole-and-skeleton.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/Porthole-and-skeleton.md)
- [/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/SkeletonElements_Detailed.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/SkeletonElements_Detailed.md)
- [/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/SkeletonModifiers.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/SkeletonModifiers.md)
- [/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/ScaffoldChat.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/ScaffoldChat.md)

Prompt:

```text
I want a concrete UI proposal for a conference chat in Binding/HAVEN.

Please read the attached Skeleton/Porthole documentation first and treat it as hard implementation context.

Important constraints:
- The UI is rendered through HAVEN Skeleton inside Porthole.
- The chat already works technically.
- I do not want new runtime primitives, new app architecture, or custom rendering systems.
- Do not suggest direct remote field URLs inside skeleton internals when absorbed cell references already exist.
- Do not suggest leaking unsent drafts onto a shared feed.
- Keep the existing control/data model intact.

Current goal:
- Make the conference chat feel more like a traditional readable chat.
- Reduce the admin/dashboard feel.
- Preserve the existing conference context and actions.

Platform goals:
- iPhone portrait: one clear chat column.
- iPad and Mac: conversation should still read as one conversation first, with optional secondary context.

Please give me:
1. A short critique of why the current chat likely reads as a dashboard rather than a chat.
2. A concrete layout proposal for iPhone portrait.
3. A concrete layout proposal for iPad/Mac.
4. Suggestions for:
   - header
   - message list
   - incoming vs outgoing messages
   - metadata/timestamps
   - composer/text editor
   - primary send action
   - secondary actions
5. A prioritized rollout:
   - Phase 1 = biggest improvement, lowest implementation risk
   - Phase 2 = improvements that can come after
6. A short “avoid” section listing things we should not do.

Please optimize for proposals that are realistic inside the current Skeleton/Porthole system.
```
