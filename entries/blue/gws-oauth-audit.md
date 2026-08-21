---
id: gws-oauth-audit
title: Detect illicit OAuth grant (Google Workspace token audit)
detection: gws-audit-log
event_ids: []
attack:
  tactic: TA0006
  techniques: [T1528]
source: Google Workspace consent-phishing (illicit OAuth grant)
pair: gws-oauth-grant
---

`eventName=authorize` in the **token** audit is the invariant. Most grants are for known
apps, so the signal is a first-seen/low-reputation `client_id` or `app_name`, a broad or
sensitive `scope` (`mail.google.com`, `drive`, `gmail.readonly`), or a burst of authorize
events across users (a campaign). Restrict third-party app access (allowlist Marketplace
apps, block unverified), and alert on new client IDs requesting mail/drive scopes.

Google Workspace audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=gws sourcetype=gws:reports:token eventName=authorize
| table _time, actor.email, app_name, client_id, scope, ipAddress
```
