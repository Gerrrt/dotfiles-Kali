---
id: cf-worker-deploy-audit
title: Detect Worker deploy (Cloudflare audit log)
detection: cloudflare-audit-log
event_ids: []
attack:
  tactic: TA0002
  techniques: [T1648]
source: Cloudflare abuse (malicious Worker deploy)
pair: cf-worker-deploy
---

A `create`/`update` on `resource.type=worker`/`workers_script` is the invariant — code
published to the edge in front of live traffic. Worker deploys should come from CI, so one
by a human/unexpected actor, outside the deploy pipeline, or on a sensitive zone is the
tell for edge interception/exfil. Require Workers to ship via version-controlled CI, and
alert on API-side script writes that bypass it; diff the deployed script against its
source.

That "outside the pipeline" test has to be *in the query* — unfiltered, this is a catch-all
on routine deploys and every real deploy buries the one that matters. Pin the release
identity in `actor.email` (or the deploy token's id, if your tenant's audit records expose
it) and exclude only that, exactly as `npm-publish-audit` does for the registry case.

Cloudflare's audit entry also records **how** the action was initiated — an `api` vs `dash`
context alongside the actor type (`user`, `account`, `cloudflare_admin`, `system`). A Worker
deployed from the dashboard in an estate that deploys from CI is the high-signal shape, so
keep both as triage columns.

```spl
index=cloudflare sourcetype=cloudflare:audit resource.type IN (worker, workers_script) action.type IN (create, update)
    NOT actor.email IN ("<ci-deploy-bot>")
| table _time, actor.email, actor.type, actor.context, resource.type, action.type, action.description
```

**Allowlist the identity, never the actor class** — the same rule as `npm-publish-audit`, and
it bites harder here. The paired attack deploys with a *stolen API token*, so Cloudflare
records it as the same actor class, and often the same `api` context, as the pipeline itself;
an exclusion like `NOT actor.context=api` would filter out the attacker's own primary path.
Only the *specific* known deploy identity can be safely excluded. Keep `actor.context` as an
enrichment column to triage by, not a gate — a deploy from a rotated-out token that reappears
is itself the finding.
