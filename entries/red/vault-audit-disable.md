---
id: vault-audit-disable
title: Disable the Vault audit device (blind the SIEM)
section: HashiCorp Vault / secrets
phase: Defense Impairment
attack:
  tactic: TA0112
  techniques: [T1685]
platform: [vault]
source: HashiCorp Vault evasion (audit-device disable)
pair: vault-audit-device-audit
---

Before draining secrets, turn off logging: disabling a Vault audit device stops every
subsequent request from being recorded, blinding the SIEM to the exfil that follows.
Vault logs the **disable request itself** (it is the last event on that device), so the
`request.operation=delete` on a `sys/audit/` path is the tripwire — and a hard failure
if it's the *only* audit device and Vault is configured to block on audit failure.
(Secrets store — no slots.)

```sh
# disable the audit device so subsequent secret reads aren't logged
vault audit disable file
# or via the API:
curl -s -H "X-Vault-Token: <token>" -X DELETE "https://<vault>:8200/v1/sys/audit/file"
```
