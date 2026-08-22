---
id: tfc-agent-audit
title: Detect rogue agent pool (Terraform Cloud audit trail)
detection: terraform-audit-log
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1543]
source: Terraform Cloud IaC abuse (rogue agent pool)
pair: tfc-agent-hijack
---

`resource.type=agent_pool` with `resource.action=create` is the invariant. Agent pools
are provisioned rarely and by a small set of admins, so a new pool — especially one
created just before a workspace is switched to `agent` execution mode, or by an
unexpected actor — is a strong tell that someone is positioning to capture run secrets
and state. Reconcile pools against the known agent inventory and alert on any created
outside change control; pair with workspace execution-mode changes.

Terraform Cloud audit-trail telemetry, companion-only — `PURPLE-TEAM.md` is on-prem
Windows.

```spl
index=terraform sourcetype=terraform:audit resource.type=agent_pool resource.action=create
| table _time, auth.description, auth.accessor_id, resource.type, resource.action, auth.organization_id
```
