---
id: entra-role-assign-audit
title: Detect privileged directory-role grant (Entra audit, Add member to role)
detection: kql-entra-audit
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098.003]
source: Entra ID directory-role abuse (privileged role assignment)
pair: entra-directory-role
---

`Add member to role` in the Entra audit (`Category == "RoleManagement"`) is the invariant —
the role name rides in the target's `Role.DisplayName` modified property, not the top-level
event. Cover the PIM variants too: `Add eligible member to role` grants standing eligibility
that activates later, so a tenant watching only the direct grant misses the backdoor at the
moment it is planted and sees it only when it is used.

Privileged role grants are rare and change-controlled, so an actor outside that process is
the tell. Treat **Privileged Authentication Administrator** as equal in severity to Global
Administrator — it can reset a GA's credentials, so it is a GA grant one step removed, and it
is the one most likely to be waved through on review. A grant that quickly follows a new-user
or new-service-principal creation is the persistence pattern.

Entra audit telemetry (KQL / Sentinel), companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```kql
AuditLogs
| where Category == "RoleManagement"
| where OperationName has_any ("Add member to role", "Add eligible member to role")
| mv-expand prop = TargetResources[0].modifiedProperties
| where tostring(prop.displayName) == "Role.DisplayName"
| extend role = trim('"', tostring(prop.newValue))
| where role has_any ("Global Administrator", "Privileged Role Administrator",
    "Privileged Authentication Administrator", "Application Administrator")
| project TimeGenerated, InitiatedBy, OperationName, role, TargetResources
```
