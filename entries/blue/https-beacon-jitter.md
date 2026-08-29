---
id: https-beacon-jitter
title: Detect HTTPS beaconing by inter-arrival regularity (proxy logs)
detection: splunk-spl
event_ids: []
attack:
  tactic: TA0011
  techniques: [T1071.001]
source: MITRE ATT&CK TA0011; beacon inter-arrival analysis
pair: https-beacon-sliver
---

Jitter randomizes each interval but not the *distribution*: a beacon's callbacks
still cluster around a mean period with a bounded spread, while human browsing does
not. Compute the deltas between successive connections per `src→dest`, and alert
when a destination is contacted many times with a low coefficient of variation
(stdev small relative to the mean) — especially to a rare/uncategorized host from a
single stable user-agent. Enrich with domain age + category to cut noise; a fixed
User-Agent talking to a young, uncategorized domain on a near-metronomic cadence is
the signal jitter can't hide.

```spl
index=proxy action=allowed
| sort 0 src_ip, dest, _time
| streamstats current=f last(_time) as prev by src_ip, dest
| eval delta=_time-prev
| stats count, avg(delta) as period, stdev(delta) as spread by src_ip, dest, http_user_agent
| eval cv=spread/period
| where count>20 AND period>30 AND cv<0.35
| sort cv
```
