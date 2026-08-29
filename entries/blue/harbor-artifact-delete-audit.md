---
id: harbor-artifact-delete-audit
title: Detect artifact deletion (Harbor audit log)
detection: harbor-audit-log
event_ids: []
attack:
  tactic: TA0005
  techniques: [T1070]
source: Container supply-chain evasion (artifact deletion)
pair: harbor-artifact-delete
---

`operation=delete` on an artifact/repository is the invariant. Deletions of published
images are rare outside retention/GC policy, so a manual delete — especially of a
trusted tag, by a robot or an unexpected actor, or close after a push to the same repo
(push-then-delete = temporary-implant cleanup) — is the tell. Enable Harbor's tag
immutability + retention so trusted tags can't be overwritten or removed, and alert on
deletes outside the GC service account.

Harbor registry audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem
Windows.

```spl
index=harbor sourcetype=harbor:audit operation=delete resource_type IN ("artifact", "repository")
| table _time, username, operation, resource_type, repository, tag
```
