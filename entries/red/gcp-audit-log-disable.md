---
id: gcp-audit-log-disable
title: GCP Cloud Audit log tamper (delete sink / strip auditConfigs)
section: GCP / cloud IAM
phase: Defense Impairment
attack:
  tactic: TA0112
  techniques: [T1685.002]
platform: [cloud]
source: GCP logging abuse (blind Data Access telemetry)
pair: gcp-audit-log-tamper-audit
---

Blind the defenders before the noisy work. Delete or redirect the log sink that
exports to the SIEM, or strip the project's `auditConfigs` so Data Access logs
stop flowing — either way the analytics that key on those events go dark. Note
the ceiling: Admin Activity logging cannot be disabled and records the tamper
itself, so this buys time, not silence.
(Cloud — no slots.)

```sh
gcloud logging sinks delete <sink> --project=<project>
gcloud projects set-iam-policy <project> policy-no-auditconfigs.json
```
