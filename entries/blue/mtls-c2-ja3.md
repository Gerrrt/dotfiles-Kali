---
id: mtls-c2-ja3
title: Detect mTLS C2 — outbound client certificate + TLS fingerprint (JA4 / JA3)
detection: splunk-spl
event_ids: []
attack:
  tactic: TA0011
  techniques: [T1573.002]
source: Zeek ssl.log JA3/JA3S + client-certificate fingerprinting
pair: mtls-c2-sliver
---

Encryption hides the payload, not the handshake — but pick the right thing in the handshake.
The invariant of *mutual* TLS is that it is **mutual**: the implant must present a **client
certificate** to authenticate to its listener. Outbound client-cert TLS is rare outside an
enterprise PKI, and unlike a fingerprint it does not depend on a list being current, on the
implant's build, or on the operator declining to randomize. Start here.

```spl
index=zeek sourcetype=zeek:ssl client_subject=*
| where isnotnull(client_subject) OR isnotnull(client_cert_chain_fids)
| stats count dc(id.orig_h) AS Sources by id.resp_h, server_name, client_subject, client_issuer
| sort count
```

Baseline it once: your own mTLS destinations (a handful of B2B APIs, an MDM endpoint, an
internal PKI) will be a short, stable list, and everything outside it — self-signed or
very-short-chain client certs especially, to a rare or young destination — is the hunt.

The fingerprint arm is the known-implant fast path, kept second because it is the fragile one.
Each implant's ClientHello (cipher list + extension order) hashes to a JA3 and the server's
ServerHello to a JA3S, so a known framework pair is a high-fidelity match regardless of
destination or sleep. Prefer **JA4/JA4S** (FoxIO, 2023+, emitted by current Zeek): JA3 is
increasingly defeated by TLS randomization and by uTLS-fronted implants that mimic a browser
hello outright, and a Go-based implant such as Sliver shifts its hello between releases — so
treat any JA3 set as a build-era IOC with a shelf life, not an invariant.

```spl
index=zeek sourcetype=zeek:ssl
| lookup ja4_c2_implants ja4 OUTPUT framework AS ja4_hit
| lookup ja3_c2_implants ja3 OUTPUT framework AS ja3_hit
| lookup ja3s_c2_servers ja3s OUTPUT framework AS ja3s_hit
| where isnotnull(ja4_hit) OR isnotnull(ja3_hit) OR isnotnull(ja3s_hit)
| table _time, id.orig_h, id.resp_h, server_name, ja4, ja3, ja3s, ja4_hit, ja3_hit, ja3s_hit
```
