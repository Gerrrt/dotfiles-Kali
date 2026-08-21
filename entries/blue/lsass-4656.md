---
id: lsass-4656
title: Detect LSASS access (4656 dump-shaped handle)
detection: splunk-spl
event_ids: [4656]
attack:
  tactic: TA0006
  techniques: [T1003.001]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: lsass-dump-lsassy
---

Credential theft from memory needs a handle to `lsass` with read/dump access
rights — `4656` with a dump-shaped access mask, from any process that isn't the
AV engine, is the signal. Endpoint telemetry (Sysmon 10 process-access) sees this
better than the Security log, but the mask filter catches the obvious cases.

```spl
index=main EventCode=4656 Object_Name=*lsass* TaskCategory="Kernel Object"
    Process_Name!=*MsMpEng.exe
    (Access_Mask="0x1010" OR Access_Mask="0x1410" OR Access_Mask="0x1FFFFF")
| table _time, host, Account_Name, Process_Name, Access_Mask, Object_Name
```
