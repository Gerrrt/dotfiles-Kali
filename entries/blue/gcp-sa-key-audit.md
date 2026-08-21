---
id: gcp-sa-key-audit
title: Detect SA key creation (GCP audit, CreateServiceAccountKey)
detection: gcp-logging
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098.001]
source: GCP IAM abuse (service-account key persistence)
pair: gcp-sa-key
---

User-managed SA keys are the durable GCP backdoor, so the invariant is the create
itself: `google.iam.admin.v1.CreateServiceAccountKey` in Cloud Audit Logs (Admin
Activity). Alert on creation for privileged SAs, by unexpected actors, or anywhere
org policy forbids user-managed keys. The org-policy constraint
`iam.disableServiceAccountKeyCreation` turns this into prevention.

GCP Cloud Audit Logs telemetry (native Cloud Logging filter below; also queryable
as Sentinel `GCPAuditLogs`), companion-only — `PURPLE-TEAM.md` is on-prem Windows.
Triage each hit by `protoPayload.authenticationInfo.principalEmail` (the actor) and
`protoPayload.resourceName` (the target SA).

```text
logName=~"cloudaudit.googleapis.com%2Factivity"
protoPayload.methodName="google.iam.admin.v1.CreateServiceAccountKey"
```
