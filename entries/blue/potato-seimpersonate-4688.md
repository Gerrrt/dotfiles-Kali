---
id: potato-seimpersonate-4688
title: Detect Potato privesc (service account → SYSTEM shell, 4688)
detection: splunk-spl
event_ids: [4688]
attack:
  tactic: TA0004
  techniques: [T1134.001]
source: itm4n (PrintSpoofer) & BeichenDream (GodPotato), SeImpersonate abuse
pair: potato-seimpersonate
---

Detection posture: **moderate** — the impersonation itself is a legitimate API,
and `4688` alone can't show the new process's run-as-SYSTEM result. So this query
flags the *shape* it can see — a service identity (app-pool / `*$` / NETWORK|LOCAL
SERVICE) spawning an interactive shell — and you confirm the SYSTEM outcome with
endpoint telemetry: Sysmon 17/18 on the `spoolss`/DCOM named pipe, plus Sysmon 1
correlating the parent service process to a SYSTEM child. Tune the service-account
list to your environment.

```spl
index=main EventCode=4688 New_Process_Name IN ("*\\cmd.exe","*\\powershell.exe")
    Account_Name IN ("*$","*APPPOOL*","NETWORK SERVICE","LOCAL SERVICE")
| table _time, host, Account_Name, Creator_Process_Name, New_Process_Name, Process_Command_Line
```

**Know how this query fails.** The `Account_Name` filter assumes the shell is spawned *as*
the service identity, but that is the state the exploit has already left: PrintSpoofer and
GodPotato impersonate the SYSTEM token **before** calling `CreateProcessAsUser`, so the
4688 Subject can be logged as `SYSTEM` — and a SYSTEM-spawning-`cmd.exe` event is excluded
by the very service-account list meant to find it. The narrower your list, the more reliably
it drops the successful escalations and keeps only the failed ones.

`Creator_Process_Name` is the sturdier key, because the parent is the potato binary itself
regardless of which token the child ends up with. Pivot to it when tuning:

```spl
index=main EventCode=4688 New_Process_Name IN ("*\\cmd.exe","*\\powershell.exe")
| regex Creator_Process_Name="(?i)(printspoofer|godpotato|juicypotato|roguepotato|sweetpotato|efspotato)"
| table _time, host, Account_Name, Creator_Process_Name, New_Process_Name, Process_Command_Line
```

That trades one weakness for another — it is name-based, so a renamed binary walks past it —
which is why the entry rates itself moderate and why Sysmon 17/18 on the `spoolss`/DCOM
named pipe should lead. Use the two 4688 queries as corroboration, not as the primary.
