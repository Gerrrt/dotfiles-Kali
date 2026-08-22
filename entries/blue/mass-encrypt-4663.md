---
id: mass-encrypt-4663
title: Detect mass encryption (4663 file-write burst + note drop)
detection: splunk-spl
event_ids: [4663, 11]
attack:
  tactic: TA0040
  techniques: [T1486]
source: Windows object-access auditing (Event ID 4663) burst analysis
pair: ransomware-encrypt-files
---

Encryption is a write storm: a single process issuing `WriteData` (4663, with
SACLs enabled) or Sysmon 11 FileCreate against hundreds of files across many
directories in seconds — far above any normal application's file-touch rate. Alert
when one `Process_Name`/host exceeds a high threshold of distinct files written in a
short window, and corroborate with a same-name note file (`readme`, `how_to_decrypt`,
`*.<campaign-ext>`) appearing in many folders. Tune the threshold per environment;
back it with canary files for a low-false-positive trip.

Prefer the **Sysmon 11 (FileCreate)** variant as the primary: file-data SACLs are
off by default, so the 4663 query is blind out-of-the-box, whereas Sysmon 11 needs
no SACL.

```spl
index=sysmon EventCode=11
| bucket _time span=1m
| rex field=TargetFilename "(?<dir>.+)\\[^\\]+$"
| stats dc(TargetFilename) as files, dc(dir) as dirs by _time, host, Image
| where files>200
| sort - files
```

The 4663 object-access variant (requires file-data SACLs enabled):

```spl
index=wineventlog EventCode=4663 Accesses="*WriteData*"
| bucket _time span=1m
| rex field=Object_Name "(?<dir>.+)\\[^\\]+$"
| stats dc(Object_Name) as files, dc(dir) as dirs by _time, host, Process_Name
| where files>200
| sort - files
```
