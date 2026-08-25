---
id: unconstrained-deleg-4624
title: Detect unconstrained-deleg abuse (DC machine-account auth to a non-DC, 4624)
detection: splunk-spl
event_ids: [4624]
attack:
  tactic: TA0006
  techniques: [T1558]
source: Lee Christensen & Will Schroeder, "The Unintended Risks of Trusting Active Directory" (SpecterOps)
pair: unconstrained-deleg-tgt
---

Detection posture: **soft** — the TGT caching is legitimate Kerberos. The realistic
tell is the coerced auth *landing*: a domain controller's computer account doing a
network logon (`4624`) to a host that isn't a DC, which DCs essentially never do.
Allowlist your DC computer accounts and DC hosts below. Best paired with the
coercion alert (`coercion-5145`) firing just before, and with config hygiene —
inventory `TRUSTED_FOR_DELEGATION` accounts that shouldn't have it.

```spl
index=main EventCode=4624 Logon_Type=3 Account_Name="*$"
| search Account_Name IN ("DC1$","DC2$")
| where NOT (host IN ("DC1","DC2"))
| table _time, host, Account_Name, Source_Network_Address
```
