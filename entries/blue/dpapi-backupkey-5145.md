---
id: dpapi-backupkey-5145
title: Detect DPAPI backup-key theft (protected_storage pipe, 5145)
detection: splunk-spl
event_ids: [5145]
attack:
  tactic: TA0006
  techniques: [T1555]
source: Benjamin Delpy (mimikatz DPAPI) & Will Schroeder (SharpDPAPI), DPAPI research
pair: dpapi-backupkey
---

Detection posture: **narrow but real** — the backup-key retrieval rides MS-BKRP
over the DC's `protected_storage` named pipe (`5145`), and almost nothing but a
genuine domain backup operation touches it. A non-backup principal accessing
`protected_storage` on a DC is the tell. The *offline* decryption that follows is
invisible — this RPC is the only on-wire moment. Needs detailed file-share
auditing on DCs.

```spl
index=main EventCode=5145 Relative_Target_Name="protected_storage"
| regex Share_Name="(?i).*ipc\$$"
| table _time, host, Account_Name, Source_Address, Share_Name, Relative_Target_Name
```
