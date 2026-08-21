---
id: gl-token-audit
title: Detect access/deploy token backdoor (GitLab audit events)
detection: gitlab-audit-log
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098]
source: GitLab post-compromise persistence (access/deploy token)
pair: gl-token-backdoor
---

Watch the token-creation invariants: `project_access_token_created` /
`personal_access_token_created` (an API/push credential) and `deploy_token_created`
(durable clone + registry pull). All mint non-interactive, MFA-free access that survives
a password reset, so an unexpected actor, a wide scope (`api`, `write_repository`), or an
out-of-band creation is the tell. Reconcile new tokens against known CI integrations,
prefer short expirations, and review any created during an incident.

GitLab audit-event telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=gitlab sourcetype=gitlab:audit event_type IN ("project_access_token_created", "personal_access_token_created", "deploy_token_created")
| table _time, author_name, event_type, entity_path, target_details
```
