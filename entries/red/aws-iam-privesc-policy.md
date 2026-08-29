---
id: aws-iam-privesc-policy
title: AWS IAM privilege escalation (AttachUserPolicy / PassRole → AssumeRole)
section: AWS / cloud IAM
phase: Privilege Escalation
attack:
  tactic: TA0004
  techniques: [T1098.003]
platform: [cloud]
source: Rhino Security Labs (AWS IAM privesc paths), Pacu
pair: aws-iam-privesc-cloudtrail
---

A principal does not need admin to *become* admin — it needs one of the IAM permissions that
grant it. The blunt path is `iam:AttachUserPolicy`: attach `AdministratorAccess` to yourself
and you are done in one call. The quieter path is `iam:PassRole` paired with a compute
service (`ec2:RunInstances`, `lambda:CreateFunction`, `glue`, …) — pass an existing
privileged role to a resource you control and read its credentials from the instance metadata
service or the function environment, never touching your own IAM identity. `sts:AssumeRole`
against a role whose trust policy is too broad reaches the same place. Pacu's
`iam__privesc_scan` enumerates which of the ~20 known paths the current creds can walk.
(Cloud — no on-host target, so no slots.)

```sh
aws iam attach-user-policy --user-name <target-user> \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
aws iam create-policy-version --policy-arn <customer-policy-arn> \
  --policy-document file://admin.json --set-as-default   # quieter: version an existing policy
aws sts assume-role --role-arn <privileged-role-arn> --role-session-name s
pacu  # then: run iam__privesc_scan
```
