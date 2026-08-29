---
id: tfc-var-audit
title: Detect workspace variable injection (Terraform Cloud audit trail)
detection: terraform-audit-log
event_ids: []
attack:
  tactic: TA0002
  techniques: [T1072]
source: Terraform Cloud IaC abuse (workspace variable injection)
pair: tfc-var-injection
---

`resource.type=variable` with `resource.action=create`/`update` is the invariant. Most
variable changes are benign CI, so the signal is one by an unexpected actor, a change to
an `env` variable that alters run behavior (`TF_CLI_ARGS`, `TF_CLI_CONFIG_FILE`,
credential vars), or a change immediately before a run. Diff the variable set against
its baseline, require config-as-code review for variable changes, and alert on env-var
writes outside the CI service identity.

Terraform Cloud audit-trail telemetry, companion-only — `PURPLE-TEAM.md` is on-prem
Windows.

```spl
index=terraform sourcetype=terraform:audit resource.type=variable resource.action IN ("create", "update")
| table _time, auth.description, auth.accessor_id, resource.type, resource.action, auth.organization_id
```
