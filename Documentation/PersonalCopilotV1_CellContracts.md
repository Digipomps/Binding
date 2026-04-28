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

## Nearby Signals Contract Boundary

Nearby Signals must keep a strict three-object boundary:

- `NearbySignalDraft`: Binding-owned mutable local draft. It may include native permission state, manual location fallback, local image picker state and publish preview, and must never be read directly by CellScaffold.
- `NearbySignalPublishRequest`: immutable consent payload sent only when the user explicitly publishes. It contains coarse location, sanitized image reference, purpose/interests, TTL and visibility.
- `NearbySignalSummary`: flat public nearby read model returned by directory search/detail. It contains no private draft state, exact GPS, EXIF metadata, private profile fields, chat state or relation data.

Native capture remains Binding-owned. CellScaffold receives only the publish request and returns summary/read models.

## NearbySignalPublisherCell

Purpose: accept an explicitly consented short-lived nearby signal payload and maintain the public nearby read model.

Minimum state:

- `myActiveSignals`
- `signalStatus`
- `publishStatus`
- `visibility`

Minimum actions:

- `publishSignal`
- `renewSignal`
- `unpublishSignal`
- `deleteSignal`
- `signalStatus`

Publish request:

```json
{
  "explicitPublishIntent": true,
  "signal": {
    "publishRequestKind": "NearbySignalPublishRequest",
    "signalID": "nearby-signal-uuid",
    "publisherRef": "requester-or-public-profile-ref",
    "text": "Interesting thing nearby",
    "imageAsset": "optional-sanitized-asset-ref",
    "imageMetadataStatus": "stripped before publish",
    "purposeRefs": ["purpose://collaboration"],
    "interestRefs": ["interest://ideas"],
    "coarseLocation": {
      "latitude": 59.913,
      "longitude": 10.752,
      "radiusMeters": 250,
      "precision": "manual-coarse",
      "coarseCell": "lat:59.913/lon:10.752/r:250"
    },
    "radiusMeters": 250,
    "createdAt": 1777399200,
    "expiresAt": 1777406400,
    "visibility": "publicNearby",
    "moderationStatus": "pending-safe-default",
    "explicitConsentRequired": true
  }
}
```

Required behavior:

- Reject publish without `explicitPublishIntent=true`.
- Reject exact/private location data; accept only coarse location and radius.
- Enforce a minimum radius of 250 meters and default expiry of 2 hours.
- Never read Binding-local drafts, photo metadata, chat state or relation state directly.
- `renewSignal` extends an active signal by another 2 hours.
- `unpublishSignal` removes directory visibility without deleting local audit history.
- `deleteSignal` removes public nearby state and discoverability records.

Published read model fields:

- `readModelKind="NearbySignalSummary"`
- `statusBadge` such as `Live`, `Reported` or `Unpublished`
- `distanceBucket`, `distanceText` and `radiusSummary`
- `expiresInSummary`, `expirySummary`, `createdAt`, `publishedAt`, `updatedAt`, `expiresAt`
- `openlyPublishedNotice`
- `rankingExplanation`

## NearbySignalDirectoryCell

Purpose: expose active openly published nearby signals with report/hide/block hooks.

Minimum state:

- `lastSearch`
- `selectedSignal`
- `directoryModerationStatus`
- `hiddenSignalCount`
- `blockedPublisherCount`
- `reportedSignalCount`

Minimum actions:

- `searchNearbySignals`
- `signalDetail`
- `reportSignal`
- `hideSignal`
- `blockPublisher`

Search request:

```json
{
  "query": "coffee",
  "center": {
    "latitude": 59.913,
    "longitude": 10.752,
    "radiusMeters": 1000,
    "precision": "manual-coarse"
  },
  "purposeRefs": ["purpose://collaboration"],
  "interestRefs": ["interest://ideas"]
}
```

Required behavior:

- Return only active `visibility="publicNearby"` signals that have not expired.
- Do not expose private drafts, exact GPS, EXIF metadata, private profiles, chat state or relation records.
- Ranking must be explainable from active expiry, coarse distance bucket and declared purpose/interest overlap.
- Hidden signals and blocked publishers must not reappear for that requester.
- Reported signals must return clear feedback and moderation status.

Directory result rows are `NearbySignalSummary` objects. Result cards should show text, optional sanitized image, purpose/interest refs, `statusBadge`, `distanceText`, `radiusSummary`, expiry and a short `rankingExplanation`.

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
- nearby signal publish requires explicit consent
- nearby signal search returns only active unexpired publicNearby signals
- nearby signal report/hide/block affects later search visibility
- matching cannot create chat without mutual approval
- chat invite/accept/decline/send/report/block works
- blocked user cannot continue chat
- meetingBridge metadata does not imply native permissions
- vault handoff does not expose local files without explicit consent
