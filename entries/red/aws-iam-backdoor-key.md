---
id: aws-iam-backdoor-key
title: AWS IAM access-key backdoor (CreateAccessKey on another user)
section: AWS / cloud IAM
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098.001]
platform: [cloud]
source: Rhino Security Labs (Pacu), AWS IAM privesc/persistence
pair: aws-createaccesskey-cloudtrail
---

With `iam:CreateAccessKey` over another principal (a privesc/persistence primitive
Pacu enumerates), mint a *second* access key for a higher-privileged IAM user and
walk off with long-lived programmatic creds — no password, no MFA, surviving the
victim's console password reset. Each user can hold two keys, so the original keeps
working and nothing visibly breaks. (Cloud — no on-host target, so no slots.)

```sh
aws iam create-access-key --user-name <target-user>
pacu  # then: run iam__backdoor_users_keys
```
