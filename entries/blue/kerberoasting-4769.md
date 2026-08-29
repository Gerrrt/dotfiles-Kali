---
id: kerberoasting-4769
title: Detect Kerberoasting (4769 RC4 TGS)
detection: splunk-spl
event_ids: [4769]
attack:
  tactic: TA0006
  techniques: [T1558.003]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: kerberoast-getuserspns
---

Detect on the invariant, not the IOC: an RC4 (`0x17`) service ticket for a
non-machine, non-krbtgt SPN. The encryption downgrade is the signal even when
ticket flags look normal — tools like Orpheus force RC4 precisely to keep the
roast crackable, so the downgrade itself is the tell.

```spl
index=main EventCode=4769 Service_Name!="*$" Service_Name!="krbtgt"
    Ticket_Encryption_Type=0x17
| stats dc(Service_Name) AS ServiceAccounts values(Service_Name)
    by Client_Address, Account_Name
| sort -ServiceAccounts
```
