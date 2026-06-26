# Staging Resource Locations

This file records external resource files and runtime-only secret material used
by the Binding phone approval loop and CellScaffold staging. Do not commit file
contents, private keys, bearer tokens, or full `.env` values here.

## Resource Placement Rule

For every external resource file copied into staging, document:

- local source path, when known
- staging host path
- container/runtime path, when mounted into Docker
- relevant `.env` keys
- non-secret verification command
- owner or permission notes when they matter

## APNS Provider Key

Purpose:

- Allows CellScaffold staging to authenticate to APNS and send visible iOS
  notifications to Binding development builds installed from Xcode.

Current file locations:

| Location | Path |
| --- | --- |
| Local source | `/Users/Shared/Apple Connect/AuthKey_ZPJC567ND5.p8` |
| Staging host | `/home/ops/CellScaffold/.secrets/AuthKey_ZPJC567ND5.p8` |
| Docker runtime mount | `/run/secrets/apns-auth-key.p8` |

Runtime config lives in:

```text
/home/ops/CellScaffold/.env
```

Relevant env keys:

```text
APNS_TEAM_ID=<set in staging .env>
APNS_KEY_ID=ZPJC567ND5
APNS_BUNDLE_ID=org.digipomps.havenplayground
APNS_USE_SANDBOX=true
APNS_PRIVATE_KEY_PATH=/run/secrets/apns-auth-key.p8
```

The Docker compose mount maps the staging host file to the runtime path:

```text
/home/ops/CellScaffold/.secrets/AuthKey_ZPJC567ND5.p8 -> /run/secrets/apns-auth-key.p8
```

Verification without printing secret contents:

```bash
ssh -i "$HOME/.ssh/id_ed25519_hetzner" -o IdentitiesOnly=yes ops@89.167.90.101 \
  'cd /home/ops/CellScaffold &&
   test -s .secrets/AuthKey_ZPJC567ND5.p8 &&
   docker exec cellscaffold-app-1 sh -lc "test -s \"$(printenv APNS_PRIVATE_KEY_PATH)\""
  '
```

Expected result:

- command exits `0`
- no key contents are printed

## Agent Relay Token

Purpose:

- Allows `HAVENAgentD` or an operator-controlled staging smoke command to
  create a `NotificationOutbox` ticket through:

```text
https://staging.haven.digipomps.org/conference-mvp/api/agent/device-action
```

Runtime config lives in:

```text
/home/ops/CellScaffold/.env
```

Relevant env key:

```text
HAVEN_AGENT_RELAY_TOKEN=<set in staging .env>
```

Verification without printing the token:

```bash
curl -i -sS -X POST \
  -H 'Content-Type: application/json' \
  -d '{}' \
  https://staging.haven.digipomps.org/conference-mvp/api/agent/device-action
```

Expected result:

- `401 Unauthorized`
- JSON reason says `Invalid agent relay token.`

## Binding Device Registration

Binding development builds currently use:

```text
PRODUCT_BUNDLE_IDENTIFIER=org.digipomps.havenplayground
aps-environment=development
```

For Xcode-installed iPhone builds, staging must use:

```text
APNS_BUNDLE_ID=org.digipomps.havenplayground
APNS_USE_SANDBOX=true
```

Binding registers the phone with:

```text
https://staging.haven.digipomps.org/conference-mvp/api/device/register
```

Default participant id:

```text
binding-participant
```

The phone must complete this registration before staging can send an APNS
ticket. A relay test that returns:

```text
Unable to resolve an active device with a push token for participant binding-participant.
```

means APNS config may be correct, but the phone has not registered a live
device token in `DeviceRegistrationCell`.
