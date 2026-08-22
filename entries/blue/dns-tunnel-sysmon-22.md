---
id: dns-tunnel-sysmon-22
title: Detect DNS tunneling (Sysmon 22 query volume + label length)
detection: splunk-spl
event_ids: [22]
attack:
  tactic: TA0011
  techniques: [T1071.004]
source: Sysmon DnsQuery (Event ID 22) telemetry
pair: dns-tunnel-c2
---

Tunneled DNS looks nothing like resolution: one process emits hundreds of unique
queries under a single registrable domain, with long high-entropy leftmost labels
(the encoded payload) and TXT/NULL answers. Sysmon Event ID 22 attributes each
query to its `Image`, so group by process and parent domain and alert when a single
non-browser image drives a high count of distinct, long subdomains to one zone.
Baseline out CDNs and telemetry endpoints that legitimately fan out subdomains.

```spl
index=sysmon EventCode=22
| eval label=mvindex(split(QueryName,"."),0), qlen=len(label)
| rex field=QueryName "(?<parent_domain>[^.]+\.[^.]+)$"
| stats count, dc(QueryName) as uniq, avg(qlen) as avg_label_len by Image, host, parent_domain
| where uniq>100 AND avg_label_len>25
| sort - uniq
```
