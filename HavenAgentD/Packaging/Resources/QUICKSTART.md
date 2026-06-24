# HAVEN Agent — Quick Start

`haven-agentd` is a small **background** macOS tool. There is no app icon and no
window; you drive it from Terminal and it runs quietly once set up. This file is
installed at `/usr/local/share/havenagent/QUICKSTART.md`.

## What got installed

| Path | What |
|------|------|
| `/usr/local/libexec/havenagent/haven-agentd` | the agent |
| `/usr/local/libexec/havenagent/sprout` | scaffold join/bootstrap helper |
| `/usr/local/bin/haven-agentd` | symlink so the command is on your PATH |
| `/usr/local/share/havenagent/` | LaunchAgent template + this guide |
| `~/Library/Application Support/HAVENAgent/` | your config, identity, logs (created by `setup`) |

Check it is reachable:

```bash
haven-agentd            # prints the list of commands
```

## Step 1 — Set up

Creates the runtime folder, writes `config.json` with a freshly generated local
token, and installs the per-user background service (LaunchAgent). It does **not**
start connecting yet (`startupMode` defaults to `disabled` = local-only, safe).

```bash
haven-agentd setup \
  --domain staging.haven.digipomps.org \
  --resolver-url https://staging.haven.digipomps.org \
  --sprout-path /usr/local/libexec/havenagent/sprout
```

The command prints a JSON report: where things were written, whether the token
was generated, and the next steps.

## Step 2 — Provisioning (lets the agent join the scaffold)

The agent needs signed evidence (pairing + starter-auth + entity-link) that an
operator mints for *this* Mac's agent key.

```bash
# 1. Emit this agent's identity and send the output to your operator:
haven-agentd provisioning-request

# 2. The operator returns a pack.json. Import it (verifies + installs):
haven-agentd provisioning-import --pack ~/Downloads/pack.json
```

Import refuses any pack minted for a different agent and verifies every artifact
before installing anything.

## Step 3 — Check readiness

```bash
haven-agentd bootstrap-probe
```

When `readyForBootstrap` is true, the agent can join the scaffold. To activate
the background service at login (safe once provisioned, or any time while
local-only):

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/io.digipomps.haven.agentd.plist
launchctl kickstart -k gui/$(id -u)/io.digipomps.haven.agentd
```

(Or re-run `haven-agentd setup --load`.)

## Where to look when unsure

```bash
haven-agentd bootstrap-probe     # provisioning + readiness
haven-agentd review-state        # queued remote intents awaiting your approval
tail -f ~/Library/Application\ Support/HAVENAgent/Logs/stdout.log
```

The first time an action drives Safari/Shortcuts, macOS will ask for Automation
/ Accessibility consent — grant it in the logged-in session.

Full operator guide: see `OperatorRunbook.md` and `ProvisioningPack.md` in the
HavenAgentD documentation.
