---
id: gh-branch-protection-audit
title: Detect branch-protection tamper (GitHub audit log)
detection: github-audit-log
event_ids: []
attack:
  tactic: TA0112
  techniques: [T1685]
source: GitHub supply-chain abuse (branch-protection tamper)
pair: gh-branch-protection-off
---

Two invariants cover both paths: `protected_branch.destroy` (the rule was deleted,
opening the branch) and `protected_branch.policy_override` (an admin merged past a
still-present rule). Both are rare, high-impact, and legitimately map to a change
ticket — so alert on either against a protected branch and reconcile with the
approved-change window; a destroy quickly followed by a re-create is the cover-tracks
shape.

GitHub Enterprise audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem
Windows.

```spl
index=github sourcetype=github:audit action IN ("protected_branch.destroy", "protected_branch.policy_override")
| table _time, actor, action, repo, branch
```
