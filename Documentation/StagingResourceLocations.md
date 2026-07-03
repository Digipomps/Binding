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

Local `HAVENAgentD` runtime config should not contain the token value. For
local operator smoke tests, store only the secret file path in
`deviceActionRelay.agentRelayTokenPath`:

| Location | Path |
| --- | --- |
| Staging source | `/home/ops/CellScaffold/.env` |
| Local runtime secret | `/Users/kjetil/Library/Application Support/HAVENAgent/Secrets/agent-relay-token` |
| Local config reference | `deviceActionRelay.agentRelayTokenPath` |

The local secret file must contain only the relay token, with no extra JSON or
shell syntax. Keep permissions restricted to the local user.

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

Local secret verification without printing the token:

```bash
test -s "$HOME/Library/Application Support/HAVENAgent/Secrets/agent-relay-token"
```

Expected result:

- command exits `0`
- no token contents are printed

## Staging Nginx Proxy Config

Purpose:

- Terminates HTTPS for `staging.haven.digipomps.org` and proxies CellScaffold
  traffic to the Vapor app on `127.0.0.1:8081`.
- Must not force `Connection: upgrade` for ordinary POST requests. That caused
  larger `agent/device-action` request bodies to stall in nginx/proxying before
  Vapor collected the body.

Current file locations:

| Location | Path |
| --- | --- |
| Active nginx include | `/etc/nginx/sites-enabled/staging_haven.conf` |
| Matching source copy | `/etc/nginx/sites-available/staging_haven.conf` |
| Active-file backup from 2026-07-03 fix | `/etc/nginx/backups/staging_haven.conf.bak-device-action-20260703T075725Z` |
| Source-copy backup from 2026-07-03 fix | `/etc/nginx/sites-available/staging_haven.conf.bak-device-action-20260703T075603Z` |

The staging vhost should define:

```nginx
map $http_upgrade $staging_connection_upgrade {
    default upgrade;
    "" close;
}
```

and the `location /` proxy block should use:

```nginx
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $staging_connection_upgrade;
```

Do not leave backup files in `/etc/nginx/sites-enabled/`; this nginx
installation includes every file in that directory, so backups there can create
duplicate `server_name staging.haven.digipomps.org` blocks.

Non-secret verification:

```bash
ssh -i "$HOME/.ssh/id_ed25519_hetzner" -o IdentitiesOnly=yes root@89.167.90.101 \
  'nginx -t &&
   nginx -T 2>/dev/null | grep -n -A20 "server_name staging.haven.digipomps.org" | sed -n "1,35p"'
```

Expected result:

- `nginx -t` reports syntax ok and successful
- the staging vhost shows `proxy_set_header Connection $staging_connection_upgrade;`

## Sprout Trust And Anchor Artifacts

Staging publishes Sprout trust and entity-anchor evidence from the mounted
CellsContainer volume:

| Artifact | Staging host path | Container path | Local HAVENAgentD path |
| --- | --- | --- | --- |
| Scaffold admin trust root | `/mnt/disk1/app/CellsContainer/sprout/scaffold-admin-trust-root.json` | `/app/CellsContainer/sprout/scaffold-admin-trust-root.json` | `/Users/kjetil/Library/Application Support/HAVENAgent/State/scaffold-admin-trust-root.json` |
| Entity anchor snapshot | `/mnt/disk1/app/CellsContainer/sprout/entity-anchor-snapshot.json` | `/app/CellsContainer/sprout/entity-anchor-snapshot.json` | n/a |
| Agent/operator entity link input | `/mnt/disk1/app/CellsContainer/sprout/agent-operator-entity-link.elc_5Wp8fRWa3LY7sru6.json` | `/app/CellsContainer/sprout/agent-operator-entity-link.elc_5Wp8fRWa3LY7sru6.json` | `/Users/kjetil/Library/Application Support/HAVENAgent/Out/agent-operator-entity-link.json` |

Local `HAVENAgentD` can pin the trust root by setting:

```json
{
  "scaffold": {
    "trustRootPath": "/Users/kjetil/Library/Application Support/HAVENAgent/State/scaffold-admin-trust-root.json"
  }
}
```

Non-secret verification:

```bash
sprout verify "$HOME/Library/Application Support/HAVENAgent/State/scaffold-admin-trust-root.json"
curl -ksS https://staging.haven.digipomps.org/.well-known/haven-scaffold-admin-trust-root.json
```

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
