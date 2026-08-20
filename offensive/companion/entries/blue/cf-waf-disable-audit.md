---
id: cf-waf-disable-audit
title: Detect WAF/firewall rule disable (Cloudflare audit log)
detection: cloudflare-audit-log
event_ids: []
attack:
  tactic: TA0112
  techniques: [T1686.001]
source: Cloudflare defense evasion (WAF/firewall tamper)
pair: cf-waf-disable
---

A `delete`/`update` on `resource.type=firewall_rule`/`ruleset` is the invariant — the edge
control being removed or weakened. These changes are rare and high-impact (they gate what
reaches the origin), so any by an unexpected actor, or a disable quickly followed by
anomalous origin traffic, warrants review. Manage rules as code and alert on out-of-band
firewall/WAF changes; a delete followed by a re-create is the cover-tracks shape.

Both `resource.type` values are kept deliberately: current changes land on `ruleset`, since
rules moved to the Rulesets engine and the legacy Firewall Rules API was sunset on
2025-06-15, while `firewall_rule` still matches historical events in retained logs. Watch
`update` as closely as `delete` — flipping a rule to `enabled:false` leaves it visible in
the dashboard and is the quieter way to open the edge.

Cloudflare audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=cloudflare sourcetype=cloudflare:audit resource.type IN (firewall_rule, ruleset) action.type IN (delete, update)
| table _time, actor.email, resource.type, action.type, action.description
```
