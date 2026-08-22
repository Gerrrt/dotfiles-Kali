---
id: bloodhound-collect
title: BloodHound collection (SharpHound / bloodhound-ce-python)
section: Active Directory — discovery
phase: Discovery
attack:
  tactic: TA0007
  techniques: [T1087.002, T1069.002, T1482]
platform: [windows, network]
source: SpecterOps BloodHound / SharpHound AD graph collection
pair: bloodhound-collect-4662
---

Map the whole domain before touching a single attack path. SharpHound (or
`bloodhound-ce-python` from Linux) walks LDAP and SMB to pull every user, group,
computer, ACL, session, and trust, then BloodHound graphs the shortest path from what
you control to Domain Admin. It is the enumeration that *precedes* Kerberoasting,
DCSync, RBCD, shadow-credentials — every AD attack in the corpus — which is exactly
why the collection sweep is the earliest place to catch the chain. `-c All` /
`--collectionmethod All` is the loud full pull; `DCOnly` is the quieter LDAP-only run
that skips per-host session enumeration. From Linux, use **`bloodhound-ce-python`**
(apt `bloodhound-ce-python`, pipx `bloodhound-ce`), not the legacy `bloodhound-python`
from `bloodhound.py` (≤4.3.1) — the legacy collector's zips do not ingest into
BloodHound CE, and the rejection comes only after you have pulled the whole graph.

```sh
# from a domain-joined Windows foothold
SharpHound.exe -c All -d {{domain}} --zipfilename loot
# or from Linux with creds
bloodhound-ce-python -u {{user}} -p {{password}} -d {{domain}} -dc {{hostname}} -c All
```
