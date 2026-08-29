---
id: dga-c2-domains
title: DGA rendezvous domains (resilient C2 resolution)
section: Command & Control
phase: Command & Control
attack:
  tactic: TA0011
  techniques: [T1568.002]
platform: [windows, network]
source: MITRE ATT&CK T1568.002; domain-generation-algorithm C2
pair: dga-nxdomain-entropy
---

Harden C2 against takedown by resolving rendezvous domains from a seeded algorithm
both sides share: the implant computes a rolling list of pseudo-random domains and
tries each until one resolves to the live server, so blocking any single domain does
nothing. Only a handful register at a time; the rest miss. The tell is the residue —
bursts of failed lookups (NXDOMAIN) for high-entropy, dictionary-free names from one
host before a hit.

```python
# illustrative seeded DGA: date-seeded pseudo-random labels the implant walks
import hashlib, datetime
seed = datetime.date.today().strftime("%Y%m%d")
for i in range(50):
    h = hashlib.md5(f"{seed}{i}".encode()).hexdigest()[:16]
    print(f"{h}.net")   # implant resolves each until one answers -> live C2
```
