---
id: account-lockout-defenders
title: Account access removal (lock out admins & responders)
section: Impact
phase: Impact
attack:
  tactic: TA0040
  techniques: [T1531]
platform: [windows]
source: MITRE ATT&CK T1531; incident-response denial
pair: account-removal-4725
---

Deny the defenders their own environment during the final act: reset or change
passwords for admin and break-glass accounts, disable or delete responder accounts,
and strip privileged group membership so IT can't log in to interrupt encryption or
kick off recovery. On-prem it's `net user` / `net localgroup` / `Disable-ADAccount`;
in the cloud it's disabling users or rotating their credentials. A burst of
password-reset / account-disable events against privileged accounts, from an
unexpected actor, is the tell.

```cmd
net user Administrator <NewP@ss!> /domain
Disable-ADAccount -Identity itadmin
net localgroup "Administrators" defenderacct /delete
net user helpdesk /active:no
```
