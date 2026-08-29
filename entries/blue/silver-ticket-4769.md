---
id: silver-ticket-4769
title: Detect Silver Ticket (Kerberos service logon with no 4769)
detection: splunk-spl
event_ids: [4624, 4769]
attack:
  tactic: TA0006
  techniques: [T1558.002]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: silver-ticket
---

Detection posture: **soft** — a silver ticket's whole point is that it never
touches the DC, so there is no `4769` to alert on directly. The realistic tell is
the *absence*: a Kerberos network logon (`4624` type 3) landing on a service host
for an account the DC issued no service ticket (`4769`) to in the window. Correlate
by `Account_Name` in a single pass (no fragile `join`/subsearch): pull both event
types and compare per-account counts. Set the search/alert **time range** to your
ticket-renewal cadence (a few hours). The durable backstop is enabling PAC
validation, which rejects the forged ticket outright.

```spl
index=main (EventCode=4624 Logon_Type=3 Authentication_Package_Name="Kerberos" Account_Name!="*$")
    OR EventCode=4769
| stats sum(eval(EventCode==4624)) AS kerb_logons sum(eval(EventCode==4769)) AS tgs_issued
    values(Source_Network_Address) AS sources by Account_Name
| where kerb_logons > 0 AND tgs_issued == 0
```
