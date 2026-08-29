---
id: rdp-hijack-4688
title: Detect RDP session hijack (4688 tscon)
detection: splunk-spl
event_ids: [4688]
attack:
  tactic: TA0008
  techniques: [T1563.002]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: rdp-hijack-tscon
---

The hijack can't happen without a `tscon ... /dest:rdp-tcp#` command line, so the
process-creation event (`4688`) carrying that argument is a near-zero-false-
positive tell — legitimate admins almost never `tscon` to a different session's
RDP endpoint by hand.

```spl
index=main EventCode=4688
| regex Process_Command_Line="(?i)/dest:rdp-tcp#"
```
