---
id: cf-worker-deploy
title: Cloudflare Worker deploy (serverless edge code exec)
section: Cloudflare / edge
phase: Execution
attack:
  tactic: TA0002
  techniques: [T1648]
platform: [cloudflare]
source: Cloudflare abuse (malicious Worker deploy)
pair: cf-worker-deploy-audit
---

Cloudflare Workers run your code on the edge in front of every request — deploy one and
you have serverless execution that can skim credentials/session cookies from live traffic,
inject content, or proxy to an attacker origin, all before the request reaches the real
site. Publishing a script writes a Cloudflare audit event with `resource.type=worker`
(`workers_script`) and `action.type=create`/`update`. (Edge control plane — no slots.)

```sh
# deploy a Worker that intercepts/exfils requests at the edge (worker.js = the payload)
curl -s -X PUT "https://api.cloudflare.com/client/v4/accounts/<acct>/workers/scripts/<name>" \
  -H "Authorization: Bearer <token>" -H "Content-Type: application/javascript" --data-binary @worker.js
```
