---
id: ldap-recon
title: LDAP reconnaissance (raw directory queries)
section: Active Directory — discovery
phase: Discovery
attack:
  tactic: TA0007
  techniques: [T1087.002, T1069.002]
platform: [windows, network]
source: hacktheplanet AD enumeration; ldapsearch / Get-ADUser / nxc ldap
pair: ldap-recon-4662
---

The hand-tool version of the same discovery: query LDAP directly for the objects you
care about instead of pulling the whole graph. Any valid domain credential can read most
of the directory, so a few targeted filters surface the SPN accounts to Kerberoast, the
AS-REP-roastable users, the privileged groups, and the machines with unconstrained
delegation — often faster and quieter than a full BloodHound run because you read only
what you need. From Windows the `Get-AD*` cmdlets and `net group /domain` do it natively;
from Linux `ldapsearch` and `nxc ldap` cover the same ground.

```sh
# Linux: broad directory read, then targeted filters
ldapsearch -x -H ldap://{{rhost}} -D "{{user}}@{{domain}}" -w {{password}} -b "dc={{domain}}" "(objectClass=user)"
nxc ldap {{rhost}} -u {{user}} -p {{password}} --admin-count --trusted-for-delegation
# Windows (native, no tooling to drop)
powershell -c "Get-ADUser -Filter * -Properties servicePrincipalName | ? {$_.servicePrincipalName}"
```
