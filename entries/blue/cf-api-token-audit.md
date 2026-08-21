---
id: cf-api-token-audit
title: Detect API token creation (Cloudflare audit log)
detection: cloudflare-audit-log
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098]
source: Cloudflare post-compromise persistence (API token)
pair: cf-api-token
---

`resource.type=api_token` with `action.type=create` is the invariant. API tokens are
issued rarely and by a known set of admins/automation, so one minted by an unexpected
actor — especially broadly scoped (zone/DNS/Workers) or created during an incident — is
the persistence tell after an account compromise. Reconcile new tokens against known
integrations, scope them tightly, and alert on creation outside change control.

Cloudflare audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=cloudflare sourcetype=cloudflare:audit resource.type=api_token action.type=create
| table _time, actor.email, action.type, action.description, actor.ip
```
