---
id: service-stop-7036
title: Detect pre-encryption service kills (7036 stop burst)
detection: splunk-spl
event_ids: [7036]
attack:
  tactic: TA0040
  techniques: [T1489]
source: Service Control Manager stop events (Event ID 7036)
pair: service-stop-preransom
---

One service stopping is routine; a *burst* of business-critical services entering
the stopped state within seconds is not. Correlate SCM Event ID 7036 ("entered the
stopped state") across many distinct services per host in a short window; the query
below is 7036-only. Corroborate out-of-band with process-creation (4688) for the
`net.exe stop` / `sc.exe stop` / `taskkill.exe` command lines against DB/mail/backup/AV
names. Weight the alert when the stopped set includes backup or endpoint-protection
services — the combination immediately preceding, or interleaved with, a file-write
storm is an active-encryption indicator.

```spl
index=wineventlog EventCode=7036 "entered the stopped state"
| bucket _time span=2m
| stats dc(Service_Name) as services_stopped, values(Service_Name) as which by _time, host
| where services_stopped>5
| sort - services_stopped
```
