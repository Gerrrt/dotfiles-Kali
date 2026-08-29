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
2025-06-15, while `firewall_rule` still matches historical events in retained logs.

The two actions need different treatment, which is why they are two queries. A `delete` is
self-evidently the control going away — alert on it unconditionally. An `update` is not: the
ruleset is written on every legitimate rules-as-code push, so an unfiltered `update` clause
is a catch-all that buries the one change that matters. The tell the body has always named —
flipping a rule to `enabled:false`, which leaves it visible in the dashboard and is the
quieter way to open the edge than deleting it — has to be *in* the query.

**Which arm you can run depends on your audit-log version.** Before/after values are an
**Audit Logs v1** feature; Cloudflare's **v2** logs do not carry them yet (documented as a
post-GA roadmap item), so on a v2 tenant the `newValue` test below matches nothing and the
detection fails silently rather than loudly. On v2, drop the `newValue` clause and run the
`update` arm as an actor-filtered triage feed — the allowlist and the initiation context are
the discrimination you have left — or read the ruleset back through the API and diff it.

```spl
index=cloudflare sourcetype=cloudflare:audit resource.type IN (firewall_rule, ruleset) action.type=delete
| table _time, actor.email, actor.type, actor.context, resource.type, resource.id, action.description
```

The quiet disable — an `update` that flips a rule inert. Needs Audit Logs **v1** for the
before/after values; see the caveat above for the v2 fallback:

```spl
index=cloudflare sourcetype=cloudflare:audit resource.type IN (firewall_rule, ruleset) action.type=update
    newValue="*\"enabled\":false*" NOT actor.email IN ("<iac-deploy-bot>")
| table _time, actor.email, actor.type, actor.context, resource.type, resource.id, oldValue, newValue
```

**Allowlist the identity, never the actor class** — the same rule as `npm-publish-audit` and
`cf-worker-deploy-audit`. The paired attack `PATCH`es the ruleset with a stolen API token, so
it is recorded with the same actor type and the same `api` initiation context as the pipeline
that manages these rules legitimately; only the *specific* known IaC identity can be excluded.
Keep `actor.context` (`api` vs `dash`) as an enrichment column — a rule disabled from the
dashboard in an estate that manages rules as code is the high-signal shape — not as a gate.
