---
id: azure-keyvault-secret-dump
title: Azure Key Vault bulk secret read (drain the vault)
section: Azure / resource plane (ARM)
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1555.006]
platform: [cloud]
source: MITRE ATT&CK T1555.006; HAFNIUM / Shai-Hulud Key Vault secret theft
pair: azure-keyvault-audit
---

Key Vault is where the *other* credentials live — DB connection strings, cloud keys, API
tokens, TLS private keys. With `Key Vault Secrets User` (RBAC) or a legacy access-policy
`get`/`list` grant — very often a **managed identity** lifted off the VM compromised via
`azure-vm-runcommand`, so it needs no phishing of its own — list every secret and read each
one. `list` returns identifiers only, never values, so the sweep is inherently
*list-then-N-gets*, and that shape is the tell on the blue side. MITRE names Key Vault
explicitly here and cites HAFNIUM and Shai-Hulud draining it.

This is the Azure analogue of `vault-secret-exfil`, and the two de-conflict the way the
5145/4662 families do — same idea, different store and different telemetry:
`vault-secret-exfil` is HashiCorp Vault audit devices under the parent `T1555`; this is
Azure Key Vault `AuditEvent` under the cloud sub-technique `T1555.006`. (Cloud — no on-host
target, so no slots.)

```sh
# list identifiers, then read each secret's value — list never returns the value
az keyvault secret list --vault-name <vault> --query '[].name' -o tsv \
  | while read -r s; do az keyvault secret show --vault-name <vault> --name "$s" --query value -o tsv; done
# or straight against the data plane with a stolen bearer token / managed-identity token
curl -s -H "Authorization: Bearer <token>" "https://<vault>.vault.azure.net/secrets?api-version=7.4"
```
