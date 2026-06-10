# Personal Co-Pilot V1 Cell Contracts

This document defines the Binding-to-CellScaffold contract for Personal Co-Pilot V1. The intent is to reuse existing CellProtocol and CellScaffold cells wherever possible, adding thin `Personal*` facades only when product policy or App Store metadata needs a curated surface.

## Contract Rules

- Reuse existing utility cells instead of forking them into Binding.
- Use CellProtocol `ChatCell` semantics for chat where available.
- Keep generic moderation, profile publish, meeting intent and catalog policy metadata suitable for CellProtocol extraction.
- Remote cells do not request native permissions; they can only express desired capability metadata for Binding to gate locally.
- All state-changing calls must be requester-scoped and auditable.
- Failed or unavailable remote calls must return recoverable error state, not dead-end UI copy.

## Shared Configuration Metadata

Every App Store-visible CellConfiguration returned by CellScaffold must include metadata equivalent to:

```json
{
  "appStoreScope": "personal-copilot-v1",
  "policyCategory": "profile|chat|matching|vault|meeting|ai|scanner|workflow|catalog",
  "surfaceFamily": "identity|relationship|content|intelligence|governance",
  "presentationClass": "detail|list|grid|hero|form",
  "ageRatingHint": "4+|9+|12+|17+",
  "requiresLogin": true,
  "requiresUserGeneratedContentModeration": true,
  "nativePermissionRequests": [],
  "universalLink": "https://...",
  "reviewSummary": "Short App Review readable explanation of this surface."
}
```

Binding currently encodes these as policy hints/discovery interests where the underlying `CellConfiguration` model does not have first-class fields. CellScaffold should preserve both machine-readable metadata and renderer-compatible hints until the schema is promoted.

## PersonalCopilotConfigurationCatalog

Purpose: return only App Store-approved Personal Co-Pilot V1 configurations.

Minimum read endpoints:

- `entries`
- `entries.allowed`
- `entries.unavailable`
- `entryDetail`
- `policySummary`

Minimum behavior:

- Include only `appStoreScope="personal-copilot-v1"`.
- Exclude `Conference*`, demo launcher, sponsor, admin, control tower and conference chat entries.
- Include universal links and review summaries for each visible configuration.
- Return an honest unavailable reason for hidden entries if Binding asks for a specific known ID.

Suggested unavailable payload:

```json
{
  "configurationID": "ConferenceDemoLauncher",
  "available": false,
  "reason": "This configuration is not included in Binding Personal Co-Pilot V1 for App Store."
}
```

## PersonalProfilePublisherCell

Purpose: accept an explicitly consented profile publish payload from Binding and maintain the public read model.

Minimum state:

- `publishedProfile`
- `publishStatus`
- `lastPublishedRevision`
- `visibility`
- `deleteStatus`

Minimum actions:

- `publishProfile`
- `unpublishProfile`
- `deleteProfile`
- `profileStatus`

Publish request:

```json
{
  "requesterID": "identity-or-account-id",
  "draftRevision": "local-draft-revision",
  "consentToken": "explicit-user-consent-token",
  "profile": {
    "displayName": "Example User",
    "headline": "Personal Co-Pilot user",
    "bio": "Short public text",
    "interests": ["ideas", "projects"],
    "publicLinks": []
  }
}
```

Required behavior:

- Reject publish without explicit consent.
- Never read a private local draft directly.
- Unpublish removes directory visibility.
- Delete removes public profile and discoverability records.
- Return revision-aware status so Binding can show whether the public profile matches the local draft.

## PublicProfileDirectoryCell

Purpose: expose searchable public profile read models with report/hide/block hooks.

Minimum endpoints:

- `searchProfiles`
- `profileDetail`
- `reportProfile`
- `hideProfile`
- `blockProfile`
- `directoryModerationStatus`

Required behavior:

- Only published profiles are searchable.
- Hidden/blocked profiles do not reappear for that requester.
- Reported profiles remain visible or hidden according to moderation policy, but the requester gets clear feedback.
- Directory entries must not expose private draft fields.

## PersonalMatchmakingCell

Purpose: produce consent-based match suggestions without starting chat.

Minimum state:

- `matchSuggestions`
- `matchConsentStatus`
- `pendingMatchRequests`

Minimum actions:

- `refreshSuggestions`
- `requestMatchConsent`
- `acceptMatchConsent`
- `declineMatchConsent`
- `clearMatchSuggestion`

Required behavior:

- Suggestions may use published profile data and explicit preferences only.
- No chat thread is created until both parties consent.
- A declined match cannot silently create a later chat.
- Blocked users must be excluded from suggestions.

## PersonalChatHubCell

Purpose: own shared invite-only 1:1 and small-group chat state using the CellProtocol chat contract where possible.

Minimum state:

- `threads`
- `currentThread`
- `composer`
- `messages`
- `invites`
- `blockedUsers`
- `moderationStatus`
- `meetingBridge`

Minimum actions:

- `invite`
- `acceptInvite`
- `declineInvite`
- `sendComposedMessage`
- `clearComposer`
- `reportMessage`
- `blockUser`
- `unblockUser`

Required behavior:

- Chat is invite-only.
- Sending is allowed only after invite acceptance.
- Blocked users cannot continue the conversation.
- Reported messages receive moderation state.
- Filtering hooks run before content is posted.
- Existing CellProtocol `ChatCell` encryption, audience and invite lifecycle should be reused rather than reimplemented.

Jitsi-ready metadata for V1:

```json
{
  "meetingBridge": {
    "provider": "jitsi",
    "joinURL": "https://meet.example/room",
    "roomName": "room-id",
    "scheduledAt": "2026-05-01T10:00:00Z",
    "requiresCameraMicrophoneConsent": true,
    "v1RenderMode": "placeholder"
  }
}
```

Binding must render this as metadata/placeholder in V1 and must not request camera or microphone merely because this metadata exists.

## PersonalAgendaContextCell

Purpose: local Binding-owned context cell that answers "today/next agenda" questions from Calendar and Reminders after explicit user consent, and exposes weighted purpose signals for Perspective.

Minimum state:

- `agenda.state`
- `agenda.today`
- `agenda.next`
- `agenda.items`
- `agenda.summary`
- `agenda.permissionStatus`
- `agenda.purposeSignals`

Minimum actions:

- `agenda.refresh`
- `agenda.answerQuery`
- `agenda.requestAccess`
- `agenda.requestCalendarAccess`
- `agenda.requestReminderAccess`
- `agenda.publishPerspectiveSignals`
- `agenda.clearCache`

Required behavior:

- Calendar and Reminders access is mediated by the local Binding cell only; remote configurations never receive native permission.
- `agenda.answerQuery` must be side-effect free and return an honest `requiresConsent` status when native data cannot be read.
- If multiple conference aspects are plausible, such as participant, organizer, sponsor or exhibitor, return `needsClarification=true` and a clarifying question instead of assuming the role.
- Purpose/interest weighting is published to Perspective only through the explicit `agenda.publishPerspectiveSignals` action.

## PersonalMeetingCoordinatorCell

Purpose: coordinate meeting intents and proposed times without native calendar/camera/mic access.

Minimum state:

- `meetingIntent`
- `proposedTimes`
- `participants`
- `meetingBridge`
- `coordinationStatus`

Minimum actions:

- `proposeTimes`
- `acceptTime`
- `declineTime`
- `updateMeetingIntent`
- `clearMeetingIntent`

Required behavior:

- No native calendar write.
- No native camera/microphone assumption.
- Return data Binding can present locally and optionally save to Calendar only after explicit user action.

## Vault Handoff

Purpose: allow remote Personal Co-Pilot configurations to reference vault-related tasks without direct vault access.

Minimum behavior:

- Remote configuration may request a vault handoff intent.
- Binding decides whether to open/select/write local vault content.
- Remote cells never receive raw local vault paths or file contents unless the user explicitly exports/shares them.

Suggested handoff intent:

```json
{
  "intent": "create-note",
  "title": "Project idea",
  "suggestedBody": "Draft text",
  "requiresLocalVaultConsent": true
}
```

## Error Semantics

All cloud cells should return:

- `status`: `ok`, `pending`, `blocked`, `requiresConsent`, `unavailable`, `rejected` or `error`
- `userMessage`: short safe UI text
- `debugMessage`: optional developer-only detail
- `retryable`: boolean
- `revision`: current state revision when relevant

## Contract Tests

CellScaffold should provide tests for:

- catalog only returns `personal-copilot-v1`
- conference entries are hidden
- profile publish requires consent
- unpublish/delete removes public directory presence
- matching cannot create chat without mutual approval
- chat invite/accept/decline/send/report/block works
- blocked user cannot continue chat
- meetingBridge metadata does not imply native permissions
- vault handoff does not expose local files without explicit consent
