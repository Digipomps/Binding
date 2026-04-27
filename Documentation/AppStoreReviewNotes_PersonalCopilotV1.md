# App Store Review Notes: Personal Co-Pilot V1

This document is the working source for App Store Connect review notes for Binding Personal Co-Pilot V1.

## Review Summary

Binding is a curated Personal Co-Pilot app. It helps a user organize profile information, ideas, projects, match intent, invitation-based chat and meeting intent surfaces. It is not submitted as a conference demo, plugin marketplace, arbitrary app host or general mini-app store.

The first App Store build exposes only the Personal Co-Pilot V1 surface:

- `Personal Home`
- `My Profile`
- `Publish Public Profile`
- `Matches`
- `Invite Chat`
- `Vault / Ideas`
- `Meeting Intent`
- `Apple Intelligence`
- `Entity Scanner`
- `Workflow Studio`

Conference, sponsor, admin, control tower, demo launcher and conference chat configurations are not part of the default App Store user experience. They remain development/debug surfaces only and are not described in App Store metadata.

## Suggested App Review Notes Text

```text
Binding is submitted as a curated Personal Co-Pilot app.

The app can load CellConfigurations from our approved CellScaffold host, but the App Store build is allowlisted to Personal Co-Pilot V1 configurations only. The visible V1 scope is profile drafting/publishing, opt-in public profile discovery, consent-based matching, invite-only chat, local vault/idea/project organization, meeting intent planning, Apple Intelligence-related local actions and entity scanning.

The app is not a general plugin marketplace and does not expose arbitrary third-party mini apps. Every remote configuration shown in the App Store build must include appStoreScope="personal-copilot-v1", policy metadata, a universalLink and a reviewSummary. Non-allowlisted configurations are hidden or shown as unavailable.

User-generated content surfaces are limited to public profiles and invite-only chat. These surfaces include filtering, reporting and blocking hooks. Matching suggestions do not create chats automatically; chat requires explicit invite/accept consent.

The app does not include prepaid credits, external purchase calls to action, StoreKit UI or in-app purchase in V1.

Remote configurations do not receive native permissions automatically. Camera, microphone, calendar, contacts, nearby/Bluetooth, local vault/file access and Apple Intelligence-related capabilities require explicit user action and platform permission flow where applicable. V1 meeting/Jitsi support is metadata-only and does not request camera or microphone access.

If account creation or sign-in is enabled for the review build, the app provides in-app account deletion and data export/deletion hooks.
```

## Reviewer Access

- Provide a review account only if the submitted build requires login for profile publish, matching or chat.
- If login is optional, provide a fully functional no-login demo path for local vault, local profile draft and non-publishing surfaces.
- Backend services must be live and reachable during review.
- If a sample public profile, match suggestion or invite-only chat is needed, seed CellScaffold with review-safe fixture users.

## V1 Non-Goals

- No conference demo in default first-run UX.
- No `Conference*` catalog entries in App Store mode.
- No sponsor/admin/control tower surfaces.
- No conference chat.
- No arbitrary remote app/plugin catalog.
- No random chat, anonymous chat, Chatroulette-style discovery or hot-or-not voting.
- No automatic chat creation from matching.
- No Jitsi embed in V1.
- No native camera/microphone request for meeting metadata in V1.
- No prepaid credits, external payment, crypto, license keys or external digital purchase CTA.

## Policy Mapping

| App Store area | Binding V1 behavior | Required evidence |
| --- | --- | --- |
| Safety / UGC | Public profiles and chat expose report/block/filter hooks. Chat is invite-only. | UGC moderation runbook, chat/report/block tests. |
| Payments | No digital unlocks, credits, prepaid wording or external purchase CTA in V1. | Payment gate checklist, screenshot review. |
| Remote software / CellConfigurations | Catalog is allowlisted to `personal-copilot-v1`, approved hosts and review metadata. | Catalog policy tests, App Store catalog fixture. |
| Native APIs | Remote configs do not get native capabilities without explicit user action and permission. | Data/permission map, denied-permission tests. |
| Privacy | Local drafts stay local until publish consent. Delete/export hooks are documented. | Data map, profile publish/unpublish/delete tests. |
| Account deletion | If account creation exists, deletion must be available in-app. | Account delete path and review notes. |

## App Store Connect Metadata Guardrails

- App name/subtitle/screenshots should describe the Personal Co-Pilot use case.
- Do not mention conference demo, event sponsor tools, admin control tower, experimental agent provisioning or hidden catalog expansion.
- If showing chat screenshots, show invite-only chat with visible report/block affordances.
- If showing profile publishing, show explicit consent before publication.
- If showing meetings, describe meeting intent planning rather than video conferencing.
- If mentioning AI, describe the user-facing task and privacy boundary; do not imply Apple Intelligence access is granted to remote configurations.

## Required Before Submission

- Privacy policy URL is present in App Store Connect and reachable in-app.
- Contact/support URL or email is present for UGC reports.
- Account deletion path is present if accounts can be created.
- TestFlight/App Review backend is live and seeded with safe fixtures.
- The submitted build has conference/debug menu enablement disabled.
- App Store mode hides non-allowlisted remote CellConfigurations.
- Review notes include any non-obvious remote CellConfiguration behavior.

## Source References

Referenced against the official Apple App Review Guidelines on 2026-04-23:

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) 1.2: user-generated content filtering, reporting, blocking and contact expectations.
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) 3.1.1: digital feature/content unlocks must use in-app purchase.
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) 4.7: remote software/chatbot/plugin surfaces require compliance, metadata/indexing, moderation and explicit permission boundaries.
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) 5.1.1: privacy policy, consent, data minimization and account deletion expectations.
