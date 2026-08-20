---
id: dcshadow-4742
title: Detect DCShadow (rogue DC registration, 4742 GC SPN)
detection: splunk-spl
event_ids: [4742, 4662, 5137]
attack:
  tactic: TA0112
  techniques: [T1207]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: dcshadow
---

DCShadow has to make the directory believe a non-DC is a DC, and that leaves
prints: a computer account gets a `GC/...` (global-catalog) service principal name
added (`4742`), a server/`nTDSDSA` object is created under the Sites container
(`5137`), and replication (`4662`) then originates from a host that is not a real
DC. The SPN write is the cleanest invariant — alert on a `GC/` SPN appearing on
any account that isn't an established domain controller. The `("DC1$","DC2$")`
list below is a **placeholder** — replace it with your real DC computer-account
inventory before relying on the rule.

```spl
index=main EventCode=4742 Service_Principal_Names="*GC/*"
| search NOT Target_Account_Name IN ("DC1$","DC2$")
| table _time, host, Account_Name, Target_Account_Name, Service_Principal_Names
```

Corroborate with `5137` creating an `nTDSDSA`/server object, and `4662` replication
(`DS-Replication-Get-Changes`) sourced from a host outside your DC inventory.
