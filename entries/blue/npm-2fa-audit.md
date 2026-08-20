---
id: npm-2fa-audit
title: Detect publish-2FA disable (npm audit log)
detection: npm-audit-log
event_ids: []
attack:
  tactic: TA0112
  techniques: [T1685]
source: npm supply-chain evasion (2FA requirement tamper)
pair: npm-2fa-disable
---

`action=package.edit` with the publish `mfa` requirement set to `none` is the invariant —
the publish protection being removed. Dropping require-2FA-to-publish is rare and high-impact
(it gates whether a bare token can ship a release), so any change to `none` warrants review,
especially one soon followed by a `package.publish`. Manage the publish-2FA requirement as a
locked package setting and alert on any downgrade; a disable-then-publish-then-re-enable is
the cover-tracks shape.

npm audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=npm sourcetype=npm:audit action=package.edit mfa=none
| table _time, actor.name, action, package, mfa
```
