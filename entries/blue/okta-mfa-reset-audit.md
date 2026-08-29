---
id: okta-mfa-reset-audit
title: Detect MFA factor reset / deactivate (Okta System Log)
detection: okta-system-log
event_ids: []
attack:
  tactic: TA0006
  techniques: [T1556.006]
source: Scattered Spider / Okta help-desk social engineering
pair: okta-mfa-reset
---

The invariant is the Okta System Log event itself: `user.mfa.factor.reset_all` (or
a `user.mfa.factor.deactivate`). Routine during genuine help-desk resets, so detect on the
correlation — a reset *not* tied to an approved ticket, or one immediately followed
by a new-factor enrollment plus a sign-in from a new device/geo.

Okta System Log telemetry (Splunk Okta add-on / Sentinel), companion-only —
`PURPLE-TEAM.md` is on-prem Windows.

```spl
index=okta sourcetype=OktaIM2:log eventType IN ("user.mfa.factor.reset_all","user.mfa.factor.deactivate")
| table _time, actor.alternateId, target{}.alternateId, client.ipAddress, client.geographicalContext.country
```
