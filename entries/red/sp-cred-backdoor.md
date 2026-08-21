---
id: sp-cred-backdoor
title: Service-principal credential backdoor (add app secret)
section: Microsoft 365 / Entra ID
phase: Persistence
attack:
  tactic: TA0003
  techniques: [T1098.001]
platform: [cloud]
source: Mandiant / dirkjanm, Entra service-principal abuse
pair: sp-cred-auditlogs
---

With rights over an app registration / service principal
(`Application.ReadWrite.All`, or a compromised privileged role), add your *own*
client secret or certificate to
an existing privileged app. You then authenticate **as that app** —
non-interactive, no MFA, surviving user password resets: a durable cloud backdoor
that blends into normal app traffic. (Cloud — no on-host target, so no slots.)

```powershell
az ad app credential reset --id <app-id> --append
Add-MgApplicationPassword -ApplicationId <app-object-id> -PasswordCredential @{ displayName = "backup" }
```
