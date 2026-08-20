---
id: vault-audit-device-audit
title: Detect audit-device disable (Vault audit log)
detection: vault-audit-log
event_ids: []
attack:
  tactic: TA0112
  techniques: [T1685]
source: HashiCorp Vault evasion (audit-device disable)
pair: vault-audit-disable
---

`request.operation=delete` on a `sys/audit/` path is the invariant — the disable request
is logged before the device stops, so it's a reliable tripwire. Audit devices are
removed almost never outside planned maintenance, so treat any disable as high-severity,
alert in real time, and pair with a **heartbeat**: a gap in Vault audit volume right
after a `sys/audit` delete is the exfil-under-cover shape. Run more than one audit device
so disabling one doesn't go dark.

HashiCorp Vault audit-device telemetry, companion-only — `PURPLE-TEAM.md` is on-prem
Windows.

```spl
index=vault sourcetype=vault:audit type=request request.operation=delete request.path=sys/audit/*
| table _time, auth.display_name, request.operation, request.path, request.remote_address
```
