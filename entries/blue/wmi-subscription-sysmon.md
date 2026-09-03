---
id: wmi-subscription-sysmon
title: Detect WMI subscription persistence (Sysmon 20 consumer)
detection: splunk-spl
event_ids: [20, 21]
attack:
  tactic: TA0003
  techniques: [T1546.003]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: wmi-subscription
---

The Security log barely sees this; Sysmon does. The WMI-eventing family is Sysmon
`19` (WmiFilter), `20` (WmiConsumer), `21` (WmiBinding). The command lives in the
consumer, so this query keys on event `20` and matches its `Destination` — a
`CommandLineEventConsumer` running PowerShell/cmd/a LOLBin is the high-fidelity
tell. The binding (`21`) and filter (`19`) carry no command, so don't fold them
into this `Destination` regex; instead treat **any** new `21`
(`__FilterToConsumerBinding`) as its own cheap, low-volume alert. Legitimate
permanent consumers are rare and usually from known management software, so
allowlist those and alert on the rest. Requires Sysmon with WMI eventing
(schema ≥ 4.1).

```spl
index=main EventCode=20
| regex Destination="(?i)(powershell|cmd\.exe|mshta|wscript|cscript|rundll32|-enc|FromBase64)"
| table _time, host, User, Name, Type, Destination, Query
```
