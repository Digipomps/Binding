# Personal Co-Pilot V1 App Store Mode

Binding now treats `Personal Co-Pilot` as the default product surface for App Store builds.

## Binding Runtime

- Default menu seeds expose only: `Personal Home`, `My Profile`, `Publish Public Profile`, `Matches`, `Invite Chat`, `Vault / Ideas`, `Meeting Intent`, `Apple Intelligence`, `Entity Scanner` and `Workflow Studio`.
- Conference/demo surfaces are still available in debug builds only when `BINDING_ENABLE_CONFERENCE_DEMO_MENUS=1` or `--conference-demo-menus` is supplied.
- App Store catalog gating is controlled by `BindingPersonalCopilotV1Policy.appStoreCatalogGateEnabled`.
- Allowed remote hosts are explicit. V1 currently allows `staging.haven.digipomps.org`; local `cell:///...` endpoints are allowed only when the configuration is scoped to `personal-copilot-v1`.
- Configurations must carry Personal Co-Pilot scope in discovery interests. Shipping catalog metadata is encoded as policy hints/interests with `appStoreScope`, `policyCategory`, `ageRatingHint`, `requiresLogin`, `requiresUserGeneratedContentModeration`, `nativePermissionRequests`, `universalLink` and `reviewSummary`.
- Phase 1 design-system metadata is also encoded in the same hint stream with `surfaceFamily` and `presentationClass`, so Binding can choose shell wrapper behavior without changing the shared `CellConfiguration` schema yet.

## Local Phone Cells

Binding registers these identity-scoped local cells:

- `PersonalIdentity`: requester/account lifecycle, export/delete hooks.
- `PersonalProfileDraft`: local profile draft, publish preview and consent staging.
- `PersonalChatClient`: invite-only chat draft surface with `invite`, `acceptInvite`, `declineInvite`, `sendComposedMessage`, `clearComposer`, `reportMessage`, `blockUser`, `blockedUsers` and `moderationStatus`.
- `PersonalMeetingIntent`: meeting intent state and Jitsi-ready `meetingBridge` metadata without camera/microphone/calendar requests in v1.
- `PersonalPrivacyAudit`: local audit log for publish, match consent, chat invite, remote config loads and permission grants.

## Phase 1 Shell Notes

- Binding now prefers a native Personal Co-Pilot shell when App Store catalog gating is active and the user is in view mode.
- Phone uses a native bottom-navigation grouping around the portable Porthole content.
- iPad/macOS uses a sidebar/split-shell with an inspector that reads curated metadata from the active configuration.
- Portable content still renders through the same Porthole canvas; the shell only wraps it with trust/privacy/policy context.

## CellScaffold Prompt

```text
Implement Personal Co-Pilot V1 for Binding App Store.

Expose only CellConfigurations with appStoreScope="personal-copilot-v1".

Build or update these sky cells:
- PersonalProfilePublisherCell: editable draft ingest, publish, unpublish, delete and public profile read model.
- PublicProfileDirectoryCell: searchable public profiles with reportProfile, hideProfile and blockProfile.
- PersonalMatchmakingCell: consent-based match suggestions; never starts chat without mutual approval.
- PersonalChatHubCell: invite-only 1:1/small-group chat using CellProtocol ChatCell contract; include filtering, reportMessage, blockUser, blockedUsers and moderationStatus.
- PersonalMeetingCoordinatorCell: meeting intent proposals and scheduling state; no native calendar/camera/mic access.
- PersonalCopilotConfigurationCatalog: returns only App Store-approved Personal Co-Pilot configurations and includes universalLink/review metadata for each configuration.

Hard requirements:
- No Conference* configurations in the default Personal Co-Pilot catalog.
- Every UGC surface must provide filter/report/block/contact hooks.
- Every configuration must include appStoreScope, policyCategory, ageRatingHint, nativePermissionRequests, universalLink and reviewSummary.
- Remote configs must not assume native permissions; Binding must request explicit user consent per permission.
- Chat must be Jitsi-ready by exposing meetingBridge metadata, but do not require or embed Jitsi for v1.
- Provide HTTP fixture routes and CellConfiguration parity fixtures for profile, matching, chat, vault handoff and meeting intent.
```

## Release Gates

- Fresh install must not show conference labels, demo launcher, sponsor/admin/control tower or conference chat.
- Catalog search/recommendations must return only `personal-copilot-v1` entries from approved hosts in App Store mode.
- Chat must support invite, accept, decline, compose/send, report and block before submission.
- Profile publish must require explicit consent; unpublish/delete must remove public profile state from CellScaffold.
- Remote configurations must not access vault, camera, microphone, calendar, contacts, nearby/bluetooth or Apple Intelligence without explicit user action per capability.
- Jitsi remains metadata only in v1: no embed and no camera/microphone request.
- No StoreKit, prepaid wording or external purchase call-to-action is exposed in v1.

## App Store Documentation Set

- [AppStoreReviewNotes_PersonalCopilotV1.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/AppStoreReviewNotes_PersonalCopilotV1.md)
- [PersonalCopilotV1_DataAndPermissionMap.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/PersonalCopilotV1_DataAndPermissionMap.md)
- [PersonalCopilotV1_CellContracts.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/PersonalCopilotV1_CellContracts.md)
- [PersonalCopilotV1_UGCModerationRunbook.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/PersonalCopilotV1_UGCModerationRunbook.md)
- [PersonalCopilotV1_ReleaseChecklist.md](/Users/kjetil/Build/Digipomps/HAVEN/Binding/Documentation/PersonalCopilotV1_ReleaseChecklist.md)
