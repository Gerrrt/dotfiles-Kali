---
id: gcp-audit-log-tamper-audit
title: Detect audit-log tamper (GCP, DeleteSink / auditConfig strip)
detection: gcp-logging
event_ids: []
attack:
  tactic: TA0112
  techniques: [T1685.002]
source: GCP logging abuse (blind Data Access telemetry)
pair: gcp-audit-log-disable
---

The tamper is self-witnessing: sink and auditConfig changes are Admin Activity
events, which are always-on and immutable, so the act of going dark is itself
logged. Alert on `DeleteSink`/`UpdateSink`, and on any `SetIamPolicy` that removes
or narrows `auditConfigs` (a `REMOVE` delta on the audit config). Pair it with a
gap monitor — an unexpected drop-to-zero in a project's Data Access log volume is
the corroborating signal when the config change slips through.

GCP Cloud Audit Logs telemetry (native Cloud Logging filter below; also queryable
as Sentinel `GCPAuditLogs`), companion-only — `PURPLE-TEAM.md` is on-prem Windows.
Triage by `protoPayload.authenticationInfo.principalEmail` (the actor) and
`protoPayload.resourceName` (the sink or project touched).

```text
logName=~"cloudaudit.googleapis.com%2Factivity"
(protoPayload.methodName=~"DeleteSink$" OR protoPayload.methodName=~"UpdateSink$"
 OR (protoPayload.methodName=~"SetIamPolicy$"
     AND protoPayload.serviceData.policyDelta.auditConfigDeltas.action="REMOVE"))
```
