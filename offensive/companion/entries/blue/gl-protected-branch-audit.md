---
id: gl-protected-branch-audit
title: Detect protected-branch tamper (GitLab audit events)
detection: gitlab-audit-log
event_ids: []
attack:
  tactic: TA0112
  techniques: [T1685]
source: GitLab supply-chain abuse (protected-branch tamper)
pair: gl-protected-branch-off
---

`protected_branch_removed` is the invariant (pair with `protected_branch_created` to
catch the re-create that covers tracks). Removing protection on a default/release branch
is rare, high-impact, and legitimately maps to a change ticket — so alert on it against a
protected branch and reconcile with the approved-change window; a remove quickly followed
by a re-create around a push to the same branch is the cover-tracks shape.

GitLab audit-event telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=gitlab sourcetype=gitlab:audit event_type IN ("protected_branch_removed", "protected_branch_created")
| table _time, author_name, event_type, entity_path, target_details
```
