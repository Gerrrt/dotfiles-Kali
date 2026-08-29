---
id: slack-app-audit
title: Detect app install (Slack audit log)
detection: slack-audit-log
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098]
source: Slack workspace compromise (malicious OAuth app)
pair: slack-malicious-app
---

`action=app_installed` is the invariant — a new integration gaining programmatic access. Apps
should come from a reviewed, approved set, so one installed by an unexpected actor, requesting
broad read scopes (`channels:history`/`files:read`/`users:read.email`), or added during an
incident is the persistence tell. Reconcile installs against the approved-app allowlist,
require admin approval for new apps, and alert on broad-scope grants; an `app_installed`
followed by bulk `conversations.history` reads is the collect shape.

Slack audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=slack sourcetype=slack:audit action=app_installed
| table _time, actor.user.email, action, entity.app.name, entity.app.scopes
```
