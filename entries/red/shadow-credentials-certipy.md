---
id: shadow-credentials-certipy
title: Shadow Credentials (certipy shadow auto)
section: Active Directory — attack paths
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1556]
platform: [windows, network]
source: Elad Shamir, "Shadow Credentials: Abusing Key Trust Account Mapping" (SpecterOps, 2021)
pair: shadow-credentials-5136
---

With write access to a target's `msDS-KeyCredentialLink` (GenericWrite / GenericAll
over the object), add your own key credential and authenticate as that account via
PKINIT — no password reset, no touching its existing creds. `shadow auto` adds the
key, gets a TGT, recovers the NT hash, then cleans up. `<target>` is the victim
account you have write over.

```sh
certipy-ad shadow auto -u {{user}}@{{domain}} -p {{password}} -account <target> -dc-ip {{rhost}}
```
