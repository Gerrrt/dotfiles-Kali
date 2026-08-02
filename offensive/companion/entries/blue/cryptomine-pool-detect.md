---
id: cryptomine-pool-detect
title: Detect cryptojacking (Stratum pool connections + CPU peg)
detection: splunk-spl
event_ids: []
attack:
  tactic: TA0040
  techniques: [T1496.001]
source: Zeek conn.log / EDR process telemetry; Stratum pool indicators
pair: resource-hijack-xmrig
---

Two independent tells converge: a process pegged near 100% CPU for a sustained
period, and an outbound connection speaking Stratum to a mining pool — often on
3333/5555/7777/14444 or to a known pool domain, sometimes wrapped in TLS. Alert on
outbound connections to pool-domain/port indicators from server or workstation
fleets, and corroborate with EDR process telemetry for the CPU peg and miner
command-line flags (`--cpu-max-threads-hint`, `stratum+tcp://`). Either signal alone
is worth a look; together they're high fidelity. Keep the base query port-based
(`conn.log` has no hostname field), then enrich the survivors with `dns.log`/`ssl.log`
to resolve `id.resp_h` and match known pool domains (`*xmr*`, `*minexmr*`, `*nanopool*`).

```spl
index=zeek sourcetype=zeek:conn id.resp_p IN (3333,5555,7777,14444)
| stats count, sum(orig_bytes) as bytes_out, max(duration) as longest by id.orig_h, id.resp_h, id.resp_p
| where count>5
| sort - longest
```
