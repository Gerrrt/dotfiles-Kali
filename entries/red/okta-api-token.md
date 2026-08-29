---
id: okta-api-token
title: Okta API token (long-lived tenant persistence)
section: Okta / identity provider
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098]
platform: [okta]
source: Okta post-compromise persistence
pair: okta-api-token-audit
---

After compromising an admin, mint a static API token: long-lived, MFA-free,
non-interactive, carrying the creator's privileges, and surviving the admin's
password/session reset — a clean tenant backdoor. SSWS tokens are created in the
**Admin Console only** (Security → API → Tokens → Create Token) — there is no REST
endpoint that mints one (the API only lists/revokes them); the supported
programmatic alternative is an OAuth 2.0 service app with a private-key JWT.

The two paths are **not** the same in the System Log, which is what makes the OAuth route the
quieter one: creating the token writes `system.api_token.create`, while standing up the service
app writes `app.oauth2.client.lifecycle.create` and registering your public key writes
`app.oauth2.credentials.lifecycle.create`/`.activate` — with the Okta API scopes arriving as
`app.oauth2.client.privilege.grant`. A tenant watching only the token event never sees it. Add
the key to an *existing*, already-trusted service app and there is no app-creation event either.
(Cloud IdP — no slots.)

```sh
# create it in the Admin Console (Security → API → Tokens → Create Token), then use it:
curl -s "https://<org>.okta.com/api/v1/users/me" -H "Authorization: SSWS <new-token>"
```
