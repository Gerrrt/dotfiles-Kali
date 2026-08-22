---
id: gpp-cpassword-5145
title: Detect GPP cpassword hunt (5145 SYSVOL Groups.xml read)
detection: splunk-spl
event_ids: [5145]
attack:
  tactic: TA0006
  techniques: [T1552.006]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: gpp-cpassword
---

The decrypt is offline, so the only on-wire moment is reading the GPP XML out of
SYSVOL — a `5145` detailed-file-share-access event on the `SYSVOL` share whose
relative target ends in a credential-bearing GPP file. Group Policy clients read
these too, so scope to *interactive* accounts (not `*$` machine accounts).
Honey-policy a fake `Groups.xml` for a near-zero-false-positive tripwire.

```spl
index=main EventCode=5145 Share_Name="*SYSVOL*" Account_Name!="*$"
| regex Relative_Target_Name="(?i)(Groups|Services|ScheduledTasks|Printers|DataSources)\.xml$"
| table _time, host, Account_Name, Source_Address, Relative_Target_Name
```
