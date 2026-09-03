---
id: gcp-iam-policy-backdoor
title: GCP IAM policy backdoor (setIamPolicy → rogue principal)
section: GCP / cloud IAM
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098]
platform: [cloud]
source: GCP IAM abuse (resource IAM policy binding persistence)
pair: gcp-iam-policy-audit
---

With `resourcemanager.projects.setIamPolicy` (any Owner/`*.admin` role), bind an
attacker-controlled principal straight into the project's IAM policy — a rogue
service account, a personal Google identity, or `allUsers`. Granting
`roles/owner` (or the quieter `roles/resourcemanager.projectIamAdmin`) is durable,
survives SA-key rotation, and blends into normal IAM churn. Prefer an existing
low-noise SA as the member so the grant looks routine.
(Cloud — no slots.)

```sh
gcloud projects add-iam-policy-binding <project> \
  --member='serviceAccount:<attacker-sa>@<project>.iam.gserviceaccount.com' \
  --role='roles/owner'
```
