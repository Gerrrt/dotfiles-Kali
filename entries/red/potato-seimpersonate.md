---
id: potato-seimpersonate
title: SeImpersonate → SYSTEM (PrintSpoofer / GodPotato)
section: Windows privilege escalation
phase: Privilege Escalation
attack:
  tactic: TA0004
  techniques: [T1134.001]
platform: [windows]
source: itm4n (PrintSpoofer) & BeichenDream (GodPotato), SeImpersonate abuse
pair: potato-seimpersonate-4688
---

A service account holding `SeImpersonate`/`SeAssignPrimaryToken` (IIS app-pool,
MSSQL, many service identities) can coerce a SYSTEM token over a local named pipe
or DCOM and impersonate it — instant local SYSTEM. Check the privilege first;
PrintSpoofer (spoolss pipe) and GodPotato (DCOM) are the current go-tos. Local
privesc — runs on the box you already have a foothold on, so no target slots.

```sh
whoami /priv
PrintSpoofer64.exe -i -c cmd
GodPotato -cmd "cmd /c whoami"
```
