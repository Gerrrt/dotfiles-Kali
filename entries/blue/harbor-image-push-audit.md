---
id: harbor-image-push-audit
title: Detect image push over a trusted tag (Harbor audit log)
detection: harbor-audit-log
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1525]
source: Container supply-chain compromise (Implant Internal Image)
pair: harbor-image-backdoor
---

`operation=push` on an artifact is the invariant. Most pushes are benign CI, so the
signal is a push to a **protected/trusted repo by an unexpected actor**, a push that
**overwrites an existing tag** (esp. `:latest`/release tags), or a push outside the CI
service account and its build window. Pair with image-signing/admission (cosign, Harbor
content trust) so an unsigned overwrite is blocked, not just logged, and diff the new
digest against the last known-good.

Harbor registry audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem
Windows.

```spl
index=harbor sourcetype=harbor:audit operation=push resource_type=artifact
| table _time, username, operation, resource_type, repository, tag
```
