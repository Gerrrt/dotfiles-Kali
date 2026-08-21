---
id: service-stop-preransom
title: Stop business services before impact (unlock files for encryption)
section: Impact
phase: Impact
attack:
  tactic: TA0040
  techniques: [T1489]
platform: [windows]
source: MITRE ATT&CK T1489; pre-encryption service termination
pair: service-stop-7036
---

Databases, mail, and backup agents hold their files open, so ransomware first stops
them — both to release those file handles for encryption and to knock out the
recovery/AV that would interrupt it. The pattern is a rapid sweep of `net stop` /
`sc stop` (or `taskkill`) against a curated list of SQL/Exchange/Veeam/AV service
names. Legitimate maintenance stops one service deliberately; this stops dozens in
seconds, which is the tell.

```cmd
net stop "MSSQLSERVER" /y
net stop "MSExchangeIS" /y
net stop "Veeam Backup Service" /y
sc stop "SQLTELEMETRY"
taskkill /F /IM sqlservr.exe
```
