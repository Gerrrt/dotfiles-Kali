---
id: harbor-robot-audit
title: Detect robot-account creation (Harbor audit log)
detection: harbor-audit-log
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098]
source: Container supply-chain persistence (registry robot account)
pair: harbor-robot-backdoor
---

`operation=create` with `resource_type=robot` is the invariant. Robot accounts are
provisioned rarely and by a small set of admins, so one minted by an unexpected actor
— especially a system-level robot or one scoped across all projects — is a strong
persistence tell after a project-admin compromise. Reconcile new robots against known
CI integrations, prefer short expirations, and alert on any created outside change
control.

Harbor registry audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem
Windows.

```spl
index=harbor sourcetype=harbor:audit operation=create resource_type=robot
| table _time, username, operation, resource_type, resource
```
