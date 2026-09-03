---
id: npm-2fa-audit
title: Detect publish-2FA downgrade (npm audit log)
detection: npm-audit-log
event_ids: []
attack:
  tactic: TA0112
  techniques: [T1685]
source: npm supply-chain evasion (2FA requirement tamper)
pair: npm-2fa-disable
---

The invariant is the publish protection being *weakened* — not one specific value. Alert on
any `action=package.edit` that lands the publish `mfa` requirement below `publish`:
`automation` (2FA required, but automation tokens override it) as well as `none`. Keying on
`mfa=none` alone misses the downgrade the paired red actually uses, and `none` is being
narrowed out of npm's documented values anyway — so the `none` arm is the legacy case, not
the main one.

Any downgrade is rare and high-impact (it gates whether a bare token can ship a release), so
all of them warrant review — especially one soon followed by a `package.publish`. Manage the
publish-2FA level as a locked package setting; a downgrade-then-publish-then-restore is the
cover-tracks shape, and the restore is what makes it look untouched at rest.

npm audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=npm sourcetype=npm:audit action=package.edit mfa IN ("none", "automation")
| table _time, actor.name, action, package, mfa
| sort -_time
```
