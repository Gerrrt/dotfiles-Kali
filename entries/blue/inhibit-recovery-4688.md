---
id: inhibit-recovery-4688
title: Detect recovery inhibition (4688 vssadmin / wbadmin / bcdedit)
detection: splunk-spl
event_ids: [4688]
attack:
  tactic: TA0040
  techniques: [T1490]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: inhibit-recovery-vssadmin
---

Shadow-copy and backup deletion runs through a small set of signed built-ins with
unmistakable arguments — `vssadmin delete shadows`, `wmic shadowcopy delete`,
`wbadmin delete catalog`, `bcdedit ... recoveryenabled no`. Alert on 4688 process
creation (or Sysmon 1) matching those image+command-line shapes; the delete/disable
verbs are what separate them from legitimate backup administration. This fires
*before* mass encryption, so treat a hit as an in-progress incident, not a report.

```spl
index=main EventCode=4688 (New_Process_Name IN ("*\\vssadmin.exe","*\\wbadmin.exe","*\\bcdedit.exe","*\\wmic.exe"))
| where (like(Process_Command_Line,"%delete shadows%")
      OR like(Process_Command_Line,"%shadowcopy delete%")
      OR like(Process_Command_Line,"%delete catalog%")
      OR like(Process_Command_Line,"%recoveryenabled no%"))
| table _time, host, Account_Name, New_Process_Name, Process_Command_Line
```
