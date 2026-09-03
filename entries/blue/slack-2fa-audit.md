---
id: slack-2fa-audit
title: Detect 2FA enforcement disable (Slack audit log)
detection: slack-audit-log
event_ids: []
attack:
  tactic: TA0112
  techniques: [T1685]
source: Slack workspace compromise (2FA enforcement tamper)
pair: slack-2fa-disable
---

`action=pref.two_factor_auth_changed` with the requirement set off (`two_factor_required=false`)
is the invariant — workspace-wide auth being weakened. Turning off enforced 2FA is rare and
high-impact (it drops every member to password-only), so any disable warrants review,
especially one paired with new logins or a fresh admin grant. Manage the 2FA policy as a
locked org setting and alert on any downgrade; a disable followed by anomalous sign-ins is the
takeover-enabling shape.

Slack audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=slack sourcetype=slack:audit action=pref.two_factor_auth_changed two_factor_required=false
| table _time, actor.user.email, action, two_factor_required
```
