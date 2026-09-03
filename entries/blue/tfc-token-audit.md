---
id: tfc-token-audit
title: Detect org/team token creation (Terraform Cloud audit trail)
detection: terraform-audit-log
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098]
source: Terraform Cloud persistence (org/team API token)
pair: tfc-token-backdoor
---

`resource.type=authentication_token` with `resource.action=create` is the invariant.
Org and team tokens are powerful and issued rarely, so one minted by an unexpected actor
— or an org token created when a team token would do — is the persistence tell after a
control-plane compromise. Reconcile new tokens against known CI integrations, prefer
short-lived team tokens scoped to a workspace, and review any created during an incident.

Terraform Cloud audit-trail telemetry, companion-only — `PURPLE-TEAM.md` is on-prem
Windows.

```spl
index=terraform sourcetype=terraform:audit resource.type=authentication_token resource.action=create
| table _time, auth.description, auth.accessor_id, resource.type, resource.action, auth.organization_id
```
