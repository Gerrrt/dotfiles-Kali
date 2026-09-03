---
id: entra-directory-role
title: Entra privileged directory-role grant (tenant persistence)
section: Microsoft 365 / Entra ID
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098.003]
platform: [cloud]
source: Entra ID directory-role abuse (privileged role assignment)
pair: entra-role-assign-audit
---

Holding Global Administrator or **Privileged Role Administrator** (or an app with
`RoleManagement.ReadWrite.Directory`), assign a controlled principal — a user you own, or
a service principal — a privileged **directory role**. This is the Entra twin of the
Workspace super-admin grant: durable, tenant-wide control that survives the victim admin's
password reset, and it hides in normal role churn far better than a new Global Admin does.
**Privileged Authentication Administrator** is the quiet choice — it can reset a Global
Admin's credentials and reads as far less alarming than GA itself. Assignment writes
`Add member to role` to the Entra audit log; under PIM, an *eligible* assignment writes
`Add eligible member to role` and stays dormant until activated. (Cloud IdP — no slots.)

```powershell
# Global Administrator role template: 62e90394-69f5-4237-9190-012177145e10
New-MgRoleManagementDirectoryRoleAssignment -RoleDefinitionId <role-template-id> `
  -PrincipalId <principal-object-id> -DirectoryScopeId "/"
az rest --method POST --url "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments" --body '{"roleDefinitionId":"<role-template-id>","principalId":"<principal-object-id>","directoryScopeId":"/"}'
```
