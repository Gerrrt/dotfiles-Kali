---
id: golden-ticket-4769
title: Detect Golden Ticket (4769 with no preceding 4768)
detection: splunk-spl
event_ids: [4768, 4769]
attack:
  tactic: TA0006
  techniques: [T1558.001]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: golden-ticket
---

A forged TGT is minted offline, so the account uses Kerberos services (`4769` TGS
requests) without the DC ever issuing it a TGT (`4768`). Per account+host window,
a principal with TGS activity but zero TGT issuance is the invariant. Secondary
tells back it up: RC4 (`0x17`) when the realm is otherwise AES, and absurd ticket
lifetimes. Tune the window to your normal ticket-renewal cadence.

```spl
index=main EventCode IN (4768,4769) Account_Name!="*$"
| stats sum(eval(EventCode==4768)) AS tgts sum(eval(EventCode==4769)) AS tgs_reqs
    by Account_Name, Client_Address
| where tgs_reqs > 0 AND tgts == 0
```
