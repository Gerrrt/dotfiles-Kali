---
id: device-code-phish
title: Device-code phishing (steal M365/Entra tokens)
section: Microsoft 365 / Entra ID
phase: Credential Access
attack:
  tactic: TA0006
  techniques: [T1528]
platform: [windows, cloud]
source: dirkjanm (ROADtools) & Secureworks CTU, device-code phishing
pair: device-code-signin
---

Start the OAuth device-code flow, send the victim the short code + the *real*
`microsoft.com/devicelogin` URL; when they sign in (it rides their existing MFA),
you receive their access + refresh tokens. No attacker infra and no malicious
consent page — the login is Microsoft's own, which is exactly why it lands.
AADInternals prints the code and polls for the tokens. (Cloud — no on-host target,
so no slots.)

```powershell
Get-AADIntAccessTokenForMSGraph -UseDeviceCode -SaveToCache
```
