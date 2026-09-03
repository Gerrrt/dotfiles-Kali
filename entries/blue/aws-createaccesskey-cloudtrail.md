---
id: aws-createaccesskey-cloudtrail
title: Detect IAM access-key backdoor (CloudTrail CreateAccessKey)
detection: splunk-cloudtrail
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098.001]
source: Rhino Security Labs (Pacu), AWS IAM privesc/persistence
pair: aws-iam-backdoor-key
---

The invariant is a `CreateAccessKey` where the *actor* differs from the *target*
user — a principal minting a key for someone else (users normally rotate only
their own). CloudTrail records `eventName=CreateAccessKey` with
`requestParameters.userName` (target) and `userIdentity` (actor); alert when they
differ, prioritizing keys minted toward a privileged user.

CloudTrail telemetry (Splunk `aws:cloudtrail` / Athena / Sentinel
`AWSCloudTrail`), companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=aws sourcetype=aws:cloudtrail eventName=CreateAccessKey
| rename requestParameters.userName AS target_user
| eval actor_user=coalesce('userIdentity.userName','userIdentity.arn','userIdentity.principalId')
| where isnotnull(target_user) AND target_user!=actor_user
| table _time, actor_user, target_user, sourceIPAddress, userAgent
```
