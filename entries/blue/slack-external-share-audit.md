---
id: slack-external-share-audit
title: Detect external shared channel (Slack audit log)
detection: slack-audit-log
event_ids: []
attack:
  tactic: TA0010
  techniques: [T1567]
source: Slack workspace compromise (Slack Connect external share)
pair: slack-external-share
---

A `shared_channel_invite_sent` / `shared_channel_invite_accepted` is the invariant — a channel
being opened to an outside workspace. Slack Connect shares are legitimate but bounded to known
partners, so an invite naming an unknown external org, on a sensitive channel, or by an
unexpected actor is the exfiltration tell: the far org can read the channel's whole history.
Allowlist approved partner orgs/domains and alert on invites to any other; an invite quickly
followed by bulk file access is the drain shape.

Slack audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=slack sourcetype=slack:audit action IN ("shared_channel_invite_sent", "shared_channel_invite_accepted")
| table _time, actor.user.email, action, entity.channel, context.external_team
```
