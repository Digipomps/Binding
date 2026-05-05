# Personal Co-Pilot V1 UGC Moderation Runbook

This runbook covers user-generated content in Binding Personal Co-Pilot V1.

## UGC Surfaces

| Surface | UGC type | V1 exposure | Required safety controls |
| --- | --- | --- | --- |
| `PersonalProfileDraft` | Private profile draft | Local only until publish | Local delete/export; publish consent |
| `PersonalProfilePublisherCell` | Public profile text/links | Public after explicit publish | Filter, unpublish, delete, report handling |
| `PublicProfileDirectoryCell` | Public profile index | Search/discovery | Report profile, hide/block profile |
| `PersonalMatchmakingCell` | Match preferences and suggestions | Suggestions only | Block exclusion, no automatic chat |
| `PersonalChatHubCell` | Chat messages | Invite-only conversations | Filter, report message, block user, moderation status |

## Policy Position

- Personal Co-Pilot V1 is not random chat.
- Personal Co-Pilot V1 is not anonymous chat.
- Matching does not create chat automatically.
- Chat starts only after explicit invite and acceptance.
- Public profiles are published only after explicit consent.
- Blocked users must not be able to continue conversations with the blocker.

## User-Facing Controls

Every UGC surface must expose:

- Filter or reject objectionable content before publication/posting.
- Report content or profile.
- Block abusive users.
- Hide profile/conversation where applicable.
- Published support/contact information.
- Clear status after report/block actions.

## Report Flow

1. User taps `Report` on a message or public profile.
2. Binding sends `reportMessage` or `reportProfile` to the owning CellScaffold cell.
3. The cloud cell stores a moderation record with requester, target, reason, timestamp and content revision.
4. The UI shows a short confirmation and, where appropriate, offers hide/block.
5. Moderation status is reflected through `moderationStatus` or `directoryModerationStatus`.
6. Operator review decides whether to keep, hide, remove, suspend or escalate.

Minimum report record:

```json
{
  "reportID": "uuid",
  "surface": "chat|profile",
  "targetID": "message-or-profile-id",
  "targetRevision": "revision",
  "reporterID": "requester-id",
  "reason": "spam|harassment|sexual|violence|self-harm|other",
  "createdAt": "2026-04-23T10:00:00Z",
  "status": "received"
}
```

## Block Flow

1. User taps `Block`.
2. Binding sends `blockUser` or `blockProfile`.
3. CellScaffold writes requester-scoped block state.
4. Public directory excludes blocked profile for the requester.
5. Matchmaking excludes blocked users.
6. Chat hub prevents blocked users from sending further messages to the blocker or entering new conversations with the blocker.
7. Binding shows a reversible or support-mediated unblock path if supported.

## Filtering Expectations

Filtering should run before public profile publish and before chat message send.

Minimum filter outcomes:

- `allowed`: content may be posted.
- `needsReview`: content is held or posted with limited visibility according to policy.
- `rejected`: content is not posted; user receives safe explanation.

Filtering should be conservative for:

- harassment and targeted abuse
- sexual content
- threats and violence
- spam/scams
- doxxing or private information
- illegal goods/services
- self-harm encouragement

## Operator Review

Required operator capabilities before public launch:

- View reports by status and severity.
- Inspect reported profile/message revision.
- Hide or remove public profile.
- Hide or remove message.
- Mark report resolved.
- Suspend or restrict abusive account/profile where account system supports it.
- Export moderation audit for App Review/support follow-up.

Suggested response targets:

- High-risk safety reports: same day.
- Abuse/spam reports: within 24 hours.
- General quality reports: within 48 hours.

## Contact Information

App Store metadata and in-app Help/Privacy surfaces must publish a support contact for UGC concerns.

Required before submission:

- Support URL or email in App Store Connect.
- In-app support/privacy path.
- Operator mailbox or dashboard checked during review period.

## Audit Events

Binding `PersonalPrivacyAudit` should record:

- profile publish consent
- profile unpublish/delete request
- match consent request/accept/decline
- chat invite/accept/decline
- message report
- user block/unblock
- remote configuration load
- native permission grant/deny

## Test Drills

Before App Store submission, run drills for:

- Report a public profile and confirm report status.
- Hide/block a public profile and confirm it disappears from directory and matches.
- Report a chat message and confirm moderation status changes.
- Block a chat participant and confirm they cannot continue the conversation.
- Attempt to match with a blocked user and confirm the suggestion is excluded.
- Attempt to send rejected content and confirm it is not posted.

## Open Items

- Final moderation operator dashboard or admin route must be implemented in CellScaffold.
- Final support contact must be inserted before App Store submission.
- Final privacy policy must describe moderation data retention and deletion.
