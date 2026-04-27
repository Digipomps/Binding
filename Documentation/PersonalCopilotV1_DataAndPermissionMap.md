# Personal Co-Pilot V1 Data And Permission Map

This map defines what Binding Personal Co-Pilot V1 may read, write, publish and request on device.

## Default Principles

- Local draft data stays local until the user takes an explicit publish/share action.
- Remote CellConfigurations receive no native permission by default.
- App Store mode shows only configurations scoped to `appStoreScope="personal-copilot-v1"` from approved hosts.
- Denied permissions must leave the app usable with an honest reduced-capability state.
- Conference/demo/admin/sponsor/control tower data is out of V1 scope.
- Payment, prepaid and digital credit data is out of V1 scope.

## Cell Map

| Cell | Owner | Data handled | Local or cloud | Native permission | Denied behavior | V1 status |
| --- | --- | --- | --- | --- | --- | --- |
| `PersonalIdentity` | Binding | requester identity, public/private identity state, export/delete hooks | Local, with optional account/cloud linkage | None by default | Local-only identity remains usable where login is not required | Binding local cell registered |
| `PersonalProfileDraft` | Binding | private profile draft, publish preview, publish consent state | Local until publish | None by default | Draft editing remains local; publish disabled if remote account/backend unavailable | Binding local cell registered |
| `PersonalProfilePublisherCell` | CellScaffold | explicitly published profile payload, public profile read model | Cloud | None; receives only explicit publish payload | Publish fails with recoverable error; local draft remains intact | Must be implemented in CellScaffold |
| `PublicProfileDirectoryCell` | CellScaffold | searchable public profile index, report/hide/block state | Cloud | None | Directory can be unavailable without affecting local draft/vault | Must be implemented in CellScaffold |
| `PersonalMatchmakingCell` | CellScaffold | match preferences, published-profile-derived suggestions, mutual consent state | Cloud | None | Matching unavailable; no chat is created | Must be implemented in CellScaffold |
| `PersonalChatClient` | Binding | local composer draft, selected invite, report/block UI state, Jitsi placeholder metadata | Local client state plus cloud chat handoff | Notifications optional later; no camera/mic in V1 | Composer remains usable only for accepted invites; denied notifications do not block chat | Binding local cell registered |
| `PersonalChatHubCell` | CellScaffold | invite-only conversation state, messages, moderation status, report/block records | Cloud | None; uses CellProtocol chat contract | Chat unavailable or read-only if backend unavailable; blocked users cannot continue | Must be implemented in CellScaffold |
| `Vault` / `PersonalVault` | Binding / CellProtocol | local notes, ideas, projects, optional vault paths | Local file/vault access | File/vault picker or explicit user-selected folder | User can keep using non-file-backed local state or choose a folder later | Existing utility cell reused |
| `PersonalMeetingIntent` | Binding | meeting title, participants, proposed time, meetingBridge metadata placeholder | Local client state | Calendar/EventKit only after explicit user action; no camera/mic in V1 | Meeting intent remains local; calendar write disabled | Binding local cell registered |
| `PersonalMeetingCoordinatorCell` | CellScaffold | suggested times, meeting intent coordination, meetingBridge metadata | Cloud | None | Suggestions unavailable; local meeting intent remains editable | Must be implemented in CellScaffold |
| `PersonalPrivacyAudit` | Binding | audit entries for publish, match consent, chat invite, remote config load, permission grant/deny | Local | None | Audit remains local; export may depend on file share/picker | Binding local cell registered |
| `PersonalCopilotConfigurationCatalog` | CellScaffold | allowlisted CellConfiguration metadata and universal links | Cloud | None | Binding hides unavailable entries and can fall back to local Personal Co-Pilot seeds | Must be implemented in CellScaffold |
| `AppleIntelligence` | Binding / CellProtocol Apple adapter | local Apple Intelligence related actions and generated content where supported | Local/device | System capability and explicit user action | Surface explains unavailable/denied capability | Existing local cell retained |
| `EntityScanner` | Binding / CellProtocol Apple adapter | scan session state, detected entities, user-selected output | Local/device | Camera / scanning permission when user starts scanner | Scanner unavailable; non-scanner app surfaces continue | Existing local cell retained |
| `WorkflowStudio` | Binding | user-authored workflows/configuration editing state | Local, with explicit import/export/publish later | File/vault only after explicit action | Editing remains local; external write disabled | Existing local cell retained |
| `Porthole` | Binding | current CellConfiguration rendering/editing state | Local with explicit remote references | None by itself | Remote references can be unavailable/read-only honestly | Existing local cell retained |

## Native Capability Gates

| Capability | Allowed trigger | Remote config access | Required UX |
| --- | --- | --- | --- |
| Camera / scanning | User taps scanner/start scan in local scanner surface | Never direct; Binding adapter mediates | Purpose string, denied state, no silent retry |
| Microphone | Out of V1 except future meeting/video surfaces | Never in V1 | No request in V1 meetingBridge placeholder |
| Calendar/EventKit | User explicitly adds/saves a meeting intent to calendar | Never direct; Binding adapter mediates | Purpose string, fallback to local meeting intent |
| Contacts | Out of V1 unless later invite flow explicitly needs picker | Never direct | Use picker/individual selection; no contact database |
| Nearby/Bluetooth | User starts entity scanner/nearby capability | Never direct | Purpose string and safe stopped state |
| Local vault/files | User selects vault/folder/file or imports/exports | Never direct; Binding-owned vault adapter mediates | File picker/folder consent; unavailable state if denied |
| Apple Intelligence | User invokes local Apple Intelligence action | Never direct | Local explanation and denied/unavailable fallback |
| Notifications | User opts in to chat/meeting reminders later | Remote may request intent only; Binding asks permission | Chat works without notifications |

## Publish And Deletion Rules

- Profile drafts are private until `publishProfile` is invoked after explicit consent.
- `unpublishProfile` must remove the public read model from directory/search.
- `deleteProfile` must remove public profile state and associated discoverability records.
- Account deletion, when accounts are enabled, must invoke local delete/export hooks and CellScaffold deletion routes.
- Audit entries should record publish, unpublish, delete, match consent, chat invite, report/block and permission grant/deny.

## Remote Configuration Policy

Every shipping remote configuration must carry:

- `appStoreScope="personal-copilot-v1"`
- `policyCategory`
- `surfaceFamily`
- `presentationClass`
- `ageRatingHint`
- `requiresLogin`
- `requiresUserGeneratedContentModeration`
- `nativePermissionRequests`
- `universalLink`
- `reviewSummary`

Binding should hide entries that are not scoped, are from unapproved hosts or contain conference/demo/admin/sponsor/control tower intent.

## Open Implementation Items

- CellScaffold must implement the cloud cells and fixture routes listed in `PersonalCopilotV1_CellContracts.md`.
- The in-app privacy policy/support/account deletion surfaces must be wired to the final account system.
- Purpose strings for iOS permissions must be reviewed in the submitted target before App Store upload.
- TestFlight review fixtures must be seeded with safe profile, match, invite chat and meeting intent examples.
