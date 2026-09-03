---
id: gh-cred-audit
title: Detect deploy-key / PAT credential backdoor (GitHub audit log)
detection: github-audit-log
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098]
source: GitHub post-compromise persistence (deploy key / PAT)
pair: gh-deploy-key-backdoor
---

Watch the two credential-add invariants: `repo.create_deploy_key` (an SSH key bound
to a repo — prioritize the writable ones) and `personal_access_token.access_granted`
(a fine-grained PAT approved against org resources). Both mint durable, MFA-free
access that survives a password reset, so an unexpected actor or an out-of-band grant
is the tell. Reconcile new credentials against known CI integrations and review any
created during an incident.

GitHub Enterprise audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem
Windows.

```spl
index=github sourcetype=github:audit action IN ("repo.create_deploy_key", "personal_access_token.access_granted")
| table _time, actor, action, repo
```
