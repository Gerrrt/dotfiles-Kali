---
id: wmiexec-4688
title: Detect WMI exec (4688 WmiPrvSE child process)
detection: splunk-spl
event_ids: [4688]
attack:
  tactic: TA0002
  techniques: [T1047]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: wmiexec-impacket
---

WMI execution drops no service (`7045`) to catch, but the payload runs as a child
of `WmiPrvSE.exe`. A `4688` whose creator is `WmiPrvSE.exe` spawning
`cmd.exe`/`powershell.exe` is the signal — especially with impacket-wmiexec's
`cmd.exe /Q /c ... 1> \\127.0.0.1\ADMIN$\...` output-redirect shape. Legitimate
WMI providers spawn children too, so pair the parent with a shell target and the
SMB output-redirect string.

```spl
index=main EventCode=4688 Creator_Process_Name="*\\WmiPrvSE.exe"
    New_Process_Name IN ("*\\cmd.exe","*\\powershell.exe")
| table _time, host, Account_Name, Creator_Process_Name, New_Process_Name, Process_Command_Line
```
