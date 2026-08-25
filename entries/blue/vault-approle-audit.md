---
id: vault-approle-audit
title: Detect rogue AppRole / auth backdoor (Vault audit log)
detection: vault-audit-log
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098]
source: HashiCorp Vault persistence (rogue AppRole / auth backdoor)
pair: vault-approle-backdoor
---

Two invariants: enabling an auth method (`update` on `sys/auth/<type>`) and creating an
AppRole (`create`/`update` on `auth/approle/role/<name>`). Both are rare, admin-level
changes, so one by an unexpected token — especially a role bound to `root`/a broad policy
or given a non-expiring `secret_id_ttl` — is a strong persistence tell. Reconcile new
roles against known automation and alert on any created outside change control.

HashiCorp Vault audit-device telemetry, companion-only — `PURPLE-TEAM.md` is on-prem
Windows.

```spl
index=vault sourcetype=vault:audit type=request request.operation IN ("create", "update") (request.path=sys/auth/* OR request.path=auth/approle/role/*)
| table _time, auth.display_name, request.operation, request.path, request.remote_address
```
