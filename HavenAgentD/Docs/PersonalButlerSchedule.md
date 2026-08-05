# Personal Butler schedule in HAVENAgentD

HAVENAgentD owns the Personal Butler user schedule so daily, weekday and weekly
slots can be evaluated while the HAVEN app is closed. The default is disabled
with a 72-hour cadence. The service stores only cadence and consent metadata in
`State/personal-butler-schedule.json`; it does not accept chat history,
personality text, raw feedback or model output.

## Local Cell surface

- Endpoint: `cell:///agent/butler/scheduler`
- Loopback route: `butler-scheduler`
- Get: `state`
- Set: `preferences.configure`
- Access: stored owner or locally paired operator
- Flow topic: `agent.personal-butler.schedule`

The HAVEN app sends only enabled flags, quiet hours, schedule kind/time/day,
minimum interval, staging-wake consent, last offered time, snooze time and the
source device identifier. HAVENAgentD records the authorized requester identity
and signing-key fingerprint itself rather than accepting those fields from the
payload.

## Schedule wake

When an enabled slot is due, HAVENAgentD applies owner approval, global enable,
quiet hours, snooze and minimum-interval gates. The slot is consumed even when a
gate suppresses it, preventing a minute-by-minute retry. An accepted slot runs:

```text
/usr/bin/open -b org.digipomps.havenplayground \
  haven://butler/check-in?source=havenagentd&trigger=user_schedule&slot=...
```

The app accepts only the exact `haven://butler/check-in` route, the
`source=havenagentd` marker and the allowlisted `app_launch` or `user_schedule`
trigger. Opening the app is not permission to show an offer: the owner-private
chat Cell evaluates the local Butler policy again.

## Signed staging wake

The only remote action handled automatically is:

```text
topic: personal.butler.wake
actionID: personal.butler.haven.wake
```

The existing remote-intent verifier must accept the issuer signature, topic,
action ID, expiry and nonce first. HAVENAgentD then requires
`stagingWakeEnabled`, owner approval, global proactivity, app-launch permission,
quiet-hours, snooze and cadence gates. Remote arguments are ignored. The action
always opens the fixed HAVEN bundle and fixed check-in URL; it cannot select a
different URL, bundle or command.

Every accepted, suppressed or failed signed wake is appended to the existing
remote-intent audit trail with reviewer
`owner_preapproved_butler_policy`. Staging wake is off by default.
