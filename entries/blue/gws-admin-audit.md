---
id: gws-admin-audit
title: Detect admin-role grant (Google Workspace admin audit)
detection: gws-audit-log
event_ids: []
attack:
  tactic: TA0003
  techniques: [T1098.003]
source: Google Workspace persistence (admin-role grant)
pair: gws-super-admin
---

`GRANT_DELEGATED_ADMIN_PRIVILEGES` (made super admin) and `ASSIGN_ROLE` (privileged role
assigned) in the **admin** audit are the invariants. Admin grants are rare and
high-impact, so one by an unexpected actor — especially super-admin, or a grant that
quickly follows a new-user creation — is the persistence tell after a tenant compromise.
Reconcile admin changes against the IdM workflow and alert on any outside change control.

Google Workspace audit-log telemetry, companion-only — `PURPLE-TEAM.md` is on-prem Windows.

```spl
index=gws sourcetype=gws:reports:admin eventName IN (GRANT_DELEGATED_ADMIN_PRIVILEGES, ASSIGN_ROLE)
| table _time, actor.email, target_user, role_name, ipAddress
```
