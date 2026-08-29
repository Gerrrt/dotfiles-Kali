---
id: schtask-4698
title: Detect scheduled-task persistence (4698 task created)
detection: splunk-spl
event_ids: [4698]
attack:
  tactic: TA0003
  techniques: [T1053.005]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: schtask-persist
---

Task creation writes `4698` with the full task XML in the event. Detect on the
action, not the name: a task whose command runs encoded/hidden PowerShell, a
LOLBin, or something from a user-writable/temp path. Baseline your software's
legit tasks and alert on the rest; `4702` (task updated) catches the
modify-an-existing-task variant. (Needs the Object Access > Other Object Access
audit subcategory enabled.)

```spl
index=main EventCode=4698
| regex Task_Content="(?i)(-enc\b|-w\s+hidden|FromBase64|\\\\Users\\\\|\\\\Temp\\\\|mshta|regsvr32|rundll32|powershell.*(http|iex))"
| table _time, host, Subject_Account_Name, Task_Name, Task_Content
```
