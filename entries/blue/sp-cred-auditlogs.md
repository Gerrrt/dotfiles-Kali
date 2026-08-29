---
id: sp-cred-auditlogs
title: Detect SP credential backdoor (Entra audit, Add credentials)
detection: kql-entra-audit
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098.001]
source: Mandiant / dirkjanm, Entra service-principal abuse
pair: sp-cred-backdoor
---

Adding a secret/cert to an app is a discrete Entra audit event — "Add service
principal credentials" / "Update application - Certificates and secrets
management". (That operation name renders with an en dash in some tenants and an
ASCII hyphen in others, so match both — the query below does.) The invariant is
the credential addition; triage by who did it, which (privileged) app it targets,
and whether it lines up with a normal app-lifecycle change. A credential added to
a high-privilege app by an unexpected actor — or one with a long/odd validity
window — is the tell.

This is **Entra audit telemetry (KQL / Sentinel), not the Windows Security log**,
so it lives only here in the companion — `PURPLE-TEAM.md` is scoped to on-prem
Splunk.

```kql
AuditLogs
| where OperationName has_any ("Add service principal credentials", "Add application credentials",
    "Update application - Certificates and secrets management",
    "Update application – Certificates and secrets management")
| project TimeGenerated, InitiatedBy, OperationName, TargetResources
```
