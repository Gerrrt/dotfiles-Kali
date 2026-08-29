---
id: coercion-5145
title: Detect coercion (5145 named-pipe access)
detection: splunk-spl
event_ids: [5145]
attack:
  tactic: TA0006
  techniques: [T1187]
source: TrustedSec "Actionable Purple Teaming" (BH USA 2023)
pair: coerce-petitpotam
---

Every coercion vector reaches the same handful of named pipes over `IPC$`, with a
detailed file-share-access event (`5145`). Detect on the pipe set, not the tool: the
target endpoint can't change even as the coercion technique does.

The set is the union of the three protocols that carry coercion, and each name in it
earns its place:

- **MS-EFSR** (PetitPotam) is exposed over **five** pipes — `efsrpc`, `lsarpc`, `samr`,
  `lsass`, `netlogon`. Note that `\pipe\lsass` really is one of them: it is an RPC
  endpoint the EFSRPC interface binds to, *not* the LSASS process appearing by name, and
  PetitPotam and `coercer` both spray it. Dropping it because it reads like a process
  name opens a hole on the vector's most-used path.
- **MS-RPRN** (printerbug) → `spoolss`.
- **MS-DFSNM** (DFSCoerce) → `netdfs`, DC-only.

```spl
index=main EventCode=5145
| regex Share_Name="(?i).*ipc\$$"
| regex Relative_Target_Name="(?i)(spoolss|efsrpc|lsarpc|netlogon|lsass|samr|netdfs)"
| table _time, host, Account_Name, Source_Address, Share_Name, Relative_Target_Name, Access_Mask
```

`Access_Mask` is reported rather than filtered. `0x3` (read+write) is what a typical RPC
pipe bind requests and is a reasonable tightening if this is noisy in your environment —
but as a *filter* it is a silent drop for any client that opens the pipe with a different
mask, which trades away the whole premise that the endpoint is the invariant and the tool
is not. Tighten only after confirming the masks you actually observe.
