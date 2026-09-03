---
id: okta-idp-audit
title: Detect IdP create / activate (Okta System Log)
detection: okta-system-log
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1556]
source: Okta tenant compromise (add-IdP / AiTM federation backdoor)
pair: okta-idp-backdoor
---

`system.idp.lifecycle.create` / `.activate` is the invariant. Adding or activating
an inbound IdP is rare and high-impact, so any one by an unexpected actor warrants
immediate review — near-zero-false-positive with a good allowlist of IAM admins and
change windows.

Okta System Log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=okta sourcetype=OktaIM2:log eventType IN ("system.idp.lifecycle.create","system.idp.lifecycle.activate")
| table _time, actor.alternateId, target{}.displayName, client.ipAddress
```
