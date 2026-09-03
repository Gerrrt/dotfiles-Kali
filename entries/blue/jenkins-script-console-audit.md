---
id: jenkins-script-console-audit
title: Detect Script Console use (Jenkins audit log)
detection: jenkins-audit-log
event_ids: []
attack:
  tactic: TA0002
  techniques: [T1059]
source: Jenkins abuse (Groovy Script Console)
pair: jenkins-script-console
---

A request to `/script` or `/scriptText` is the invariant. The Script Console is
admin-only and rarely used legitimately (mostly break-glass), so *any* hit — especially
outside a change window, from a service account, or right before a credential-store read
— is high-signal for controller RCE / credential theft. Alert in real time, scope
`RunScripts`/`Administer` tightly, and pair with process-exec telemetry on the controller
host.

Jenkins Audit Trail plugin telemetry, companion-only — `PURPLE-TEAM.md` is on-prem
Windows.

```spl
index=jenkins sourcetype=jenkins:audit ("/scriptText" OR "/script")
| table _time, user, uri, node
```
