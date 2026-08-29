---
id: reverse-tunnel-detect
title: Detect reverse tunnels (long-lived outbound session + JA3)
detection: splunk-spl
event_ids: []
attack:
  tactic: TA0011
  techniques: [T1572]
source: Zeek conn.log duration/volume + JA3 tunneling fingerprints
pair: reverse-tunnel-chisel
---

A tunnel collapses many logical sessions into one, so it shows up as a single outbound
connection that lives far longer than normal client traffic — often to a raw IP or a
young domain on an odd port, from a host that has no business holding a persistent
outbound session.

**Do not require volume in both directions.** The paired technique is `chisel R:socks` /
`ligolo-ng` driving interactive pivoting, scanning and lateral RDP/SMB: bursty and
*asymmetric* — the red entry's own tell is "disproportionate" traffic. An
`orig_bytes > N AND resp_bytes > N` gate excludes exactly that shape, and a recon or
lateral tunnel that never bulk-transfers in both directions is invisible to it. Gate on
duration plus volume in *either* direction, and keep the orig/resp ratio as a ranking
column — the imbalance is the signal, not a disqualifier.

From Zeek `conn.log`, alert on long-lived external connections and rank by asymmetry;
enrich with chisel/ligolo TLS fingerprints and destination reputation.

```spl
index=zeek sourcetype=zeek:conn
| where NOT (cidrmatch("10.0.0.0/8",id.resp_h) OR cidrmatch("172.16.0.0/12",id.resp_h) OR cidrmatch("192.168.0.0/16",id.resp_h))
| eval total_bytes=orig_bytes+resp_bytes, ratio=round(orig_bytes/(resp_bytes+1),2)
| where duration>600 AND total_bytes>100000
| table _time, id.orig_h, id.resp_h, id.resp_p, duration, orig_bytes, resp_bytes, total_bytes, ratio, ja3, ja4
| sort - duration
```

The duration floor is the evadable part — an operator who tears down and redials stays
under any threshold you set. That tunnel does not disappear, it changes shape: repeated
short sessions from one host to the same rare destination. Pair the query above with a
per-destination session count over the same window, and treat a high reconnect count to
a single external IP as equivalent to one long session. Prefer **JA4/JA4S** over JA3
where your Zeek emits it (JA3 is increasingly defeated by TLS randomization), and
remember the fingerprint is enrichment on top of the behavioural signal, not a
prerequisite for it.
