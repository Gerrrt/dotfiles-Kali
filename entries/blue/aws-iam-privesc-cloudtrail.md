---
id: aws-iam-privesc-cloudtrail
title: Detect IAM privilege escalation (CloudTrail AttachUserPolicy / PassRole)
detection: splunk-cloudtrail
event_ids: []
attack:
  tactic: TA0004
  techniques: [T1098.003]
source: Rhino Security Labs (AWS IAM privesc paths), Pacu
pair: aws-iam-privesc-policy
---

Two invariants, because the attack has two shapes. The **self-grant** is an
`AttachUserPolicy` / `AttachRolePolicy` / `PutUserPolicy` whose actor is the same principal
as the target, or whose `policyArn` is a wildcard-admin policy — `AdministratorAccess` is the
obvious one, but `PowerUserAccess` and any customer policy with `"Action": "*"` land in the
same place, so match on the grant rather than the ARN string alone. `CreatePolicyVersion`
with `setAsDefault=true` is the same escalation wearing an update's clothes and is easy to
miss if you only watch Attach\*.

The **PassRole** shape never touches the actor's own identity, and it is the one most often
missed — because **there is no `PassRole` event to search for**. `iam:PassRole` is an
authorization check evaluated during the *launching* call, not an API call of its own, so
the passed role appears only as a request parameter on the `RunInstances` /
`CreateFunction` / `RegisterTaskDefinition` that consumed it. A query keyed on `Attach*`
alone will never see this path, and neither will one hunting for an event named PassRole.
Alert on a privileged role passed by a principal that does not normally launch compute —
then pivot to whether that role's credentials subsequently appear from a new source IP.

CloudTrail telemetry (Splunk `aws:cloudtrail` / Athena / Sentinel `AWSCloudTrail`),
companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=aws sourcetype=aws:cloudtrail
  eventName IN (AttachUserPolicy, AttachRolePolicy, AttachGroupPolicy, PutUserPolicy, CreatePolicyVersion)
| eval actor=coalesce('userIdentity.userName','userIdentity.arn','userIdentity.principalId')
| eval target=coalesce('requestParameters.userName','requestParameters.roleName','requestParameters.policyArn')
| where like('requestParameters.policyArn',"%AdministratorAccess%")
     OR like('requestParameters.policyArn',"%PowerUserAccess%")
     OR 'requestParameters.setAsDefault'="true"
     OR actor=target
| table _time, eventName, actor, target, requestParameters.policyArn, sourceIPAddress, userAgent
```

The PassRole half, which the query above cannot see — the role rides in the launching call's
`requestParameters`. Baseline who legitimately launches compute with which role, then alert
on the pairs that fall outside it:

```spl
index=aws sourcetype=aws:cloudtrail
  eventName IN (RunInstances, CreateFunction, UpdateFunctionConfiguration, RegisterTaskDefinition, CreateJob)
| eval passed_role=coalesce('requestParameters.iamInstanceProfile.arn','requestParameters.role','requestParameters.roleArn','requestParameters.taskRoleArn')
| where isnotnull(passed_role)
| eval actor=coalesce('userIdentity.userName','userIdentity.arn','userIdentity.principalId')
| stats count AS launches, values(eventName) AS via, min(_time) AS first_seen by actor, passed_role, sourceIPAddress
| sort launches
```
