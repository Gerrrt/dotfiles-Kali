---
id: dcsync-4662
title: Detect DCSync / NTDS replication (4662)
detection: splunk-spl
event_ids: [4662]
attack:
  tactic: TA0006
  techniques: [T1003.006]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: dcsync-secretsdump
---

A `4662` directory-access event with the replication access mask (`0x100`) from a
non-system SID is the signal — legitimate replication comes from DC machine
accounts, so a user/admin SID requesting it is the anomaly.

```spl
index=main EventCode=4662 Access_Mask="0x100" Security_ID!="S-1-5-18"
| stats count by host, Account_Name, Object_Server | sort -count
```

Tighter: alert on `Properties` containing the **DS-Replication-Get-Changes-All**
extended right `1131f6ad-9c07-11d1-f79f-00c04fc2dcd2` requested by anything that
isn't a domain controller.
