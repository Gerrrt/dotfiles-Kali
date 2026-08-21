---
id: wmi-subscription
title: WMI event-subscription persistence (permanent consumer)
section: Persistence (authorized engagements only)
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1546.003]
platform: [windows]
source: hacktheplanet §"Persistence (authorized engagements only)"
pair: wmi-subscription-sysmon
---

The fileless persistence classic: bind an `__EventFilter` (a trigger — a clock
time, logon, a process start) to a `CommandLineEventConsumer` (your payload) with
a `__FilterToConsumerBinding`. It lives in the WMI repository, survives reboot,
runs as SYSTEM, and touches no Run key or scheduled task. PowerLurk's
`Register-MaliciousWmiEvent` is the easy local PoC. Authorized only.

NetExec has no module for this: there is no `wmi-event`/`wmi_event` in either
`nxc smb -L` or `nxc wmi -L`. Its one T1546.003 surface is `nxc wmi <t>
--exec-method wmiexec-event`, which *executes* through a subscription it then
tears down — not the reboot-surviving consumer this entry is about.

```sh
Register-MaliciousWmiEvent -EventName Persist -PermanentCommand "powershell -w hidden -enc <b64>" -Trigger ProcessStart -ProcessName notepad.exe
```
