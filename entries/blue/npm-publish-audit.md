---
id: npm-publish-audit
title: Detect package publish (npm audit log)
detection: npm-audit-log
event_ids: []
attack:
  tactic: TA0001
  techniques: [T1195.002]
source: npm supply-chain compromise (trojanized publish)
pair: npm-malicious-publish
---

`action=package.publish` is the invariant. Publishing is routine — but it should come from
one known automation identity, so the tell is a publish by a human/unexpected actor, from
an unusual IP, out of hours, or a first-ever publisher on a package with many dependents.
Pin releases to the CI publish identity, allowlist it, and alert on any `package.publish`
outside it; a publish immediately after an `owner_add` or a 2FA change is the high-signal
sequence.

npm audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=npm sourcetype=npm:audit action=package.publish NOT actor.name IN ("<ci-publisher-bot>")
| table _time, actor.name, actor.type, action, package, version, actor.ip
```

**Allowlist the identity, never the actor class.** The paired attack publishes with a
*stolen automation token*, so it is recorded as an automation/CI actor — an exclusion like
`NOT actor.type=ci` would filter out the exact class the attacker publishes as and blind
this query to its own primary path. The compromised credential is indistinguishable from
the legitimate one by class; only the *specific* known publisher can be safely excluded, so
pin `actor.name` (or the automation token's id) to your release identity and keep
human-vs-automation as an enrichment column to triage by, not a gate. If your tenant's audit
records expose the token id, prefer `NOT actor.token_id IN (<known automation tokens>)` — a
token that was rotated out then reappears is itself the finding.
