# Device Action Relay

`DeviceActionRelay` gir `HAVENAgentD` en enkel bro mellom lokale agenter og Binding på telefonen:

- lokale agenter eller GUI-automatisering kan droppe JSON-filer i `~/Library/Application Support/HAVENAgent/Inbox/Requests/`
- `haven-agentd` normaliserer filen og oppretter en ekte staging-ticket via `cell://.../NotificationOutbox.createTicket`
- Binding på telefonen kan svare med prompt eller approval/reject via `AgentConversationInbox`
- `haven-agentd` skriver replies til `~/Library/Application Support/HAVENAgent/Inbox/Replies/`

## Kataloger

- `Inbox/Requests`: nye innkommende action-requests som skal publiseres
- `Inbox/Processed`: requests som ble publisert uten lokal feil
- `Inbox/Failed`: requests som ikke kunne publiseres eller manglet target-data
- `Inbox/Replies`: svar som kom tilbake fra Binding via `AgentConversationInbox`

## Request-format

Eksempel:

```json
{
  "id": "approval-continue-codex-001",
  "responseMode": "approval",
  "title": "Continue coding",
  "message": "Approve if the assistant should continue the staging fix.",
  "purpose": "purpose://agent-approval",
  "purposeDescription": "Operator approval before a code assistant continues.",
  "interests": ["approval", "automation", "codex"],
  "conversationId": "codex-session-1",
  "jobId": "job-42",
  "sourceCellEndpoint": "cell:///AgentConversationInbox",
  "payload": {
    "source": "codex"
  }
}
```

Følgende felter kan også settes per request:

- `participantId`
- `deviceId`
- `ticketId`
- `requiredActionKey`
- `naturalLanguageIntent`
- `sourceEventPath`
- `sourceEventTopic`
- `triggerEvent`
- `ttlSeconds`

Hvis `participantId` eller `deviceId` ikke settes i filen, brukes eventuelle defaults fra `deviceActionRelay` i agent-konfigen.

Hvis `conversationId` eller `jobId` mangler, fyller relayet dem ut med request-id slik at svar fra telefonen kan korreleres deterministisk.

Når en `deviceId` er kjent, sender relayet den både på toppnivå og som
`payload.deviceId`. CellScaffold sin nåværende `NotificationOutboxCell` bruker
`payload.deviceId` for direkte enhetsoppslag før den faller tilbake til
participant/platform-match.

## Konfig

`config.json` kan nå ha en `deviceActionRelay`-seksjon:

```json
{
  "deviceActionRelay": {
    "enabled": true,
    "notificationOutboxEndpoint": "cell://staging.haven.digipomps.org/NotificationOutbox",
    "defaultParticipantID": "binding-participant",
    "defaultDeviceID": "binding-phone",
    "defaultTTLSeconds": 900,
    "conversationEndpoint": "cell://staging.haven.digipomps.org/AgentConversationInbox"
  }
}
```

Viktig:

- relayet oppretter tickets direkte i staging-kontrakten, ikke via en lokal/mock adapter
- eldre `publishURL`-konfig blir fortsatt lest som fallback og mappes til riktig staging-host
- approval-/prompt-svar kommer tilbake gjennom `AgentConversationInbox`, ikke gjennom `callback/submit`
- ved live-feil pakkes remote resolver-/`createTicket`-feil med endpoint-kontekst slik at `Inbox/Failed/*.json` viser om feilen skjedde før eller under `NotificationOutbox.createTicket`
