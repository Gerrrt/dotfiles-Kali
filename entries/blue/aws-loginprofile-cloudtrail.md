---
id: aws-loginprofile-cloudtrail
title: Detect console takeover (CloudTrail Create/UpdateLoginProfile)
detection: splunk-cloudtrail
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098]
source: Rhino Security Labs (Pacu), AWS IAM privesc/persistence
pair: aws-console-login-profile
---

`CreateLoginProfile` on a user that had no console access, or `UpdateLoginProfile`
where actor != target, is the takeover tell — a login profile is normally set once
at user creation by an admin, and users reset only their own. Alert on the events
and prioritize actor!=target plus anything toward a privileged user. Pair with the
`CreateAccessKey` alert: the two together are the full console+API takeover.

CloudTrail telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=aws sourcetype=aws:cloudtrail eventName IN (CreateLoginProfile, UpdateLoginProfile)
| rename requestParameters.userName AS target_user
| eval actor_user=coalesce('userIdentity.userName','userIdentity.arn','userIdentity.principalId')
| eval cross_principal=if(target_user!=actor_user,"yes","no")
| where eventName="CreateLoginProfile" OR cross_principal="yes"
| table _time, eventName, actor_user, target_user, cross_principal, sourceIPAddress
```
