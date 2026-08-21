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

**Rank the role, don't filter on it.** The selling point of this technique is that it blends
into ordinary role churn, so a short named-role allowlist is the one shape that must not gate
the query: an attacker who reads the same detection simply takes User Administrator, Groups
Administrator, Cloud Application Administrator, or Hybrid Identity Administrator instead —
each a path back to Global Admin — and the alert never fires. Alert on every grant and sort by
role sensitivity, so the tier-0 grants surface first and the rest stay visible as churn to
baseline against. The `tier` lists below are a starting point; Entra marks the authoritative
set with the role definition's **`isPrivileged`** property, so a tenant that can join a role
watchlist (or an `externaldata` pull of the privileged role list) should key on that rather
than hand-maintain the `case`.

Entra audit telemetry (KQL / Sentinel), companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```kql
AuditLogs
| where Category == "RoleManagement"
| where OperationName has_any ("Add member to role", "Add eligible member to role")
| mv-expand prop = TargetResources[0].modifiedProperties
| where tostring(prop.displayName) == "Role.DisplayName"
| extend role = trim('"', tostring(prop.newValue))
| extend tier = case(
    role in ("Global Administrator", "Privileged Role Administrator",
             "Privileged Authentication Administrator"), 0,
    role in ("Application Administrator", "Cloud Application Administrator",
             "User Administrator", "Groups Administrator",
             "Hybrid Identity Administrator", "Authentication Administrator",
             "Security Administrator", "Directory Writers"), 1,
    2)
| project TimeGenerated, tier, InitiatedBy, OperationName, role, TargetResources
| sort by tier asc, TimeGenerated desc
```
