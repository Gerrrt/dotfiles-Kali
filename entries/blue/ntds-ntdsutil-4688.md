---
id: ntds-ntdsutil-4688
title: Detect NTDS theft via ntdsutil/VSS (4688 + 8222)
detection: splunk-spl
event_ids: [4688, 8222]
attack:
  tactic: TA0006
  techniques: [T1003.003]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: ntds-ntdsutil
---

Copying NTDS.dit avoids the replication right (`4662`), so detect on host
behavior instead: on a domain controller, `ntdsutil` with an `ifm`/`create full`
argument, or `vssadmin`/`diskshadow`/`wbadmin` creating a shadow copy (`4688`).
Corroborate with the `8222` shadow-copy-created event. Almost nothing legitimately
runs `ntdsutil ... ifm` outside a planned DC backup or migration — allowlist
those windows and alert on the rest.

```spl
index=main EventCode=4688
| regex Process_Command_Line="(?i)(ntdsutil.*(ifm|create\s+full)|vssadmin\s+create\s+shadow|diskshadow|wbadmin\s+start\s+backup)"
| table _time, host, Account_Name, New_Process_Name, Process_Command_Line
```
