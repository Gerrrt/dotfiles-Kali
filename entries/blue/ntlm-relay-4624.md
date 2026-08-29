---
id: ntlm-relay-4624
title: Detect NTLM relay (4624 workstation mismatch)
detection: splunk-spl
event_ids: [4624]
attack:
  tactic: TA0006
  techniques: [T1557.001]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: ntlm-relay-ntlmrelayx
---

A relayed logon carries the *victim's* workstation name but arrives from the
*relay's* source address — so the tell is a `4624` whose `Workstation_Name`
doesn't resolve to its `Source_Network_Address`. That mismatch is the invariant;
the attacker can't relay without it.

```spl
index=main EventCode=4624 Workstation_Name!="-" Source_Port!="0"
| eval RelayedFrom=if(host!=Workstation_Name, Workstation_Name, "")
| lookup dnslookup clienthost AS RelayedFrom OUTPUT clientip AS IP
| where RelayedFrom!="" AND Source_Network_Address!=IP
| table _time, host, Account_Name, Source_Network_Address, RelayedFrom, IP
```
