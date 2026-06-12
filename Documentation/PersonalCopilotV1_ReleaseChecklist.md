# Personal Co-Pilot V1 Release Checklist

This checklist is the App Store gate for Binding Personal Co-Pilot V1.

## Scope Lock

- [ ] App metadata describes Personal Co-Pilot, not conference demo.
- [ ] Default menus show only Personal Co-Pilot V1 entries.
- [ ] No `Conference*`, demo launcher, sponsor, admin, control tower or conference chat labels in fresh install UX.
- [ ] Conference/debug enablement is off in the submitted build.
- [ ] No prepaid, credits, external purchase CTA, crypto or StoreKit UI in V1.
- [ ] Jitsi is metadata/placeholder only; no embed in V1.

## Catalog Gate

- [ ] `PersonalCopilotConfigurationCatalog` returns only `appStoreScope="personal-copilot-v1"`.
- [ ] Each visible remote config has `policyCategory`, `ageRatingHint`, `requiresLogin`, `requiresUserGeneratedContentModeration`, `nativePermissionRequests`, `universalLink` and `reviewSummary`.
- [ ] Non-allowlisted configs are hidden or shown as unavailable with honest copy.
- [ ] Approved host list is explicit.
- [ ] Search/recommendations cannot surface conference/admin/sponsor/control tower configs.

## Profile Gate

- [ ] Profile draft is local by default.
- [ ] Publish requires explicit consent.
- [ ] Publish writes only the approved public payload.
- [ ] Unpublish removes directory visibility.
- [ ] Delete removes public profile state.
- [ ] Account deletion is available in-app if accounts can be created.
- [ ] Export/delete hooks are documented and tested.

## Matching Gate

- [ ] Match suggestions use only published profile data and explicit preferences.
- [ ] Match suggestions cannot create chat automatically.
- [ ] Chat starts only after mutual approval.
- [ ] Blocked users are excluded from future suggestions.
- [ ] Declined match does not silently reappear as an active chat.

## Chat Gate

- [ ] Chat is invite-only.
- [ ] Co-Pilot speech input is explicit push-to-talk/dictation only.
- [ ] Speech transcript can fill the composer without sending a message.
- [ ] Speech transcript analysis remains side-effect-free until the user chooses a concrete action.
- [ ] `invite` works.
- [ ] `acceptInvite` works.
- [ ] `declineInvite` works.
- [ ] `sendComposedMessage` works only after invite acceptance.
- [ ] `clearComposer` works.
- [ ] `reportMessage` works.
- [ ] `blockUser` works.
- [ ] `blockedUsers` state is visible to Binding.
- [ ] `moderationStatus` is visible to Binding.
- [ ] Blocked user cannot continue conversation.
- [ ] Filtering runs before message post.

## UGC Gate

- [ ] Public profile report works.
- [ ] Public profile hide/block works.
- [ ] Chat message report works.
- [ ] Chat user block works.
- [ ] Published support/contact information exists.
- [ ] Moderation operator path exists for reports.
- [ ] UGC retention/deletion policy is documented in privacy policy.

## Vault Gate

- [ ] Local note/project write works without staging backend.
- [ ] Remote config cannot access vault without explicit user action.
- [ ] Vault/file picker denial leaves app usable.
- [ ] Remote vault handoff does not expose raw local paths by default.

## Hardware And Permission Gate

- [ ] Entity scanner shows purpose copy before camera/scanner use.
- [ ] Entity scanner works when allowed.
- [ ] Entity scanner denied state is honest and non-fatal.
- [ ] Co-Pilot Chat requests microphone and speech recognition only after an explicit speech-input tap.
- [ ] Microphone/speech denial leaves the text composer usable.
- [ ] Co-Pilot speech input has no wake phrase, background listening or autosend.
- [ ] Apple Intelligence surface handles unsupported/denied/unavailable state.
- [ ] Calendar/EventKit is requested only after explicit meeting action.
- [ ] Calendar denial leaves local meeting intent usable.
- [ ] Notifications, if present, are optional and not required for chat.
- [ ] Remote configurations never receive native permissions directly.

## Meeting/Jitsi Gate

- [ ] `meetingBridge.provider="jitsi"` metadata can render.
- [ ] `joinURL`, `roomName`, `scheduledAt` and `requiresCameraMicrophoneConsent` can render.
- [ ] V1 render is placeholder/open-later only.
- [ ] No camera/microphone permission request occurs from meetingBridge metadata alone.

## Review Assets

- [ ] App Store Connect privacy policy URL is set.
- [ ] In-app privacy/support path is reachable.
- [ ] App Review notes explain curated CellConfigurations.
- [ ] App Review notes state that arbitrary plugins/mini apps are not exposed.
- [ ] App Review notes explain UGC report/block/filter.
- [ ] App Review notes explain native permission boundaries.
- [ ] Review account or demo mode is available.
- [ ] Backend services are live during review.
- [ ] Safe fixture data is seeded.

## Binding Regression Commands

Run before submission:

```sh
xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

```sh
xcodebuild -quiet -project Binding.xcodeproj -scheme Binding -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test -only-testing:BindingTests/BindingTests/personalCopilotV1MenuConfigurationsAreScopedAndConferenceFree -only-testing:BindingTests/BindingTests/personalCopilotInviteChatExposesSafetyActionsAndJitsiPlaceholder -only-testing:BindingTests/BindingTests/personalCopilotV1PolicyRejectsConferenceAndUnapprovedHosts -only-testing:BindingTests/BindingTests/personalCopilotProfilePublishingCarriesAppStoreReviewMetadata
```

```sh
zsh Scripts/run_skeleton_parity_suite.sh local /tmp/binding-personal-copilot-v1-parity
```

Add CellScaffold commands when the cloud cells land:

```sh
# TODO(CellScaffold): run personal-copilot-v1 HTTP fixture tests
# TODO(CellScaffold): run personal-copilot-v1 CellConfiguration parity fixtures
```

## Submission Blockers

- [ ] Any conference/demo/admin/sponsor/control tower label appears in App Store default UX.
- [ ] Catalog can surface non-allowlisted remote configurations.
- [ ] Public profile or chat lacks report/block/filter.
- [ ] Match can create chat without mutual approval.
- [ ] Remote config can access camera, microphone, contacts, calendar, nearby/Bluetooth, vault/files or Apple Intelligence without explicit Binding-mediated consent.
- [ ] Payment/prepaid/external purchase wording appears in V1.
- [ ] Account creation exists without in-app account deletion.
- [ ] Backend review fixtures are unavailable.

## Apple Guideline References

Referenced against the official [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) on 2026-04-23:

- 1.2 for UGC filter/report/block/contact requirements.
- 3.1.1 for digital purchases and in-app purchase boundaries.
- 4.7 for remote software/chatbot/plugin metadata, indexing and compliance boundaries.
- 5.1.1 for privacy policy, consent, data minimization and account deletion.
