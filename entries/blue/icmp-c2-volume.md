---
id: icmp-c2-volume
title: Detect ICMP tunneling (echo volume + payload size)
detection: splunk-spl
event_ids: []
attack:
  tactic: TA0011
  techniques: [T1095]
source: Zeek conn.log / NetFlow ICMP volumetrics
pair: icmp-tunnel-c2
---

Legitimate ICMP echo is sparse and small — fixed-size OS pings, a few per host.
Tunneled ICMP is the opposite: sustained echo request/reply to a single external
host, high packet counts, and large or variable payload bytes carrying the encoded
session. From Zeek `conn.log` (or NetFlow) filtered to ICMP, sum bytes and packets
per internal→external pair over a window and alert on the outliers, especially to a
rare destination. Baseline out monitoring pollers that legitimately ping a lot.

```spl
index=zeek sourcetype=zeek:conn proto=icmp
| stats sum(orig_bytes) as bytes_out, count as pkts, avg(orig_bytes) as avg_payload by id.orig_h, id.resp_h
| where pkts>500 AND avg_payload>64
| sort - bytes_out
```
