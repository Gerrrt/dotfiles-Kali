---
id: okta-api-token-audit
title: Detect tenant credential persistence — API token + OAuth service app (Okta System Log)
detection: okta-system-log
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098]
source: Okta post-compromise persistence
pair: okta-api-token
---

`system.api_token.create` is the invariant for the static-token path. API tokens should come
from a small, known set of service integrations, so one minted by an unexpected actor —
especially a human admin during an incident — is the tell. Pair with token *use* from a new IP
shortly after, and rotate/scope tokens so a leaked one is bounded.

**That event covers only half the technique.** An SSWS token can be created in the Admin
Console only; the supported *programmatic* route to the same durable, MFA-free, non-interactive
tenant access is an **OAuth 2.0 service app authenticating with a private-key JWT** — which is
what the paired attack recommends, and which never writes `system.api_token.create`. It writes
`app.oauth2.*` instead, so a query keyed on the token event alone is blind to the path an
attacker who reads Okta's own documentation will take. Watch both:

- `app.oauth2.credentials.lifecycle.create` / `.activate` — a client secret **or a JWK** added
  to an OAuth client. Registering the public key of a keypair you hold is the literal act of
  planting this backdoor, and it applies to an *existing* trusted app just as well as a new one.
- `app.oauth2.client.privilege.grant` — Okta API scopes granted to an OAuth client. The
  highest-signal event of the set and the one with no static-token analogue: this is what turns
  an ordinary service app into an admin-equivalent tenant backdoor.
- `app.oauth2.client.lifecycle.create` / `.update` — the service app itself being stood up or
  reconfigured.
- `app.oauth2.client.read_client_secret` — an existing app's secret being read back, the
  credential-theft variant that needs no new app at all.

Table `eventType` so the two shapes stay distinguishable at triage: a static token and a
service app are different persistence, revoked differently and hunted differently.

Okta System Log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=okta sourcetype=OktaIM2:log eventType IN (
    "system.api_token.create",
    "app.oauth2.client.lifecycle.create", "app.oauth2.client.lifecycle.update",
    "app.oauth2.credentials.lifecycle.create", "app.oauth2.credentials.lifecycle.activate",
    "app.oauth2.client.privilege.grant", "app.oauth2.client.read_client_secret")
| table _time, eventType, actor.alternateId, actor.type, target{}.displayName, client.ipAddress
| sort -_time
```
