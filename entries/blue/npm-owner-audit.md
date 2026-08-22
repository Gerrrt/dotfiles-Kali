---
id: npm-owner-audit
title: Detect maintainer add (npm audit log)
detection: npm-audit-log
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098]
source: npm supply-chain persistence (package ownership)
pair: npm-owner-add
---

A `package.owner_add` (or org `team.user_add`) is the invariant — a new identity gaining
durable publish rights. Ownership changes are rare and map to a known onboarding, so one by
an unexpected actor, adding an unfamiliar account, or during an incident is the persistence
tell after a maintainer compromise. Reconcile new owners/maintainers against known
collaborators and alert on out-of-band grants; an owner_add followed by a publish is the
takeover-then-ship shape.

npm audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=npm sourcetype=npm:audit action IN ("package.owner_add", "team.user_add")
| table _time, actor.name, action, package, target.user
```
